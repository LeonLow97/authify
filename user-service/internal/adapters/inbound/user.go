package inbound

import (
	"context"
	"errors"

	"github.com/LeonLow97/internal/core/services"
	"github.com/LeonLow97/internal/pkg/contextstore"
	"github.com/LeonLow97/internal/pkg/grpcerror"
	pb "github.com/LeonLow97/proto"
	empty "google.golang.org/protobuf/types/known/emptypb"
)

type inbound struct {
	service services.Service
	pb.UserServiceServer
}

func NewInbound(s services.Service) *inbound {
	return &inbound{
		service: s,
	}
}

func (in *inbound) Login(ctx context.Context, req *pb.LoginRequest) (*pb.LoginResponse, error) {
	user, token, err := in.service.Login(ctx, toLoginInput(req))
	if err != nil {
		switch {
		case errors.Is(err, services.ErrInvalidCredentials) ||
			errors.Is(err, services.ErrInactiveUser) ||
			errors.Is(err, services.ErrUserNotFound):
			return nil, grpcerror.ECUnauthorized.GRPCError(err)
		default:
			return nil, grpcerror.ECInternalServerError.GRPCError(err)
		}
	}
	return toLoginResponse(user, token), nil
}

func (in *inbound) SignUp(ctx context.Context, req *pb.SignUpRequest) (*pb.SignUpResponse, error) {
	if err := in.service.SignUp(ctx, toSignUpInput(req)); err != nil {
		switch {
		case errors.Is(err, services.ErrEmailAlreadyExists):
			return nil, grpcerror.ECEmailAlreadyExists.GRPCError(err)
		default:
			return nil, grpcerror.ECInternalServerError.GRPCError(err)
		}
	}

	return &pb.SignUpResponse{
		Email: req.Email,
	}, nil
}

func (s *inbound) GetUsers(ctx context.Context, req *pb.GetUsersRequest) (*pb.GetUsersResponse, error) {
	// Retrieve admin user ID from grpc request metadata
	adminUserID, err := contextstore.UserIDFromContext(ctx)
	if err != nil {
		return nil, grpcerror.ECInternalServerError.GRPCError(err)
	}

	SanitizeGetUsersRequest(req)
	users, nextCursor, err := s.service.GetUsers(ctx, adminUserID, int64(req.Limit), req.Cursor)
	if err != nil {
		switch {
		case errors.Is(err, services.ErrUnauthorizedAdminAccess):
			return nil, grpcerror.ECUnauthorized.GRPCError(err)
		default:
			return nil, grpcerror.ECInternalServerError.GRPCError(err)
		}
	}

	// Convert []domain.User to []*pb.User
	grpcUsers := make([]*pb.User, len(users))
	for i, user := range users {
		grpcUsers[i] = &pb.User{
			ID:        user.ID,
			Email:     user.Email,
			FirstName: *user.FirstName,
			LastName:  *user.LastName,
			Active:    user.Active,
		}
	}

	return &pb.GetUsersResponse{
		Users:      grpcUsers,
		NextCursor: nextCursor,
	}, nil
}

func (s *inbound) UpdateUser(ctx context.Context, req *pb.UpdateUserRequest) (*empty.Empty, error) {
	// Retrieve user ID from grpc request metadata
	userID, err := contextstore.UserIDFromContext(ctx)
	if err != nil {
		return nil, grpcerror.ECInternalServerError.GRPCError(err)
	}

	updateUserInput := ToUpdateUserInput(req)
	if err := s.service.UpdateUser(ctx, int64(userID), updateUserInput); err != nil {
		switch {
		case errors.Is(err, services.ErrUserNotFound):
			return nil, grpcerror.ECUnauthorized.GRPCError(err)
		default:
			return nil, grpcerror.ECInternalServerError.GRPCError(err)
		}
	}
	return &empty.Empty{}, nil
}
