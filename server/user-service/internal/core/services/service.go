package services

import (
	"context"

	"github.com/LeonLow97/internal/core/domain"
	"github.com/LeonLow97/internal/pkg/config"
	"github.com/LeonLow97/internal/ports"
)

type Service interface {
	Login(ctx context.Context, loginInput domain.LoginInput) (*domain.User, string, error)
	SignUp(ctx context.Context, signupInput domain.SignUpInput) error

	UpdateUser(ctx context.Context, userID int64, updateUserInput domain.UpdateUserInput) error
	GetUsers(ctx context.Context, adminUserID int64, limit int64, cursorStr string) ([]domain.User, string, error)
}

type service struct {
	repo ports.Repository
	cfg  config.Config
}

func NewService(r ports.Repository, cfg config.Config) Service {
	return &service{
		repo: r,
		cfg:  cfg,
	}
}
