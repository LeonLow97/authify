package cache

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/LeonLow97/internal/config"
	"github.com/go-redis/redis/v8"
)

type Cache struct {
	RedisClient *redis.Client
	cfg         config.Config
}

var (
	instance *Cache
	once     sync.Once // singleton pattern
)

func GetCache(cfg config.Config) (*Cache, error) {
	var initErr error
	once.Do(func() {
		opts := &redis.Options{
			Addr:            fmt.Sprintf("%s:%d", cfg.RedisConfig.Address, cfg.RedisConfig.Port),
			Password:        cfg.RedisConfig.Password,
			DB:              cfg.RedisConfig.DatabaseIndex,
			MaxRetries:      3,
			MinRetryBackoff: 100 * time.Millisecond,
			MaxRetryBackoff: 1 * time.Second,
		}

		// DO NOT reassign `instance` because we are using a global instance variable
		instance = &Cache{
			RedisClient: redis.NewClient(opts),
			cfg:         cfg,
		}

		// Ping Redis during initialization
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()
		if err := instance.Ping(ctx); err != nil {
			initErr = fmt.Errorf("failed to connect to Redis: %w", err)
			return
		}
	})

	return instance, initErr
}

// Ping checks if Redis is alive
func (c *Cache) Ping(ctx context.Context) error {
	return c.RedisClient.Ping(ctx).Err()
}
