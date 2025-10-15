// GraphQL Server with Event-Driven Architecture for Hyper-NixOS
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/99designs/gqlgen/graphql"
	"github.com/99designs/gqlgen/graphql/handler"
	"github.com/99designs/gqlgen/graphql/handler/extension"
	"github.com/99designs/gqlgen/graphql/handler/lru"
	"github.com/99designs/gqlgen/graphql/handler/transport"
	"github.com/99designs/gqlgen/graphql/playground"
	"github.com/gorilla/websocket"
	"github.com/nats-io/nats.go"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/rs/cors"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/sdk/resource"
	"go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.7.0"
)

// Event system for real-time updates
type EventBus struct {
	nc              *nats.Conn
	js              nats.JetStreamContext
	subscriptions   map[string]*nats.Subscription
	metricsRegistry *prometheus.Registry
}

// NewEventBus creates a new event bus
func NewEventBus(natsURL string) (*EventBus, error) {
	// Connect to NATS
	nc, err := nats.Connect(natsURL)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to NATS: %w", err)
	}

	// Create JetStream context
	js, err := nc.JetStream()
	if err != nil {
		return nil, fmt.Errorf("failed to create JetStream context: %w", err)
	}

	// Create streams
	streams := []nats.StreamConfig{
		{
			Name:     "COMPUTE",
			Subjects: []string{"compute.>"},
			MaxAge:   24 * time.Hour,
		},
		{
			Name:     "STORAGE",
			Subjects: []string{"storage.>"},
			MaxAge:   24 * time.Hour,
		},
		{
			Name:     "MESH",
			Subjects: []string{"mesh.>"},
			MaxAge:   24 * time.Hour,
		},
		{
			Name:     "SECURITY",
			Subjects: []string{"security.>"},
			MaxAge:   24 * time.Hour,
		},
		{
			Name:     "BACKUP",
			Subjects: []string{"backup.>"},
			MaxAge:   24 * time.Hour,
		},
		{
			Name:     "SYSTEM",
			Subjects: []string{"system.>"},
			MaxAge:   24 * time.Hour,
		},
	}

	for _, stream := range streams {
		_, err = js.AddStream(&stream)
		if err != nil {
			log.Printf("Failed to create stream %s: %v", stream.Name, err)
		}
	}

	// Setup metrics
	reg := prometheus.NewRegistry()
	
	// Register metrics
	eventCounter := prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "hypervisor_events_total",
			Help: "Total number of events published",
		},
		[]string{"type", "severity"},
	)
	reg.MustRegister(eventCounter)

	return &EventBus{
		nc:              nc,
		js:              js,
		subscriptions:   make(map[string]*nats.Subscription),
		metricsRegistry: reg,
	}, nil
}

// PublishEvent publishes an event to the event bus
func (eb *EventBus) PublishEvent(ctx context.Context, eventType, severity string, data interface{}) error {
	// Marshal event data
	payload, err := json.Marshal(data)
	if err != nil {
		return fmt.Errorf("failed to marshal event: %w", err)
	}

	// Determine subject based on event type
	subject := fmt.Sprintf("%s.%s", getEventCategory(eventType), eventType)

	// Publish to JetStream
	_, err = eb.js.Publish(subject, payload)
	if err != nil {
		return fmt.Errorf("failed to publish event: %w", err)
	}

	// Update metrics
	if counter, err := eb.metricsRegistry.GetMetricWith(
		prometheus.Labels{"type": eventType, "severity": severity},
	); err == nil {
		if c, ok := counter.(prometheus.Counter); ok {
			c.Inc()
		}
	}

	return nil
}

// Subscribe creates a subscription for events
func (eb *EventBus) Subscribe(subject string, handler nats.MsgHandler) (*nats.Subscription, error) {
	sub, err := eb.nc.Subscribe(subject, handler)
	if err != nil {
		return nil, err
	}
	
	eb.subscriptions[subject] = sub
	return sub, nil
}

// Close closes the event bus
func (eb *EventBus) Close() {
	for _, sub := range eb.subscriptions {
		sub.Unsubscribe()
	}
	eb.nc.Close()
}

func getEventCategory(eventType string) string {
	switch {
	case contains(eventType, "COMPUTE"):
		return "compute"
	case contains(eventType, "STORAGE"):
		return "storage"
	case contains(eventType, "NODE") || contains(eventType, "CONSENSUS"):
		return "mesh"
	case contains(eventType, "CAPABILITY") || contains(eventType, "SECURITY"):
		return "security"
	case contains(eventType, "BACKUP"):
		return "backup"
	default:
		return "system"
	}
}

func contains(s, substr string) bool {
	return len(s) >= len(substr) && s[:len(substr)] == substr
}

// Resolver is the root GraphQL resolver
type Resolver struct {
	EventBus *EventBus
	// Add other dependencies like database, services, etc.
}

// GraphQL server setup
func NewGraphQLServer(resolver *Resolver) *handler.Server {
	srv := handler.NewDefaultServer(NewExecutableSchema(Config{Resolvers: resolver}))

	// Add transports
	srv.AddTransport(&transport.Websocket{
		Upgrader: websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool {
				// Configure CORS as needed
				return true
			},
			ReadBufferSize:  1024,
			WriteBufferSize: 1024,
		},
		InitFunc: func(ctx context.Context, initPayload transport.InitPayload) (context.Context, error) {
			// Handle authentication from connection params
			token := initPayload.Authorization()
			if token != "" {
				ctx = context.WithValue(ctx, "auth-token", token)
			}
			return ctx, nil
		},
		KeepAlivePingInterval: 10 * time.Second,
	})
	
	srv.AddTransport(transport.Options{})
	srv.AddTransport(transport.GET{})
	srv.AddTransport(transport.POST{})
	srv.AddTransport(transport.MultipartForm{})

	// Add extensions
	srv.Use(extension.Introspection{})
	srv.Use(extension.AutomaticPersistedQuery{
		Cache: lru.New(100),
	})

	// Add custom middleware
	srv.Use(&CapabilityMiddleware{})
	srv.Use(&MetricsMiddleware{})
	srv.Use(&TracingMiddleware{})

	return srv
}

// CapabilityMiddleware checks capabilities for GraphQL operations
type CapabilityMiddleware struct{}

func (m *CapabilityMiddleware) ExtensionName() string {
	return "CapabilityMiddleware"
}

func (m *CapabilityMiddleware) Validate(schema graphql.ExecutableSchema) error {
	return nil
}

func (m *CapabilityMiddleware) InterceptOperation(ctx context.Context, next graphql.OperationHandler) graphql.ResponseHandler {
	oc := graphql.GetOperationContext(ctx)
	
	// Extract auth token
	token := ctx.Value("auth-token")
	if token == nil {
		// Check header
		if req := graphql.GetRequestContext(ctx).Request; req != nil {
			token = req.Header.Get("Authorization")
		}
	}

	// Validate capabilities based on operation
	if err := validateCapabilities(ctx, oc.Operation, token); err != nil {
		return func(ctx context.Context) *graphql.Response {
			return &graphql.Response{
				Errors: gqlerror.List{{
					Message: "Unauthorized: " + err.Error(),
					Extensions: map[string]interface{}{
						"code": "UNAUTHORIZED",
					},
				}},
			}
		}
	}

	return next(ctx)
}

// MetricsMiddleware collects GraphQL metrics
type MetricsMiddleware struct {
	requestDuration *prometheus.HistogramVec
	requestCounter  *prometheus.CounterVec
}

func (m *MetricsMiddleware) ExtensionName() string {
	return "MetricsMiddleware"
}

func (m *MetricsMiddleware) Validate(schema graphql.ExecutableSchema) error {
	// Initialize metrics
	m.requestDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name: "graphql_request_duration_seconds",
			Help: "GraphQL request duration",
		},
		[]string{"operation_type", "operation_name"},
	)
	
	m.requestCounter = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "graphql_requests_total",
			Help: "Total GraphQL requests",
		},
		[]string{"operation_type", "operation_name", "status"},
	)

	prometheus.MustRegister(m.requestDuration, m.requestCounter)
	return nil
}

func (m *MetricsMiddleware) InterceptOperation(ctx context.Context, next graphql.OperationHandler) graphql.ResponseHandler {
	start := time.Now()
	oc := graphql.GetOperationContext(ctx)
	
	return func(ctx context.Context) *graphql.Response {
		resp := next(ctx)
		
		duration := time.Since(start).Seconds()
		status := "success"
		if resp != nil && len(resp.Errors) > 0 {
			status = "error"
		}
		
		m.requestDuration.WithLabelValues(
			string(oc.Operation.Operation),
			oc.Operation.Name,
		).Observe(duration)
		
		m.requestCounter.WithLabelValues(
			string(oc.Operation.Operation),
			oc.Operation.Name,
			status,
		).Inc()
		
		return resp
	}
}

// TracingMiddleware adds OpenTelemetry tracing
type TracingMiddleware struct{}

func (m *TracingMiddleware) ExtensionName() string {
	return "TracingMiddleware"
}

func (m *TracingMiddleware) Validate(schema graphql.ExecutableSchema) error {
	return nil
}

func (m *TracingMiddleware) InterceptField(ctx context.Context, next graphql.Resolver) (interface{}, error) {
	fc := graphql.GetFieldContext(ctx)
	
	tracer := otel.Tracer("graphql")
	ctx, span := tracer.Start(ctx, fmt.Sprintf("GraphQL.%s", fc.Field.Name))
	defer span.End()
	
	return next(ctx)
}

// Initialize OpenTelemetry
func initTracer() (*trace.TracerProvider, error) {
	exporter, err := otlptrace.New(
		context.Background(),
		otlptracegrpc.NewClient(
			otlptracegrpc.WithEndpoint("localhost:4317"),
			otlptracegrpc.WithInsecure(),
		),
	)
	if err != nil {
		return nil, err
	}

	tp := trace.NewTracerProvider(
		trace.WithBatcher(exporter),
		trace.WithResource(resource.NewWithAttributes(
			semconv.SchemaURL,
			semconv.ServiceNameKey.String("hypervisor-graphql"),
			semconv.ServiceVersionKey.String("1.0.0"),
		)),
	)

	otel.SetTracerProvider(tp)
	return tp, nil
}

func validateCapabilities(ctx context.Context, op *ast.OperationDefinition, token interface{}) error {
	// Implementation would check capabilities based on operation
	// This is a placeholder
	return nil
}

func main() {
	// Configuration
	port := os.Getenv("GRAPHQL_PORT")
	if port == "" {
		port = "8081"
	}
	
	natsURL := os.Getenv("NATS_URL")
	if natsURL == "" {
		natsURL = "nats://localhost:4222"
	}

	// Initialize tracing
	tp, err := initTracer()
	if err != nil {
		log.Printf("Failed to initialize tracer: %v", err)
	} else {
		defer tp.Shutdown(context.Background())
	}

	// Initialize event bus
	eventBus, err := NewEventBus(natsURL)
	if err != nil {
		log.Fatalf("Failed to create event bus: %v", err)
	}
	defer eventBus.Close()

	// Create resolver
	resolver := &Resolver{
		EventBus: eventBus,
	}

	// Create GraphQL server
	srv := NewGraphQLServer(resolver)

	// Setup HTTP server
	mux := http.NewServeMux()
	
	// GraphQL endpoint
	mux.Handle("/graphql", otelhttp.NewHandler(srv, "graphql"))
	
	// GraphQL playground
	mux.Handle("/", playground.Handler("GraphQL playground", "/graphql"))
	
	// Metrics endpoint
	mux.Handle("/metrics", promhttp.Handler())
	
	// Health check
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]interface{}{
			"status": "healthy",
			"service": "hypervisor-graphql",
			"timestamp": time.Now().Unix(),
		})
	})

	// Setup CORS
	c := cors.New(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "OPTIONS"},
		AllowedHeaders:   []string{"*"},
		AllowCredentials: true,
	})

	handler := c.Handler(mux)

	// Start server
	log.Printf("Starting GraphQL server on :%s", port)
	log.Printf("GraphQL playground available at http://localhost:%s/", port)
	
	if err := http.ListenAndServe(":"+port, handler); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}