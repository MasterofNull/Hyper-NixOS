// Package services provides business logic services
package services

import (
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"go.uber.org/zap"
	"golang.org/x/crypto/bcrypt"

	"github.com/hypervisor/api/internal/config"
	"github.com/hypervisor/api/internal/db"
)

// VMService handles VM operations
type VMService struct {
	db     *db.Database
	logger *zap.Logger
}

// NewVMService creates a new VM service
func NewVMService(database *db.Database, logger *zap.Logger) *VMService {
	return &VMService{
		db:     database,
		logger: logger,
	}
}

// ListVMs returns all VMs
func (s *VMService) ListVMs() ([]db.VM, error) {
	var vms []db.VM
	result := s.db.Find(&vms)
	return vms, result.Error
}

// GetVM returns a VM by ID
func (s *VMService) GetVM(id uint) (*db.VM, error) {
	var vm db.VM
	result := s.db.First(&vm, id)
	return &vm, result.Error
}

// CreateVM creates a new VM
func (s *VMService) CreateVM(vm *db.VM) error {
	return s.db.Create(vm).Error
}

// UpdateVM updates a VM
func (s *VMService) UpdateVM(vm *db.VM) error {
	return s.db.Save(vm).Error
}

// DeleteVM deletes a VM
func (s *VMService) DeleteVM(id uint) error {
	return s.db.Delete(&db.VM{}, id).Error
}

// AuthService handles authentication
type AuthService struct {
	cfg    config.AuthConfig
	db     *db.Database
	logger *zap.Logger
}

// Claims represents JWT claims
type Claims struct {
	UserID   uint   `json:"user_id"`
	Username string `json:"username"`
	Role     string `json:"role"`
	jwt.RegisteredClaims
}

// NewAuthService creates a new auth service
func NewAuthService(cfg config.AuthConfig, logger *zap.Logger) *AuthService {
	return &AuthService{
		cfg:    cfg,
		logger: logger,
	}
}

// SetDatabase sets the database for auth service
func (s *AuthService) SetDatabase(database *db.Database) {
	s.db = database
}

// Login authenticates a user and returns a JWT token
func (s *AuthService) Login(username, password string) (string, string, error) {
	var user db.User
	if err := s.db.Where("username = ?", username).First(&user).Error; err != nil {
		return "", "", errors.New("invalid credentials")
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password)); err != nil {
		return "", "", errors.New("invalid credentials")
	}

	token, err := s.generateToken(&user, time.Duration(s.cfg.TokenExpiry)*time.Second)
	if err != nil {
		return "", "", err
	}

	refreshToken, err := s.generateToken(&user, time.Duration(s.cfg.RefreshExpiry)*time.Second)
	if err != nil {
		return "", "", err
	}

	return token, refreshToken, nil
}

// ValidateToken validates a JWT token and returns the claims
func (s *AuthService) ValidateToken(tokenString string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		return []byte(s.cfg.JWTSecret), nil
	})

	if err != nil {
		return nil, err
	}

	if claims, ok := token.Claims.(*Claims); ok && token.Valid {
		return claims, nil
	}

	return nil, errors.New("invalid token")
}

func (s *AuthService) generateToken(user *db.User, expiry time.Duration) (string, error) {
	claims := &Claims{
		UserID:   user.ID,
		Username: user.Username,
		Role:     user.Role,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(expiry)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(s.cfg.JWTSecret))
}

// MetricsService handles metrics collection
type MetricsService struct {
	logger *zap.Logger
}

// NewMetricsService creates a new metrics service
func NewMetricsService(logger *zap.Logger) *MetricsService {
	return &MetricsService{
		logger: logger,
	}
}

// EventService handles event streaming
type EventService struct {
	cfg    config.EventsConfig
	logger *zap.Logger
}

// NewEventService creates a new event service
func NewEventService(cfg config.EventsConfig, logger *zap.Logger) *EventService {
	return &EventService{
		cfg:    cfg,
		logger: logger,
	}
}

// Close closes the event service connections
func (s *EventService) Close() {
	// Close NATS connection if open
}
