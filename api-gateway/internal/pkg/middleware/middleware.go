package middleware

import "github.com/LeonLow97/internal/config"

type middleware struct {
	cfg *config.Config
}

func NewMiddleware(cfg *config.Config) *middleware {
	return &middleware{
		cfg: cfg,
	}
}
