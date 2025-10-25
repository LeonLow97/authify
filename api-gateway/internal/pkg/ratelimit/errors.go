package ratelimit

import "errors"

var (
	ErrLoginBurstRateLimitExceeded = errors.New("login burst rate limit exceeded")
	ErrLoginFailRateLimitExceeded  = errors.New("login fail rate limit exceeded")
)
