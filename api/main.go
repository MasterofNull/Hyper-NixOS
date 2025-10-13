package main

import (
    "context"
    "fmt"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"

    "github.com/gin-gonic/gin"
    "github.com/prometheus/client_golang/prometheus/promhttp"
    "github.com/spf13/viper"
    "go.uber.org/zap"
    "go.uber.org/zap/zapcore"

    "github.com/hypervisor/api/internal/config"
    "github.com/hypervisor/api/internal/db"
    "github.com/hypervisor/api/internal/handlers"
    "github.com/hypervisor/api/internal/middleware"
    "github.com/hypervisor/api/internal/services"
)

// @title Hyper-NixOS API
// @version 2.0
// @description High-performance API for Hyper-NixOS VM management
// @termsOfService https://github.com/hypervisor/terms
// @contact.name API Support
// @contact.email support@hypervisor.local
// @license.name GPL-3.0
// @license.url https://www.gnu.org/licenses/gpl-3.0.html
// @host localhost:8080
// @BasePath /api/v2
// @securityDefinitions.apikey BearerAuth
// @in header
// @name Authorization
func main() {
    // Initialize logger
    logger := initLogger()
    defer logger.Sync()

    // Load configuration
    cfg, err := config.Load()
    if err != nil {
        logger.Fatal("Failed to load configuration", zap.Error(err))
    }

    // Initialize database
    database, err := db.Initialize(cfg.Database)
    if err != nil {
        logger.Fatal("Failed to initialize database", zap.Error(err))
    }

    // Initialize services
    vmService := services.NewVMService(database, logger)
    authService := services.NewAuthService(cfg.Auth, logger)
    metricsService := services.NewMetricsService(logger)
    eventService := services.NewEventService(cfg.Events, logger)

    // Initialize Gin router
    router := setupRouter(cfg, logger, vmService, authService, metricsService, eventService)

    // Create HTTP server
    srv := &http.Server{
        Addr:         fmt.Sprintf("%s:%d", cfg.API.Host, cfg.API.Port),
        Handler:      router,
        ReadTimeout:  30 * time.Second,
        WriteTimeout: 30 * time.Second,
        IdleTimeout:  120 * time.Second,
    }

    // Start server in goroutine
    go func() {
        logger.Info("Starting API server", 
            zap.String("address", srv.Addr),
            zap.Bool("tls", cfg.API.TLS.Enabled))
        
        if cfg.API.TLS.Enabled {
            if err := srv.ListenAndServeTLS(cfg.API.TLS.CertFile, cfg.API.TLS.KeyFile); err != nil && err != http.ErrServerClosed {
                logger.Fatal("Failed to start HTTPS server", zap.Error(err))
            }
        } else {
            if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
                logger.Fatal("Failed to start HTTP server", zap.Error(err))
            }
        }
    }()

    // Wait for interrupt signal
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit

    logger.Info("Shutting down server...")

    // Graceful shutdown with timeout
    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()

    if err := srv.Shutdown(ctx); err != nil {
        logger.Error("Server forced to shutdown", zap.Error(err))
    }

    // Close services
    eventService.Close()
    database.Close()

    logger.Info("Server exited")
}

func initLogger() *zap.Logger {
    config := zap.NewProductionConfig()
    
    // Customize based on environment
    if os.Getenv("DEBUG") == "true" {
        config.Level = zap.NewAtomicLevelAt(zapcore.DebugLevel)
        config.Development = true
    }
    
    config.OutputPaths = []string{"stdout", "/var/log/hypervisor/api.log"}
    config.ErrorOutputPaths = []string{"stderr", "/var/log/hypervisor/api-error.log"}
    
    logger, err := config.Build()
    if err != nil {
        panic(fmt.Sprintf("Failed to initialize logger: %v", err))
    }
    
    return logger
}

func setupRouter(
    cfg *config.Config,
    logger *zap.Logger,
    vmService *services.VMService,
    authService *services.AuthService,
    metricsService *services.MetricsService,
    eventService *services.EventService,
) *gin.Engine {
    // Set Gin mode
    if cfg.API.Debug {
        gin.SetMode(gin.DebugMode)
    } else {
        gin.SetMode(gin.ReleaseMode)
    }

    router := gin.New()

    // Global middleware
    router.Use(middleware.Logger(logger))
    router.Use(middleware.Recovery(logger))
    router.Use(middleware.CORS(cfg.API.CORS))
    router.Use(middleware.RateLimiter(cfg.API.RateLimit))
    router.Use(middleware.RequestID())

    // Health check
    router.GET("/health", handlers.HealthCheck(vmService))
    
    // Metrics endpoint
    router.GET("/metrics", gin.WrapH(promhttp.Handler()))

    // API v2 routes
    v2 := router.Group("/api/v2")
    {
        // Public routes
        v2.POST("/auth/login", handlers.Login(authService))
        v2.POST("/auth/refresh", handlers.RefreshToken(authService))

        // Protected routes
        protected := v2.Group("")
        protected.Use(middleware.Auth(authService))
        {
            // VM routes
            vms := protected.Group("/vms")
            {
                vms.GET("", handlers.ListVMs(vmService))
                vms.POST("", handlers.CreateVM(vmService, eventService))
                vms.GET("/:id", handlers.GetVM(vmService))
                vms.PUT("/:id", handlers.UpdateVM(vmService, eventService))
                vms.DELETE("/:id", handlers.DeleteVM(vmService, eventService))
                
                // VM actions
                vms.POST("/:id/start", handlers.StartVM(vmService, eventService))
                vms.POST("/:id/stop", handlers.StopVM(vmService, eventService))
                vms.POST("/:id/restart", handlers.RestartVM(vmService, eventService))
                vms.POST("/:id/pause", handlers.PauseVM(vmService, eventService))
                vms.POST("/:id/resume", handlers.ResumeVM(vmService, eventService))
                
                // VM operations
                vms.POST("/:id/snapshot", handlers.CreateSnapshot(vmService, eventService))
                vms.GET("/:id/snapshots", handlers.ListSnapshots(vmService))
                vms.POST("/:id/clone", handlers.CloneVM(vmService, eventService))
                vms.GET("/:id/console", handlers.GetConsole(vmService))
                vms.GET("/:id/metrics", handlers.GetVMMetrics(metricsService))
            }

            // Storage routes
            storage := protected.Group("/storage")
            {
                storage.GET("/pools", handlers.ListStoragePools(vmService))
                storage.GET("/volumes", handlers.ListVolumes(vmService))
                storage.POST("/volumes", handlers.CreateVolume(vmService))
                storage.DELETE("/volumes/:id", handlers.DeleteVolume(vmService))
            }

            // Network routes
            networks := protected.Group("/networks")
            {
                networks.GET("", handlers.ListNetworks(vmService))
                networks.POST("", handlers.CreateNetwork(vmService))
                networks.DELETE("/:id", handlers.DeleteNetwork(vmService))
            }

            // User management
            users := protected.Group("/users")
            users.Use(middleware.RequireRole("admin"))
            {
                users.GET("", handlers.ListUsers(authService))
                users.POST("", handlers.CreateUser(authService))
                users.PUT("/:id", handlers.UpdateUser(authService))
                users.DELETE("/:id", handlers.DeleteUser(authService))
            }

            // System routes
            system := protected.Group("/system")
            {
                system.GET("/info", handlers.GetSystemInfo(vmService))
                system.GET("/stats", handlers.GetSystemStats(metricsService))
                system.POST("/backup", handlers.CreateBackup(vmService))
                system.GET("/events", handlers.GetEvents(eventService))
            }
        }
    }

    // WebSocket endpoint for real-time updates
    router.GET("/ws", middleware.Auth(authService), handlers.WebSocketHandler(eventService))

    // Swagger documentation
    router.GET("/swagger/*any", handlers.SwaggerHandler())

    return router
}