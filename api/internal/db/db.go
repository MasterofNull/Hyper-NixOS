// Package db provides database initialization and access
package db

import (
	"github.com/hypervisor/api/internal/config"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// Database wraps the GORM database connection
type Database struct {
	*gorm.DB
}

// Initialize creates and configures the database connection
func Initialize(cfg config.DatabaseConfig) (*Database, error) {
	var dialector gorm.Dialector

	switch cfg.Driver {
	case "sqlite":
		dialector = sqlite.Open(cfg.DSN)
	default:
		dialector = sqlite.Open(cfg.DSN)
	}

	db, err := gorm.Open(dialector, &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		return nil, err
	}

	// Auto-migrate models
	if err := db.AutoMigrate(&VM{}, &User{}, &Snapshot{}, &Event{}); err != nil {
		return nil, err
	}

	return &Database{db}, nil
}

// Close closes the database connection
func (d *Database) Close() error {
	sqlDB, err := d.DB.DB()
	if err != nil {
		return err
	}
	return sqlDB.Close()
}

// VM represents a virtual machine in the database
type VM struct {
	gorm.Model
	Name        string `gorm:"uniqueIndex"`
	UUID        string `gorm:"uniqueIndex"`
	State       string
	CPUs        int
	Memory      int64
	DiskSize    int64
	Description string
	OwnerID     uint
}

// User represents a user in the database
type User struct {
	gorm.Model
	Username     string `gorm:"uniqueIndex"`
	PasswordHash string
	Email        string
	Role         string
	Enabled      bool
}

// Snapshot represents a VM snapshot
type Snapshot struct {
	gorm.Model
	VMID        uint
	Name        string
	Description string
	State       string
}

// Event represents a system event
type Event struct {
	gorm.Model
	Type      string
	Source    string
	Message   string
	Severity  string
	Metadata  string
}
