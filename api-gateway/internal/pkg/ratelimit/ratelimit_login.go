package ratelimit

import (
	"context"
	"errors"
	"fmt"
	"log"
	"strconv"
)

func (r *rateLimiter) LoginRateLimiter(ctx context.Context, email, ip string) error {
	// Burst Rate Limiter
	if err := r.loginBurstRateLimiter(ctx, email, ip); err != nil {
		if errors.Is(err, ErrLoginBurstRateLimitExceeded) {
			return err
		}
		log.Printf("login burst rate limiter error: %v\n", err)
	}

	// Fail Rate Limiter
	if err := r.checkLoginFailRateLimiter(ctx, email, ip); err != nil {
		if errors.Is(err, ErrLoginFailRateLimitExceeded) {
			return err
		}
		log.Printf("login fail rate limiter error: %v\n", err)
	}

	return nil
}

func (r *rateLimiter) ResetLoginFailRateLimiter(ctx context.Context, email, ip string) error {
	cfg := r.cfg.AuthRateLimit.Login.Fail
	key := fmt.Sprintf(cfg.Key, email, ip)
	if err := r.appCache.Delete(ctx, key); err != nil {
		return fmt.Errorf("failed to reset login fail rate limiter: %w", err)
	}
	return nil
}

func (r *rateLimiter) IncrementLoginFailRateLimiter(ctx context.Context, email, ip string) error {
	cfg := r.cfg.AuthRateLimit.Login.Fail
	key := fmt.Sprintf(cfg.Key, email, ip)
	count, err := r.fixedWindowCounter(ctx, key, cfg.RateLimit.WindowExpiry)
	if err != nil {
		return fmt.Errorf("failed to increment login fail rate limiter: %w", err)
	}

	log.Printf("login fail count for %s (%s): %d\n", email, ip, count)
	return nil
}

func (r *rateLimiter) loginBurstRateLimiter(ctx context.Context, email, ip string) error {
	cfg := r.cfg.AuthRateLimit.Login.Burst
	key := fmt.Sprintf(cfg.Key, email, ip)
	count, err := r.fixedWindowCounter(ctx, key, cfg.RateLimit.WindowExpiry)
	if err != nil {
		return fmt.Errorf("failed to apply login burst rate limiter: %w", err)
	}

	if count >= cfg.RateLimit.Requests {
		return ErrLoginBurstRateLimitExceeded
	}
	return nil
}

func (r *rateLimiter) checkLoginFailRateLimiter(ctx context.Context, email, ip string) error {
	cfg := r.cfg.AuthRateLimit.Login.Fail
	key := fmt.Sprintf(cfg.Key, email, ip)

	count, err := r.appCache.Get(ctx, key)
	if err != nil {
		return fmt.Errorf("failed to get login fail counter: %w", err)
	}

	countInt, _ := strconv.ParseInt(count, 10, 64)
	if countInt >= cfg.RateLimit.Requests {
		return ErrLoginFailRateLimitExceeded
	}
	return nil
}
