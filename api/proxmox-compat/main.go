// Proxmox API Compatibility Layer for Hyper-NixOS
package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
)

// Proxmox API compatible structures
type ProxmoxNode struct {
	Node   string  `json:"node"`
	Status string  `json:"status"`
	CPU    float64 `json:"cpu"`
	MaxCPU int     `json:"maxcpu"`
	Mem    int64   `json:"mem"`
	MaxMem int64   `json:"maxmem"`
	Disk   int64   `json:"disk"`
	MaxDisk int64  `json:"maxdisk"`
	Uptime int64   `json:"uptime"`
}

type ProxmoxVM struct {
	VMID      int     `json:"vmid"`
	Name      string  `json:"name"`
	Status    string  `json:"status"`
	CPU       float64 `json:"cpu"`
	MaxCPU    int     `json:"maxcpu"`
	Mem       int64   `json:"mem"`
	MaxMem    int64   `json:"maxmem"`
	Disk      int64   `json:"disk"`
	Netin     int64   `json:"netin"`
	Netout    int64   `json:"netout"`
	Uptime    int64   `json:"uptime"`
	Template  int     `json:"template,omitempty"`
}

type ProxmoxTask struct {
	UPID      string `json:"upid"`
	Type      string `json:"type"`
	Status    string `json:"status"`
	Node      string `json:"node"`
	User      string `json:"user"`
	StartTime int64  `json:"starttime"`
	EndTime   int64  `json:"endtime,omitempty"`
}

type ProxmoxStorage struct {
	Storage   string `json:"storage"`
	Type      string `json:"type"`
	Content   string `json:"content"`
	Active    int    `json:"active"`
	Total     int64  `json:"total"`
	Used      int64  `json:"used"`
	Available int64  `json:"avail"`
}

// API Response wrapper
type APIResponse struct {
	Data interface{} `json:"data"`
}

// API Error response
type APIError struct {
	Errors map[string]string `json:"errors"`
}

// Hyper-NixOS to Proxmox API adapter
type ProxmoxAdapter struct {
	hypervisorAPI string
}

// WebSocket upgrader for console connections
var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true // In production, implement proper origin checking
	},
}

func NewProxmoxAdapter(hypervisorAPI string) *ProxmoxAdapter {
	return &ProxmoxAdapter{
		hypervisorAPI: hypervisorAPI,
	}
}

// Convert Hyper-NixOS VM to Proxmox format
func (pa *ProxmoxAdapter) convertVM(hvVM map[string]interface{}) ProxmoxVM {
	// Extract VM ID from name (e.g., "vm-100" -> 100)
	name := hvVM["name"].(string)
	vmid := 0
	if strings.HasPrefix(name, "vm-") {
		fmt.Sscanf(name[3:], "%d", &vmid)
	}
	
	return ProxmoxVM{
		VMID:   vmid,
		Name:   name,
		Status: hvVM["state"].(string),
		CPU:    hvVM["cpu_usage"].(float64),
		MaxCPU: int(hvVM["cores"].(float64)),
		Mem:    int64(hvVM["memory_usage"].(float64)),
		MaxMem: int64(hvVM["memory"].(float64)) * 1024 * 1024,
		Disk:   int64(hvVM["disk_usage"].(float64)),
		Netin:  int64(hvVM["network_in"].(float64)),
		Netout: int64(hvVM["network_out"].(float64)),
		Uptime: int64(hvVM["uptime"].(float64)),
	}
}

// Setup Proxmox-compatible API routes
func (pa *ProxmoxAdapter) SetupRoutes(r *gin.Engine) {
	// API v2 JSON endpoints
	api := r.Group("/api2/json")
	{
		// Version endpoint
		api.GET("/version", pa.getVersion)
		
		// Access endpoints
		api.POST("/access/ticket", pa.createTicket)
		api.GET("/access/permissions", pa.getPermissions)
		
		// Cluster endpoints
		api.GET("/cluster/status", pa.getClusterStatus)
		api.GET("/cluster/resources", pa.getClusterResources)
		api.GET("/cluster/tasks", pa.getClusterTasks)
		
		// Nodes endpoints
		nodes := api.Group("/nodes")
		{
			nodes.GET("", pa.getNodes)
			nodes.GET("/:node/status", pa.getNodeStatus)
			nodes.GET("/:node/storage", pa.getNodeStorage)
			nodes.GET("/:node/disks/list", pa.getNodeDisks)
			nodes.GET("/:node/network", pa.getNodeNetwork)
			
			// QEMU/KVM endpoints
			nodes.GET("/:node/qemu", pa.getNodeVMs)
			nodes.POST("/:node/qemu", pa.createVM)
			nodes.GET("/:node/qemu/:vmid/status/current", pa.getVMStatus)
			nodes.GET("/:node/qemu/:vmid/config", pa.getVMConfig)
			nodes.PUT("/:node/qemu/:vmid/config", pa.updateVMConfig)
			nodes.DELETE("/:node/qemu/:vmid", pa.deleteVM)
			
			// VM actions
			nodes.POST("/:node/qemu/:vmid/status/start", pa.startVM)
			nodes.POST("/:node/qemu/:vmid/status/stop", pa.stopVM)
			nodes.POST("/:node/qemu/:vmid/status/reset", pa.resetVM)
			nodes.POST("/:node/qemu/:vmid/status/shutdown", pa.shutdownVM)
			nodes.POST("/:node/qemu/:vmid/status/suspend", pa.suspendVM)
			nodes.POST("/:node/qemu/:vmid/status/resume", pa.resumeVM)
			
			// Clone and template
			nodes.POST("/:node/qemu/:vmid/clone", pa.cloneVM)
			nodes.POST("/:node/qemu/:vmid/template", pa.convertToTemplate)
			
			// Snapshots
			nodes.GET("/:node/qemu/:vmid/snapshot", pa.getSnapshots)
			nodes.POST("/:node/qemu/:vmid/snapshot", pa.createSnapshot)
			nodes.DELETE("/:node/qemu/:vmid/snapshot/:snapname", pa.deleteSnapshot)
			nodes.POST("/:node/qemu/:vmid/snapshot/:snapname/rollback", pa.rollbackSnapshot)
			
			// Migration
			nodes.POST("/:node/qemu/:vmid/migrate", pa.migrateVM)
			
			// Console/VNC
			nodes.POST("/:node/qemu/:vmid/vncproxy", pa.createVNCProxy)
			nodes.GET("/:node/qemu/:vmid/vncwebsocket", pa.vncWebSocket)
		}
		
		// Storage endpoints
		api.GET("/storage", pa.getStorage)
		api.GET("/storage/:storage/content", pa.getStorageContent)
		api.POST("/storage/:storage/upload", pa.uploadToStorage)
		
		// Backup endpoints
		api.GET("/cluster/backup", pa.getBackupJobs)
		api.POST("/cluster/backup", pa.createBackupJob)
		api.PUT("/cluster/backup/:id", pa.updateBackupJob)
		api.DELETE("/cluster/backup/:id", pa.deleteBackupJob)
	}
	
	// WebSocket endpoints
	r.GET("/api2/json/nodes/:node/qemu/:vmid/vncwebsocket", pa.vncWebSocket)
}

// API Implementation methods

func (pa *ProxmoxAdapter) getVersion(c *gin.Context) {
	c.JSON(200, APIResponse{
		Data: map[string]interface{}{
			"version": "8.0.0",
			"release": "1",
			"repoid":  "proxmox-nixos",
		},
	})
}

func (pa *ProxmoxAdapter) createTicket(c *gin.Context) {
	var creds struct {
		Username string `json:"username"`
		Password string `json:"password"`
	}
	
	if err := c.ShouldBindJSON(&creds); err != nil {
		c.JSON(400, APIError{Errors: map[string]string{"bind": err.Error()}})
		return
	}
	
	// TODO: Implement actual authentication
	// For now, return a mock ticket
	c.JSON(200, APIResponse{
		Data: map[string]interface{}{
			"username": creds.Username,
			"ticket":   "PVE:admin@pve:12345678::MOCKTICKET",
			"CSRFPreventionToken": "12345678:MOCKCSRF",
		},
	})
}

func (pa *ProxmoxAdapter) getPermissions(c *gin.Context) {
	// Return permissions based on user
	c.JSON(200, APIResponse{
		Data: map[string]interface{}{
			"/":             []string{"Sys.Audit"},
			"/vms":          []string{"VM.Allocate", "VM.Audit"},
			"/storage":      []string{"Datastore.Allocate", "Datastore.Audit"},
			"/access":       []string{"User.Modify"},
			"/access/groups": []string{"User.Modify"},
		},
	})
}

func (pa *ProxmoxAdapter) getClusterStatus(c *gin.Context) {
	// TODO: Query actual cluster status from Hyper-NixOS
	c.JSON(200, APIResponse{
		Data: []map[string]interface{}{
			{
				"type":    "cluster",
				"name":    "hypervisor-cluster",
				"nodes":   1,
				"quorate": 1,
				"version": 1,
			},
			{
				"type":   "node",
				"name":   "node1",
				"online": 1,
				"level":  "",
				"id":     "node/node1",
			},
		},
	})
}

func (pa *ProxmoxAdapter) getClusterResources(c *gin.Context) {
	// TODO: Aggregate resources from Hyper-NixOS
	resources := []map[string]interface{}{
		// Nodes
		{
			"id":       "node/node1",
			"type":     "node",
			"node":     "node1",
			"status":   "online",
			"cpu":      0.05,
			"maxcpu":   8,
			"mem":      4294967296,
			"maxmem":   16884465664,
			"disk":     10737418240,
			"maxdisk":  107374182400,
			"uptime":   86400,
		},
		// VMs
		{
			"id":       "qemu/100",
			"type":     "qemu",
			"node":     "node1",
			"vmid":     100,
			"name":     "vm-100",
			"status":   "running",
			"cpu":      0.02,
			"maxcpu":   2,
			"mem":      1073741824,
			"maxmem":   2147483648,
			"disk":     0,
			"uptime":   3600,
		},
		// Storage
		{
			"id":       "storage/node1/local",
			"type":     "storage",
			"node":     "node1",
			"storage":  "local",
			"status":   "available",
			"disk":     10737418240,
			"maxdisk":  107374182400,
		},
	}
	
	// Apply type filter if specified
	if typeFilter := c.Query("type"); typeFilter != "" {
		filtered := []map[string]interface{}{}
		for _, r := range resources {
			if r["type"] == typeFilter {
				filtered = append(filtered, r)
			}
		}
		resources = filtered
	}
	
	c.JSON(200, APIResponse{Data: resources})
}

func (pa *ProxmoxAdapter) getClusterTasks(c *gin.Context) {
	// TODO: Get actual tasks from Hyper-NixOS
	tasks := []ProxmoxTask{
		{
			UPID:      "UPID:node1:00001234:12345678:5F000000:qmstart:100:admin@pve:",
			Type:      "qmstart",
			Status:    "OK",
			Node:      "node1",
			User:      "admin@pve",
			StartTime: time.Now().Unix() - 300,
			EndTime:   time.Now().Unix() - 290,
		},
	}
	
	c.JSON(200, APIResponse{Data: tasks})
}

func (pa *ProxmoxAdapter) getNodes(c *gin.Context) {
	// TODO: Get actual nodes from Hyper-NixOS cluster
	nodes := []ProxmoxNode{
		{
			Node:    "node1",
			Status:  "online",
			CPU:     0.05,
			MaxCPU:  8,
			Mem:     4294967296,
			MaxMem:  16884465664,
			Disk:    10737418240,
			MaxDisk: 107374182400,
			Uptime:  86400,
		},
	}
	
	c.JSON(200, APIResponse{Data: nodes})
}

func (pa *ProxmoxAdapter) getNodeStatus(c *gin.Context) {
	node := c.Param("node")
	
	// TODO: Get actual node status from Hyper-NixOS
	status := map[string]interface{}{
		"node":     node,
		"status":   "online",
		"cpu":      0.05,
		"maxcpu":   8,
		"mem":      4294967296,
		"maxmem":   16884465664,
		"disk":     10737418240,
		"maxdisk":  107374182400,
		"uptime":   86400,
		"loadavg":  []float64{0.10, 0.15, 0.12},
		"cpuinfo": map[string]interface{}{
			"model":   "Intel(R) Core(TM) i7-9700K CPU @ 3.60GHz",
			"sockets": 1,
			"cores":   8,
		},
	}
	
	c.JSON(200, APIResponse{Data: status})
}

func (pa *ProxmoxAdapter) getNodeVMs(c *gin.Context) {
	// TODO: Query actual VMs from Hyper-NixOS
	vms := []ProxmoxVM{
		{
			VMID:   100,
			Name:   "vm-100",
			Status: "running",
			CPU:    0.02,
			MaxCPU: 2,
			Mem:    1073741824,
			MaxMem: 2147483648,
			Disk:   5368709120,
			Netin:  1048576,
			Netout: 2097152,
			Uptime: 3600,
		},
		{
			VMID:     999,
			Name:     "ubuntu-template",
			Status:   "stopped",
			Template: 1,
			MaxCPU:   2,
			MaxMem:   2147483648,
		},
	}
	
	c.JSON(200, APIResponse{Data: vms})
}

func (pa *ProxmoxAdapter) createVM(c *gin.Context) {
	var vmConfig map[string]interface{}
	if err := c.ShouldBindJSON(&vmConfig); err != nil {
		c.JSON(400, APIError{Errors: map[string]string{"bind": err.Error()}})
		return
	}
	
	// TODO: Create VM in Hyper-NixOS
	// For now, return a task
	task := ProxmoxTask{
		UPID:      fmt.Sprintf("UPID:%s:00001234:12345678:5F000000:qmcreate:%v:admin@pve:", c.Param("node"), vmConfig["vmid"]),
		Type:      "qmcreate",
		Status:    "running",
		Node:      c.Param("node"),
		User:      "admin@pve",
		StartTime: time.Now().Unix(),
	}
	
	c.JSON(200, APIResponse{Data: task.UPID})
}

func (pa *ProxmoxAdapter) getVMStatus(c *gin.Context) {
	vmid := c.Param("vmid")
	
	// TODO: Get actual VM status from Hyper-NixOS
	status := map[string]interface{}{
		"status":   "running",
		"vmid":     vmid,
		"cpu":      0.02,
		"cpus":     2,
		"mem":      1073741824,
		"maxmem":   2147483648,
		"disk":     0,
		"diskread": 1048576,
		"diskwrite": 524288,
		"netin":    1048576,
		"netout":   2097152,
		"uptime":   3600,
		"pid":      12345,
		"qmpstatus": "running",
		"running-qemu": "7.0.0",
		"running-machine": "pc-q35-7.0",
	}
	
	c.JSON(200, APIResponse{Data: status})
}

func (pa *ProxmoxAdapter) getVMConfig(c *gin.Context) {
	vmid := c.Param("vmid")
	
	// TODO: Get actual VM config from Hyper-NixOS
	config := map[string]interface{}{
		"vmid":     vmid,
		"name":     fmt.Sprintf("vm-%s", vmid),
		"memory":   2048,
		"cores":    2,
		"sockets":  1,
		"cpu":      "host",
		"numa":     0,
		"ostype":   "l26",
		"boot":     "order=scsi0;ide2;net0",
		"scsihw":   "virtio-scsi-pci",
		"ide2":     "none,media=cdrom",
		"net0":     "virtio=52:54:00:12:34:56,bridge=vmbr0,firewall=1",
		"scsi0":    "local:vm-" + vmid + "-disk-0,size=32G",
		"agent":    1,
		"vga":      "std",
		"description": "Test VM",
	}
	
	c.JSON(200, APIResponse{Data: config})
}

func (pa *ProxmoxAdapter) updateVMConfig(c *gin.Context) {
	var config map[string]interface{}
	if err := c.ShouldBindJSON(&config); err != nil {
		c.JSON(400, APIError{Errors: map[string]string{"bind": err.Error()}})
		return
	}
	
	// TODO: Update VM config in Hyper-NixOS
	c.JSON(200, APIResponse{Data: nil})
}

func (pa *ProxmoxAdapter) deleteVM(c *gin.Context) {
	vmid := c.Param("vmid")
	
	// TODO: Delete VM in Hyper-NixOS
	task := ProxmoxTask{
		UPID:      fmt.Sprintf("UPID:%s:00001234:12345678:5F000000:qmdestroy:%s:admin@pve:", c.Param("node"), vmid),
		Type:      "qmdestroy",
		Status:    "running",
		Node:      c.Param("node"),
		User:      "admin@pve",
		StartTime: time.Now().Unix(),
	}
	
	c.JSON(200, APIResponse{Data: task.UPID})
}

// VM action handlers
func (pa *ProxmoxAdapter) startVM(c *gin.Context) {
	pa.vmAction(c, "qmstart", "start")
}

func (pa *ProxmoxAdapter) stopVM(c *gin.Context) {
	pa.vmAction(c, "qmstop", "stop")
}

func (pa *ProxmoxAdapter) resetVM(c *gin.Context) {
	pa.vmAction(c, "qmreset", "reset")
}

func (pa *ProxmoxAdapter) shutdownVM(c *gin.Context) {
	pa.vmAction(c, "qmshutdown", "shutdown")
}

func (pa *ProxmoxAdapter) suspendVM(c *gin.Context) {
	pa.vmAction(c, "qmsuspend", "suspend")
}

func (pa *ProxmoxAdapter) resumeVM(c *gin.Context) {
	pa.vmAction(c, "qmresume", "resume")
}

func (pa *ProxmoxAdapter) vmAction(c *gin.Context, taskType, action string) {
	vmid := c.Param("vmid")
	
	// TODO: Perform actual VM action in Hyper-NixOS
	task := ProxmoxTask{
		UPID:      fmt.Sprintf("UPID:%s:00001234:12345678:5F000000:%s:%s:admin@pve:", c.Param("node"), taskType, vmid),
		Type:      taskType,
		Status:    "running",
		Node:      c.Param("node"),
		User:      "admin@pve",
		StartTime: time.Now().Unix(),
	}
	
	c.JSON(200, APIResponse{Data: task.UPID})
}

// Clone and template operations
func (pa *ProxmoxAdapter) cloneVM(c *gin.Context) {
	var cloneConfig struct {
		NewID       int    `json:"newid"`
		Name        string `json:"name"`
		Description string `json:"description"`
		Full        bool   `json:"full"`
		Pool        string `json:"pool"`
		SnapName    string `json:"snapname"`
		Storage     string `json:"storage"`
		Target      string `json:"target"`
	}
	
	if err := c.ShouldBindJSON(&cloneConfig); err != nil {
		c.JSON(400, APIError{Errors: map[string]string{"bind": err.Error()}})
		return
	}
	
	// TODO: Implement VM cloning in Hyper-NixOS
	task := ProxmoxTask{
		UPID:      fmt.Sprintf("UPID:%s:00001234:12345678:5F000000:qmclone:%s:admin@pve:", c.Param("node"), c.Param("vmid")),
		Type:      "qmclone",
		Status:    "running",
		Node:      c.Param("node"),
		User:      "admin@pve",
		StartTime: time.Now().Unix(),
	}
	
	c.JSON(200, APIResponse{Data: task.UPID})
}

func (pa *ProxmoxAdapter) convertToTemplate(c *gin.Context) {
	vmid := c.Param("vmid")
	
	// TODO: Convert VM to template in Hyper-NixOS
	c.JSON(200, APIResponse{Data: nil})
}

// Snapshot operations
func (pa *ProxmoxAdapter) getSnapshots(c *gin.Context) {
	// TODO: Get actual snapshots from Hyper-NixOS
	snapshots := []map[string]interface{}{
		{
			"name":        "current",
			"description": "You are here!",
			"parent":      "snapshot1",
		},
		{
			"name":        "snapshot1",
			"description": "Test snapshot",
			"snaptime":    time.Now().Unix() - 86400,
			"vmstate":     1,
		},
	}
	
	c.JSON(200, APIResponse{Data: snapshots})
}

func (pa *ProxmoxAdapter) createSnapshot(c *gin.Context) {
	var snapConfig struct {
		SnapName    string `json:"snapname"`
		Description string `json:"description"`
		VMState     bool   `json:"vmstate"`
	}
	
	if err := c.ShouldBindJSON(&snapConfig); err != nil {
		c.JSON(400, APIError{Errors: map[string]string{"bind": err.Error()}})
		return
	}
	
	// TODO: Create snapshot in Hyper-NixOS
	task := ProxmoxTask{
		UPID:      fmt.Sprintf("UPID:%s:00001234:12345678:5F000000:qmsnapshot:%s:admin@pve:", c.Param("node"), c.Param("vmid")),
		Type:      "qmsnapshot",
		Status:    "running",
		Node:      c.Param("node"),
		User:      "admin@pve",
		StartTime: time.Now().Unix(),
	}
	
	c.JSON(200, APIResponse{Data: task.UPID})
}

func (pa *ProxmoxAdapter) deleteSnapshot(c *gin.Context) {
	// TODO: Delete snapshot in Hyper-NixOS
	task := ProxmoxTask{
		UPID:      fmt.Sprintf("UPID:%s:00001234:12345678:5F000000:qmdelsnapshot:%s:admin@pve:", c.Param("node"), c.Param("vmid")),
		Type:      "qmdelsnapshot",
		Status:    "running",
		Node:      c.Param("node"),
		User:      "admin@pve",
		StartTime: time.Now().Unix(),
	}
	
	c.JSON(200, APIResponse{Data: task.UPID})
}

func (pa *ProxmoxAdapter) rollbackSnapshot(c *gin.Context) {
	// TODO: Rollback to snapshot in Hyper-NixOS
	task := ProxmoxTask{
		UPID:      fmt.Sprintf("UPID:%s:00001234:12345678:5F000000:qmrollback:%s:admin@pve:", c.Param("node"), c.Param("vmid")),
		Type:      "qmrollback",
		Status:    "running",
		Node:      c.Param("node"),
		User:      "admin@pve",
		StartTime: time.Now().Unix(),
	}
	
	c.JSON(200, APIResponse{Data: task.UPID})
}

// Migration
func (pa *ProxmoxAdapter) migrateVM(c *gin.Context) {
	var migrateConfig struct {
		Target        string `json:"target"`
		Online        bool   `json:"online"`
		Force         bool   `json:"force"`
		MigrationNetwork string `json:"migration_network"`
		MigrationType string `json:"migration_type"`
		WithLocalDisks bool  `json:"with-local-disks"`
	}
	
	if err := c.ShouldBindJSON(&migrateConfig); err != nil {
		c.JSON(400, APIError{Errors: map[string]string{"bind": err.Error()}})
		return
	}
	
	// TODO: Implement VM migration in Hyper-NixOS
	task := ProxmoxTask{
		UPID:      fmt.Sprintf("UPID:%s:00001234:12345678:5F000000:qmigrate:%s:admin@pve:", c.Param("node"), c.Param("vmid")),
		Type:      "qmigrate",
		Status:    "running",
		Node:      c.Param("node"),
		User:      "admin@pve",
		StartTime: time.Now().Unix(),
	}
	
	c.JSON(200, APIResponse{Data: task.UPID})
}

// Storage operations
func (pa *ProxmoxAdapter) getStorage(c *gin.Context) {
	// TODO: Get actual storage from Hyper-NixOS
	storage := []ProxmoxStorage{
		{
			Storage:   "local",
			Type:      "dir",
			Content:   "images,iso,vztmpl,backup,snippets",
			Active:    1,
			Total:     107374182400,
			Used:      10737418240,
			Available: 96636764160,
		},
		{
			Storage:   "local-lvm",
			Type:      "lvmthin",
			Content:   "images,rootdir",
			Active:    1,
			Total:     214748364800,
			Used:      21474836480,
			Available: 193273528320,
		},
	}
	
	c.JSON(200, APIResponse{Data: storage})
}

func (pa *ProxmoxAdapter) getNodeStorage(c *gin.Context) {
	// Filter storage by node
	pa.getStorage(c)
}

func (pa *ProxmoxAdapter) getStorageContent(c *gin.Context) {
	storage := c.Param("storage")
	content := c.Query("content")
	
	// TODO: Get actual storage content from Hyper-NixOS
	var items []map[string]interface{}
	
	switch content {
	case "images":
		items = []map[string]interface{}{
			{
				"volid":  fmt.Sprintf("%s:vm-100-disk-0", storage),
				"format": "qcow2",
				"size":   32212254720,
				"used":   5368709120,
				"vmid":   100,
			},
		}
	case "iso":
		items = []map[string]interface{}{
			{
				"volid":  fmt.Sprintf("%s:iso/ubuntu-22.04.iso", storage),
				"format": "iso",
				"size":   3825205248,
			},
		}
	case "backup":
		items = []map[string]interface{}{
			{
				"volid":  fmt.Sprintf("%s:backup/vzdump-qemu-100-2024_01_01-12_00_00.vma.zst", storage),
				"format": "vma.zst",
				"size":   1073741824,
				"vmid":   100,
				"ctime":  time.Now().Unix() - 86400,
			},
		}
	}
	
	c.JSON(200, APIResponse{Data: items})
}

func (pa *ProxmoxAdapter) uploadToStorage(c *gin.Context) {
	// TODO: Implement file upload to storage
	c.JSON(200, APIResponse{Data: "OK"})
}

func (pa *ProxmoxAdapter) getNodeDisks(c *gin.Context) {
	// TODO: Get actual disk list from node
	disks := []map[string]interface{}{
		{
			"devpath": "/dev/sda",
			"size":    256060514304,
			"model":   "SAMSUNG MZVLB256HAHQ-000H1",
			"serial":  "S444NA0M123456",
			"vendor":  "ATA",
			"wwn":     "0x5002538e40123456",
			"health":  "PASSED",
			"type":    "ssd",
			"rpm":     0,
			"gpt":     1,
			"used":    "lvm",
		},
	}
	
	c.JSON(200, APIResponse{Data: disks})
}

func (pa *ProxmoxAdapter) getNodeNetwork(c *gin.Context) {
	// TODO: Get actual network config from node
	networks := []map[string]interface{}{
		{
			"iface":      "vmbr0",
			"type":       "bridge",
			"method":     "static",
			"address":    "192.168.1.10",
			"netmask":    "255.255.255.0",
			"gateway":    "192.168.1.1",
			"bridge_ports": "eth0",
			"active":     1,
		},
		{
			"iface":   "eth0",
			"type":    "eth",
			"method":  "manual",
			"active":  1,
		},
	}
	
	c.JSON(200, APIResponse{Data: networks})
}

// Backup operations
func (pa *ProxmoxAdapter) getBackupJobs(c *gin.Context) {
	// TODO: Get actual backup jobs from Hyper-NixOS
	jobs := []map[string]interface{}{
		{
			"id":       "backup-daily",
			"enabled":  1,
			"schedule": "daily",
			"storage":  "local",
			"vmid":     "all",
			"mode":     "snapshot",
			"compress": "zstd",
			"mailto":   "admin@example.com",
			"comment":  "Daily backup of all VMs",
		},
	}
	
	c.JSON(200, APIResponse{Data: jobs})
}

func (pa *ProxmoxAdapter) createBackupJob(c *gin.Context) {
	var job map[string]interface{}
	if err := c.ShouldBindJSON(&job); err != nil {
		c.JSON(400, APIError{Errors: map[string]string{"bind": err.Error()}})
		return
	}
	
	// TODO: Create backup job in Hyper-NixOS
	c.JSON(200, APIResponse{Data: job["id"]})
}

func (pa *ProxmoxAdapter) updateBackupJob(c *gin.Context) {
	var job map[string]interface{}
	if err := c.ShouldBindJSON(&job); err != nil {
		c.JSON(400, APIError{Errors: map[string]string{"bind": err.Error()}})
		return
	}
	
	// TODO: Update backup job in Hyper-NixOS
	c.JSON(200, APIResponse{Data: nil})
}

func (pa *ProxmoxAdapter) deleteBackupJob(c *gin.Context) {
	// TODO: Delete backup job in Hyper-NixOS
	c.JSON(200, APIResponse{Data: nil})
}

// VNC proxy
func (pa *ProxmoxAdapter) createVNCProxy(c *gin.Context) {
	vmid := c.Param("vmid")
	
	// TODO: Create actual VNC proxy
	proxy := map[string]interface{}{
		"ticket": fmt.Sprintf("PVEVNC:%s:MOCKTICKET", vmid),
		"port":   5900,
		"cert":   "-----BEGIN CERTIFICATE-----\nMOCKCERT\n-----END CERTIFICATE-----",
		"upid":   fmt.Sprintf("UPID:%s:00001234:12345678:5F000000:vncproxy:%s:admin@pve:", c.Param("node"), vmid),
	}
	
	c.JSON(200, APIResponse{Data: proxy})
}

func (pa *ProxmoxAdapter) vncWebSocket(c *gin.Context) {
	// Upgrade to WebSocket
	ws, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		log.Printf("WebSocket upgrade failed: %v", err)
		return
	}
	defer ws.Close()
	
	// TODO: Implement actual VNC WebSocket proxy
	// This would connect to the VM's VNC server and proxy the connection
	
	// For now, just echo messages
	for {
		messageType, p, err := ws.ReadMessage()
		if err != nil {
			log.Printf("WebSocket read error: %v", err)
			return
		}
		
		if err := ws.WriteMessage(messageType, p); err != nil {
			log.Printf("WebSocket write error: %v", err)
			return
		}
	}
}

func main() {
	// Initialize Gin router
	r := gin.Default()
	
	// Create Proxmox adapter
	adapter := NewProxmoxAdapter("http://localhost:8080")
	
	// Setup routes
	adapter.SetupRoutes(r)
	
	// Start server
	log.Println("Starting Proxmox API compatibility layer on :8006")
	if err := r.Run(":8006"); err != nil {
		log.Fatal("Failed to start server:", err)
	}
}