package ports

import (
	"context"

	"github.com/LeonLow97/internal/core/domain"
)

type UserOutbound interface {
	Login(ctx context.Context, req domain.User) (*domain.User, string, error)
	SignUp(ctx context.Context, req domain.User) error

	GetUsers(ctx context.Context, limit int64, cursor string) ([]domain.User, string, error)
	UpdateUser(ctx context.Context, req domain.User) error
}
