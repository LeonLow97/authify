package user

import (
	"context"
	"log"

	"github.com/LeonLow97/internal/core/domain"
	"github.com/LeonLow97/internal/ports"
)

type User interface {
	Login(ctx context.Context, req domain.User) (*domain.User, string, error)
	SignUp(ctx context.Context, req domain.User) error

	GetUsers(ctx context.Context, limit int64, cursor string) ([]domain.User, string, error)
	UpdateUser(ctx context.Context, req domain.User) error
}

type service struct {
	userRepo ports.UserOutbound
}

func NewUserService(userRepo ports.UserOutbound) User {
	return &service{
		userRepo: userRepo,
	}
}

func (s *service) Login(ctx context.Context, req domain.User) (*domain.User, string, error) {
	user, token, err := s.userRepo.Login(ctx, req)
	if err != nil {
		log.Printf("failed to login for email %s with error: %v\n", req.Email, err)
		return nil, "", err
	}
	return user, token, nil
}

func (s *service) SignUp(ctx context.Context, req domain.User) error {
	if err := s.userRepo.SignUp(ctx, req); err != nil {
		log.Printf("failed to sign up for email %s with error: %v\n", req.Email, err)
		return err
	}
	return nil
}

func (s *service) GetUsers(ctx context.Context, limit int64, cursor string) ([]domain.User, string, error) {
	users, nextCursor, err := s.userRepo.GetUsers(ctx, limit, cursor)
	if err != nil {
		log.Printf("failed to get users with error: %v\n", err)
		return nil, "", err
	}

	return users, nextCursor, nil
}

func (s *service) UpdateUser(ctx context.Context, req domain.User) error {
	return s.userRepo.UpdateUser(ctx, req)
}
