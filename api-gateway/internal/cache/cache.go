package cache

import "context"

// Cache defines the interface for caching operations.
type Cache interface {
	Set(ctx context.Context, key string, value any, ttlSeconds int64) error
	SetNX(ctx context.Context, key string, value any, ttlSeconds int64) (bool, error)
	Get(ctx context.Context, key string) (string, error)
	Delete(ctx context.Context, key string) error
	Exists(ctx context.Context, key string) (bool, error)
	Incr(ctx context.Context, key string) (int64, error)
	Expire(ctx context.Context, key string, ttlSeconds int64) (bool, error)
	Ping(ctx context.Context) error
}
