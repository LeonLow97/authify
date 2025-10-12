package inbound

import (
	"context"
	"errors"

	"github.com/LeonLow97/internal/core/services"
	"github.com/LeonLow97/internal/pkg/grpcerror"
	pb "github.com/LeonLow97/proto"
)

type authInbound struct {
	service services.Service
	pb.AuthenticationServiceServer
}

func NewAuthGRPCServer(s services.Service) *authInbound {
	return &authInbound{
		service: s,
	}
}

func (s *authInbound) Login(ctx context.Context, req *pb.LoginRequest) (*pb.LoginResponse, error) {
	loginInput := ToLoginInput(req)
	user, token, err := s.service.Login(ctx, loginInput)
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

	return &pb.LoginResponse{
		FirstName: *user.FirstName,
		LastName:  *user.LastName,
		Email:     user.Email,
		Active:    user.Active,
		Admin:     user.Admin,
		Token:     token,
	}, nil
}

func (s *authInbound) SignUp(ctx context.Context, req *pb.SignUpRequest) (*pb.SignUpResponse, error) {
	signupInput := ToSignUpInput(req)
	if err := s.service.SignUp(ctx, signupInput); err != nil {
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
