//! Virtual Machine management module

use crate::error::HypervisorError;
use crate::metrics::MetricsCollector;
use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{debug, error, info, instrument, warn};
use uuid::Uuid;

/// VM state enumeration
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, sqlx::Type)]
#[sqlx(type_name = "TEXT")]
pub enum VmState {
    #[serde(rename = "stopped")]
    Stopped,
    #[serde(rename = "running")]
    Running,
    #[serde(rename = "paused")]
    Paused,
    #[serde(rename = "suspended")]
    Suspended,
    #[serde(rename = "crashed")]
    Crashed,
}

/// VM resource configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VmResources {
    pub vcpus: u32,
    pub memory_mb: u64,
    pub disk_gb: u64,
}

/// Virtual Machine representation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Vm {
    pub id: Uuid,
    pub name: String,
    pub state: VmState,
    pub resources: VmResources,
    pub owner: Option<String>,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub updated_at: chrono::DateTime<chrono::Utc>,
    pub metadata: serde_json::Value,
}

/// VM creation request
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateVmRequest {
    pub name: String,
    pub resources: VmResources,
    pub owner: Option<String>,
    pub template: Option<String>,
    pub metadata: Option<serde_json::Value>,
}

/// VM manager service
pub struct VmManager {
    db: sqlx::SqlitePool,
    metrics: Arc<MetricsCollector>,
    libvirt: Arc<RwLock<virt::connect::Connect>>,
}

impl VmManager {
    /// Create a new VM manager
    pub async fn new(
        db: sqlx::SqlitePool,
        metrics: Arc<MetricsCollector>,
    ) -> Result<Self, HypervisorError> {
        // Connect to libvirt
        let conn = virt::connect::Connect::open("qemu:///system")
            .map_err(|e| HypervisorError::LibvirtError(e.to_string()))?;
        let libvirt = Arc::new(RwLock::new(conn));
        
        Ok(Self {
            db,
            metrics,
            libvirt,
        })
    }
    
    /// List all VMs
    #[instrument(skip(self))]
    pub async fn list_vms(&self) -> Result<Vec<Vm>, HypervisorError> {
        debug!("Listing all VMs");
        
        let vms = sqlx::query_as!(
            Vm,
            r#"
            SELECT 
                id as "id: Uuid",
                name,
                state as "state: VmState",
                resources as "resources: sqlx::types::Json<VmResources>",
                owner,
                created_at as "created_at: chrono::DateTime<chrono::Utc>",
                updated_at as "updated_at: chrono::DateTime<chrono::Utc>",
                metadata
            FROM vms
            ORDER BY name
            "#
        )
        .fetch_all(&self.db)
        .await?;
        
        self.metrics.record_vm_count(vms.len()).await;
        Ok(vms)
    }
    
    /// Create a new VM
    #[instrument(skip(self))]
    pub async fn create_vm(&self, request: CreateVmRequest) -> Result<Vm, HypervisorError> {
        info!("Creating VM: {}", request.name);
        
        // Validate request
        self.validate_create_request(&request)?;
        
        // Generate VM ID
        let vm_id = Uuid::new_v4();
        let now = chrono::Utc::now();
        
        // Start transaction
        let mut tx = self.db.begin().await?;
        
        // Insert into database
        let vm = Vm {
            id: vm_id,
            name: request.name.clone(),
            state: VmState::Stopped,
            resources: request.resources.clone(),
            owner: request.owner,
            created_at: now,
            updated_at: now,
            metadata: request.metadata.unwrap_or_else(|| serde_json::json!({})),
        };
        
        sqlx::query!(
            r#"
            INSERT INTO vms (id, name, state, resources, owner, created_at, updated_at, metadata)
            VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)
            "#,
            vm.id,
            vm.name,
            vm.state,
            serde_json::to_string(&vm.resources)?,
            vm.owner,
            vm.created_at,
            vm.updated_at,
            serde_json::to_string(&vm.metadata)?
        )
        .execute(&mut *tx)
        .await?;
        
        // Create libvirt domain
        self.create_libvirt_domain(&vm).await?;
        
        // Commit transaction
        tx.commit().await?;
        
        // Record metrics
        self.metrics.record_vm_created(&vm.name).await;
        
        info!("VM created successfully: {} ({})", vm.name, vm.id);
        Ok(vm)
    }
    
    /// Start a VM
    #[instrument(skip(self))]
    pub async fn start_vm(&self, vm_id: Uuid) -> Result<(), HypervisorError> {
        info!("Starting VM: {}", vm_id);
        
        // Get VM from database
        let vm = self.get_vm(vm_id).await?;
        
        // Check state
        if vm.state == VmState::Running {
            warn!("VM {} is already running", vm.name);
            return Ok(());
        }
        
        // Start via libvirt
        let conn = self.libvirt.read().await;
        let domain = conn
            .domain_lookup_by_uuid_string(&vm_id.to_string())
            .map_err(|e| HypervisorError::LibvirtError(e.to_string()))?;
        
        domain
            .create()
            .map_err(|e| HypervisorError::LibvirtError(e.to_string()))?;
        
        // Update database
        self.update_vm_state(vm_id, VmState::Running).await?;
        
        // Record metrics
        self.metrics.record_vm_started(&vm.name).await;
        
        info!("VM started successfully: {}", vm.name);
        Ok(())
    }
    
    /// Stop a VM
    #[instrument(skip(self))]
    pub async fn stop_vm(&self, vm_id: Uuid, force: bool) -> Result<(), HypervisorError> {
        info!("Stopping VM: {} (force: {})", vm_id, force);
        
        // Get VM from database
        let vm = self.get_vm(vm_id).await?;
        
        // Check state
        if vm.state != VmState::Running {
            warn!("VM {} is not running", vm.name);
            return Ok(());
        }
        
        // Stop via libvirt
        let conn = self.libvirt.read().await;
        let domain = conn
            .domain_lookup_by_uuid_string(&vm_id.to_string())
            .map_err(|e| HypervisorError::LibvirtError(e.to_string()))?;
        
        if force {
            domain
                .destroy()
                .map_err(|e| HypervisorError::LibvirtError(e.to_string()))?;
        } else {
            domain
                .shutdown()
                .map_err(|e| HypervisorError::LibvirtError(e.to_string()))?;
        }
        
        // Update database
        self.update_vm_state(vm_id, VmState::Stopped).await?;
        
        // Record metrics
        self.metrics.record_vm_stopped(&vm.name).await;
        
        info!("VM stopped successfully: {}", vm.name);
        Ok(())
    }
    
    /// Delete a VM
    #[instrument(skip(self))]
    pub async fn delete_vm(&self, vm_id: Uuid) -> Result<(), HypervisorError> {
        info!("Deleting VM: {}", vm_id);
        
        // Get VM from database
        let vm = self.get_vm(vm_id).await?;
        
        // Ensure VM is stopped
        if vm.state != VmState::Stopped {
            return Err(HypervisorError::InvalidOperation(
                "VM must be stopped before deletion".to_string(),
            ));
        }
        
        // Delete from libvirt
        let conn = self.libvirt.read().await;
        if let Ok(domain) = conn.domain_lookup_by_uuid_string(&vm_id.to_string()) {
            domain
                .undefine()
                .map_err(|e| HypervisorError::LibvirtError(e.to_string()))?;
        }
        
        // Delete from database
        sqlx::query!("DELETE FROM vms WHERE id = ?", vm_id)
            .execute(&self.db)
            .await?;
        
        // Record metrics
        self.metrics.record_vm_deleted(&vm.name).await;
        
        info!("VM deleted successfully: {}", vm.name);
        Ok(())
    }
    
    // Helper methods
    
    async fn get_vm(&self, vm_id: Uuid) -> Result<Vm, HypervisorError> {
        sqlx::query_as!(
            Vm,
            r#"
            SELECT 
                id as "id: Uuid",
                name,
                state as "state: VmState",
                resources as "resources: sqlx::types::Json<VmResources>",
                owner,
                created_at as "created_at: chrono::DateTime<chrono::Utc>",
                updated_at as "updated_at: chrono::DateTime<chrono::Utc>",
                metadata
            FROM vms
            WHERE id = ?
            "#,
            vm_id
        )
        .fetch_one(&self.db)
        .await
        .map_err(|_| HypervisorError::VmNotFound(vm_id))
    }
    
    async fn update_vm_state(&self, vm_id: Uuid, state: VmState) -> Result<(), HypervisorError> {
        let now = chrono::Utc::now();
        sqlx::query!(
            "UPDATE vms SET state = ?, updated_at = ? WHERE id = ?",
            state,
            now,
            vm_id
        )
        .execute(&self.db)
        .await?;
        Ok(())
    }
    
    fn validate_create_request(&self, request: &CreateVmRequest) -> Result<(), HypervisorError> {
        // Validate name
        if request.name.is_empty() || request.name.len() > 63 {
            return Err(HypervisorError::ValidationError(
                "VM name must be 1-63 characters".to_string(),
            ));
        }
        
        // Validate resources
        if request.resources.vcpus == 0 || request.resources.vcpus > 64 {
            return Err(HypervisorError::ValidationError(
                "vCPUs must be between 1 and 64".to_string(),
            ));
        }
        
        if request.resources.memory_mb < 512 || request.resources.memory_mb > 1024 * 1024 {
            return Err(HypervisorError::ValidationError(
                "Memory must be between 512 MB and 1 TB".to_string(),
            ));
        }
        
        Ok(())
    }
    
    async fn create_libvirt_domain(&self, vm: &Vm) -> Result<(), HypervisorError> {
        // This would create the actual libvirt XML and define the domain
        // Simplified for example
        debug!("Creating libvirt domain for VM: {}", vm.name);
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_vm_state_serialization() {
        assert_eq!(
            serde_json::to_string(&VmState::Running).unwrap(),
            r#""running""#
        );
    }
}