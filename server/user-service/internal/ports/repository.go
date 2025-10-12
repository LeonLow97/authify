package ports

import (
	"context"

	"github.com/LeonLow97/internal/core/domain"
)

type Repository interface {
	GetUserByEmail(ctx context.Context, email string) (*domain.User, error)
	GetUsers(ctx context.Context, limit int64, userCursor domain.UserCursor) ([]domain.User, error)
	EmailExists(ctx context.Context, email string) (bool, error)

	InsertUser(ctx context.Context, user *domain.User) error
	UpdateUserByID(ctx context.Context, user *domain.User) error

	IsAdminUser(ctx context.Context, adminUserID int64) (bool, error)
}
