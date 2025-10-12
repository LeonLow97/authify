package db

import (
	"fmt"
	"log"
	"regexp"

	"github.com/LeonLow97/internal/pkg/config"
	"github.com/jackc/pgx/v4"
	"github.com/jackc/pgx/v4/stdlib"
	"github.com/jmoiron/sqlx"
)

// ConnectToDB initializes a database connection using the provided configuration.
// It construct a DSN, opens a connection, verifies it with a ping.
func ConnectToDB(cfg config.Config) (*sqlx.DB, error) {
	// Construct the DSN (Data Source Name) string using values from the configuration
	dsn := fmt.Sprintf("postgres://%s:%s@%s:%d/%s?sslmode=disable",
		cfg.PostgresConfig.User,     // Username
		cfg.PostgresConfig.Password, // Password
		cfg.PostgresConfig.Host,     // Database Host
		cfg.PostgresConfig.Port,     // Database Port
		cfg.PostgresConfig.DB,       // Database Name
	)

	// Parse the DSN into a `pgx` connection configuration
	connConfig, err := pgx.ParseConfig(dsn)
	if err != nil {
		errMsg := err.Error()
		errMsg = regexp.MustCompile(`(://[^:]+:).+(@.+)`).ReplaceAllString(errMsg, "$1*****$2")
		errMsg = regexp.MustCompile(`(password=).+(\s+)`).ReplaceAllString(errMsg, "$1*****$2")
		return nil, fmt.Errorf("parsing DSN failed with error %s", errMsg)
	}

	// Register the parsed `pgx` configuration and obtain a connection string
	connStr := stdlib.RegisterConnConfig(connConfig)

	// Open a new database connection using `sqlx` with the `pgx` driver
	db, err := sqlx.Open("pgx", connStr)
	if err != nil {
		log.Println("Failed to open Postgres connection with error:", err)
		return nil, err
	}

	// Verify the connection by sending a simple ping to the database
	if err := db.Ping(); err != nil {
		log.Println("Failed to ping postgres database with error:", err)
		return nil, err
	}

	log.Println("Successfully connected to Postgres database!")
	return db, nil
}
