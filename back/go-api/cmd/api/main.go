package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"github.com/darkzinn11/parque/back/go-api/internal/application/usecases"
	"github.com/darkzinn11/parque/back/go-api/internal/domain/entities"
	"github.com/darkzinn11/parque/back/go-api/internal/domain/repositories"
	"github.com/darkzinn11/parque/back/go-api/internal/infrastructure/http/handlers"
	"github.com/darkzinn11/parque/back/go-api/internal/infrastructure/http/middleware"
	"github.com/darkzinn11/parque/back/go-api/internal/infrastructure/persistence"
	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	sqldriver "github.com/go-sql-driver/mysql"
	"github.com/joho/godotenv"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

func main() {
	// Load environment variables
	if err := godotenv.Load("configs/.env"); err != nil {
		log.Println("No .env file found, using system env")
	}

	dbHost := os.Getenv("DB_HOST")
	dbPort := os.Getenv("DB_PORT")
	dbName := os.Getenv("DB_NAME")
	dbUser := os.Getenv("DB_USER")
	dbPass := os.Getenv("DB_PASS")
	jwtSecret := getEnv("JWT_SECRET", "troque-essa-chave-em-producao")
	adminCorsOrigin := getEnv("ADMIN_CORS_ORIGIN", "http://localhost:5173")
	basePath := normalizeBasePath(os.Getenv("BASE_PATH"))

	mysqlConfig := sqldriver.Config{
		User:                 dbUser,
		Passwd:               dbPass,
		Net:                  "tcp",
		Addr:                 fmt.Sprintf("%s:%s", dbHost, dbPort),
		DBName:               dbName,
		Collation:            "utf8mb4_general_ci",
		Loc:                  time.Local,
		ParseTime:            true,
		AllowNativePasswords: true,
	}
	dsn := mysqlConfig.FormatDSN()

	// Database setup
	db, err := gorm.Open(mysql.Open(dsn), &gorm.Config{})
	if err != nil {
		log.Fatalf("failed to connect to database: %v", err)
	}

	// Auto Migration of schemas
	log.Println("Running Auto migrations...")
	if err := db.AutoMigrate(
		&entities.AdminUser{},
		&entities.Park{},
		&entities.Reservation{},
		&entities.Evento{},
		&entities.Activity{},
		&entities.MapPoint{},
		&entities.Review{},
		&entities.VemCaminhar{},
		&entities.Favorite{},
	); err != nil {
		log.Fatalf("failed to run database automigrations: %v", err)
	}
	log.Println("Database connection and migration successful!")

	// Repositories
	parkRepo := persistence.NewMySQLParkRepository(db)
	resRepo := persistence.NewMySQLReservationRepository(db)
	mapPointRepo := persistence.NewMySQLMapPointRepository(db)
	reviewRepo := persistence.NewMySQLReviewRepository(db)
	adminUserRepo := persistence.NewMySQLAdminUserRepository(db)
	dashboardRepo := persistence.NewMySQLDashboardRepository(db)

	// Setup UseCases and Handlers
	parkUseCase := usecases.NewParkUseCase(parkRepo)
	mapPointUseCase := usecases.NewMapPointUseCase(mapPointRepo)
	reviewUseCase := usecases.NewReviewUseCase(reviewRepo)
	authUseCase := usecases.NewAuthUseCase(adminUserRepo, jwtSecret)
	dashboardUseCase := usecases.NewDashboardUseCase(dashboardRepo)
	parkHandler := handlers.NewParkHandler(parkUseCase)
	mapPointHandler := handlers.NewMapPointHandler(mapPointUseCase)
	reviewHandler := handlers.NewReviewHandler(reviewUseCase)
	authHandler := handlers.NewAuthHandler(authUseCase)
	dashboardHandler := handlers.NewDashboardHandler(dashboardUseCase)

	if err := authUseCase.SeedDefaultAdmin(
		context.Background(),
		getEnv("ADMIN_SEED_NAME", "Administrador do Painel"),
		getEnv("ADMIN_SEED_EMAIL", "admin@vemproparque.com.br"),
		getEnv("ADMIN_SEED_PASSWORD", "Admin@123456"),
	); err != nil {
		log.Fatalf("failed to seed admin user: %v", err)
	}

	// Router setup
	r := gin.Default()
	if trustedProxies := parseTrustedProxies(os.Getenv("TRUSTED_PROXIES")); len(trustedProxies) > 0 {
		if err := r.SetTrustedProxies(trustedProxies); err != nil {
			log.Fatalf("failed to set trusted proxies: %v", err)
		}
	}
	r.Use(cors.New(cors.Config{
		AllowOrigins:     []string{adminCorsOrigin},
		AllowMethods:     []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Accept", "Authorization"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowCredentials: true,
		MaxAge:           12 * time.Hour,
	}))

	root := r.Group(basePath)

	// Health check
	root.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "UP"})
	})

	// API Routes
	api := root.Group("/api/v1")
	{
		parks := api.Group("/parks")
		{
			parks.GET("/", parkHandler.ListParks)
			parks.GET("/:id", parkHandler.GetPark)
		}

		auth := api.Group("/admin/auth")
		{
			auth.POST("/login", authHandler.Login)
		}

		admin := api.Group("/admin")
		admin.Use(middleware.RequireAdminAuth(authUseCase))
		{
			admin.GET("/dashboard", dashboardHandler.GetStats)
			admin.GET("/auth/me", authHandler.Me)

			adminParks := admin.Group("/parks")
			{
				adminParks.GET("/", parkHandler.ListParks)
				adminParks.GET("/:id", parkHandler.GetPark)
				adminParks.POST("/", parkHandler.CreatePark)
				adminParks.PUT("/:id", parkHandler.UpdatePark)
				adminParks.DELETE("/:id", parkHandler.DeletePark)
			}

			adminMapPoints := admin.Group("/map-points")
			{
				adminMapPoints.GET("/", mapPointHandler.List)
				adminMapPoints.GET("/:id", mapPointHandler.GetByID)
				adminMapPoints.POST("/", mapPointHandler.Create)
				adminMapPoints.PUT("/:id", mapPointHandler.Update)
				adminMapPoints.DELETE("/:id", mapPointHandler.Delete)
			}

			adminReviews := admin.Group("/reviews")
			{
				adminReviews.GET("/", reviewHandler.List)
				adminReviews.GET("/:id", reviewHandler.GetByID)
				adminReviews.POST("/", reviewHandler.Create)
				adminReviews.PUT("/:id", reviewHandler.Update)
				adminReviews.DELETE("/:id", reviewHandler.Delete)
			}
		}

		reservations := api.Group("/reservations")
		{
			reservations.GET("/user/:id", listUserReservationsHandler(resRepo))
		}
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Server starting on port %s with base path %q", port, basePath)
	if err := r.Run(":" + port); err != nil {
		log.Fatal(err)
	}
}

func getEnv(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

func normalizeBasePath(value string) string {
	trimmed := strings.TrimSpace(value)
	if trimmed == "" || trimmed == "/" {
		return ""
	}

	trimmed = "/" + strings.Trim(trimmed, "/")
	return trimmed
}

func parseTrustedProxies(value string) []string {
	if strings.TrimSpace(value) == "" {
		return nil
	}

	rawItems := strings.Split(value, ",")
	proxies := make([]string, 0, len(rawItems))
	for _, item := range rawItems {
		trimmed := strings.TrimSpace(item)
		if trimmed != "" {
			proxies = append(proxies, trimmed)
		}
	}
	return proxies
}

func listUserReservationsHandler(repo repositories.ReservationRepository) gin.HandlerFunc {
	return func(c *gin.Context) {
		idStr := c.Param("id")
		// In a real app, convert string to uint safely
		var userID uint
		_, err := fmt.Sscanf(idStr, "%d", &userID)
		if err != nil {
			c.JSON(400, gin.H{"error": "invalid user id"})
			return
		}

		resList, err := repo.GetByUserID(c.Request.Context(), userID)
		if err != nil {
			c.JSON(500, gin.H{"error": err.Error()})
			return
		}
		c.JSON(200, resList)
	}
}
