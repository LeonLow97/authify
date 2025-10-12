package outbound

import (
	"context"

	"github.com/LeonLow97/internal/core/domain"
	"github.com/LeonLow97/internal/ports"
	pb "github.com/LeonLow97/proto"
)

type userOutbound struct {
	conn pb.UserServiceClient
}

func NewUserOutbound(conn pb.UserServiceClient) ports.UserOutbound {
	return &userOutbound{
		conn: conn,
	}
}

func (r *userOutbound) Login(ctx context.Context, req domain.User) (*domain.User, string, error) {
	grpcReq := &pb.LoginRequest{
		Email:    req.Email,
		Password: req.Password,
	}

	grpcResp, err := r.conn.Login(ctx, grpcReq)
	if err != nil {
		return nil, "", err
	}

	return &domain.User{
		FirstName: grpcResp.FirstName,
		LastName:  grpcResp.LastName,
		Email:     grpcResp.Email,
		Active:    grpcResp.Active,
		Admin:     grpcResp.Admin,
	}, grpcResp.Token, nil
}

func (r *userOutbound) SignUp(ctx context.Context, req domain.User) error {
	grpcReq := &pb.SignUpRequest{
		Email:     req.Email,
		Password:  req.Password,
		FirstName: req.FirstName,
		LastName:  req.LastName,
	}

	_, err := r.conn.SignUp(ctx, grpcReq)
	return err
}

func (r *userOutbound) GetUsers(ctx context.Context, limit int64, cursor string) ([]domain.User, string, error) {
	grpcReq := &pb.GetUsersRequest{
		Limit:  limit,
		Cursor: cursor,
	}

	grpcResp, err := r.conn.GetUsers(ctx, grpcReq)
	if err != nil {
		return nil, "", err
	}

	users := make([]domain.User, len(grpcResp.Users))
	for i, grpcUser := range grpcResp.Users {
		users[i] = domain.User{
			ID:        grpcUser.ID,
			FirstName: grpcUser.FirstName,
			LastName:  grpcUser.LastName,
			Email:     grpcUser.Email,
			Active:    grpcUser.Active,
			Admin:     grpcUser.Admin,
		}
	}

	return users, grpcResp.NextCursor, nil
}

func (r *userOutbound) UpdateUser(ctx context.Context, req domain.User) error {
	grpcReq := &pb.UpdateUserRequest{
		FirstName: req.FirstName,
		LastName:  req.LastName,
		Password:  req.Password,
	}

	_, err := r.conn.UpdateUser(ctx, grpcReq)
	return err
}
