//! Hyper-NixOS Core Library
//! 
//! High-performance, type-safe implementations of core hypervisor operations.

#![warn(clippy::all, clippy::pedantic)]
#![allow(clippy::module_name_repetitions)]

pub mod config;
pub mod error;
pub mod metrics;
pub mod security;
pub mod storage;
pub mod vm;

use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{info, instrument};

/// Global hypervisor state
pub struct HypervisorState {
    config: Arc<RwLock<config::Config>>,
    db_pool: sqlx::SqlitePool,
    metrics: Arc<metrics::MetricsCollector>,
    vm_manager: Arc<vm::VmManager>,
}

impl HypervisorState {
    /// Initialize the hypervisor system
    #[instrument(skip_all)]
    pub async fn initialize() -> Result<Self, error::HypervisorError> {
        info!("Initializing Hyper-NixOS core library");
        
        // Load configuration
        let config = config::Config::load().await?;
        let config = Arc::new(RwLock::new(config));
        
        // Initialize database
        let db_pool = storage::init_database(&config.read().await.storage.database_path).await?;
        
        // Initialize metrics
        let metrics = Arc::new(metrics::MetricsCollector::new());
        
        // Initialize VM manager
        let vm_manager = Arc::new(vm::VmManager::new(db_pool.clone(), metrics.clone()).await?);
        
        Ok(Self {
            config,
            db_pool,
            metrics,
            vm_manager,
        })
    }
    
    /// Get VM manager
    pub fn vm_manager(&self) -> &Arc<vm::VmManager> {
        &self.vm_manager
    }
    
    /// Get metrics collector
    pub fn metrics(&self) -> &Arc<metrics::MetricsCollector> {
        &self.metrics
    }
    
    /// Reload configuration
    #[instrument(skip(self))]
    pub async fn reload_config(&self) -> Result<(), error::HypervisorError> {
        info!("Reloading configuration");
        let new_config = config::Config::load().await?;
        *self.config.write().await = new_config;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[tokio::test]
    async fn test_initialization() {
        // This would need test fixtures
        // let state = HypervisorState::initialize().await.unwrap();
        // assert!(state.vm_manager.list_vms().await.unwrap().is_empty());
    }
}