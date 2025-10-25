package ratelimit

import (
	"context"
	"fmt"
)

// fixedWindowCounter uses the redis pattern of INCR and EXPIRE
func (r *rateLimiter) fixedWindowCounter(
	ctx context.Context,
	key string,
	windowExpiry int64,
) (int64, error) {
	count, err := r.appCache.Incr(ctx, key)
	if err != nil {
		return 0, fmt.Errorf("failed to increment rate limit key %q: %w", key, err)
	}

	if count == 1 {
		if _, err = r.appCache.Expire(ctx, key, windowExpiry); err != nil {
			return 0, fmt.Errorf("failed to set expiry for rate limit key %q: %w", key, err)
		}
	}

	return count, nil
}
