package cache

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/LeonLow97/internal/config"
	"github.com/go-redis/redis/v8"
)

type RedisCache struct {
	client *redis.Client
	cfg    config.Config
}

var (
	instance *RedisCache
	once     sync.Once // singleton pattern
)

func NewRedisCache(cfg config.Config) (*RedisCache, error) {
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
		instance = &RedisCache{
			client: redis.NewClient(opts),
			cfg:    cfg,
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

func (r *RedisCache) Ping(ctx context.Context) error {
	return r.client.Ping(ctx).Err()
}

func (r *RedisCache) Set(ctx context.Context, key string, value any, ttlSeconds int64) error {
	return r.client.Set(ctx, key, value, time.Duration(ttlSeconds)*time.Second).Err()
}

func (r *RedisCache) SetNX(ctx context.Context, key string, value any, ttlSeconds int64) (bool, error) {
	ok, err := r.client.SetNX(ctx, key, value, time.Duration(ttlSeconds)*time.Second).Result()
	return ok, err
}

func (r *RedisCache) Get(ctx context.Context, key string) (string, error) {
	return r.client.Get(ctx, key).Result()
}

func (r *RedisCache) Delete(ctx context.Context, key string) error {
	return r.client.Del(ctx, key).Err()
}

func (r *RedisCache) Incr(ctx context.Context, key string) (int64, error) {
	return r.client.Incr(ctx, key).Result()
}

func (r *RedisCache) Expire(ctx context.Context, key string, ttlSeconds int64) (bool, error) {
	return r.client.Expire(ctx, key, time.Duration(ttlSeconds)*time.Second).Result()
}

func (r *RedisCache) Exists(ctx context.Context, key string) (bool, error) {
	count, err := r.client.Exists(ctx, key).Result()
	return count > 0, err
}
