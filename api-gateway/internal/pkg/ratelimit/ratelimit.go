package ratelimit

import (
	"context"

	"github.com/LeonLow97/internal/cache"
	"github.com/LeonLow97/internal/config"
)

type RateLimiter interface {
	LoginRateLimiter(ctx context.Context, email, ip string) error
	ResetLoginFailRateLimiter(ctx context.Context, email, ip string) error
	IncrementLoginFailRateLimiter(ctx context.Context, email, ip string) error
}

type rateLimiter struct {
	cfg      config.Config
	appCache cache.Cache
}

func NewRateLimiter(cfg config.Config, appCache cache.Cache) RateLimiter {
	return &rateLimiter{
		cfg:      cfg,
		appCache: appCache,
	}
}
