package inbound

import (
	"strings"

	"github.com/LeonLow97/internal/core/domain"
	"github.com/LeonLow97/internal/pkg/utils"
	pb "github.com/LeonLow97/proto"
)

func toLoginInput(req *pb.LoginRequest) domain.LoginInput {
	return domain.LoginInput{
		Email:    strings.TrimSpace(req.Email),
		Password: strings.TrimSpace(req.Password),
	}
}

func toLoginResponse(user *domain.User, token string) *pb.LoginResponse {
	return &pb.LoginResponse{
		FirstName: utils.FromPointer(user.FirstName),
		LastName:  utils.FromPointer(user.LastName),
		Email:     user.Email,
		Active:    user.Active,
		Admin:     user.Admin,
		Token:     token,
	}
}

func toSignUpInput(req *pb.SignUpRequest) domain.SignUpInput {
	return domain.SignUpInput{
		Email:     strings.TrimSpace(req.Email),
		Password:  strings.TrimSpace(req.Password),
		FirstName: strings.TrimSpace(req.FirstName),
		LastName:  strings.TrimSpace(req.LastName),
	}
}

func toGetUsersResponse(users []domain.User, nextCursor string) *pb.GetUsersResponse {
	grpcUsers := make([]*pb.User, 0, len(users))
	for _, user := range users {
		grpcUsers = append(grpcUsers, &pb.User{
			ID:        user.ID,
			Email:     user.Email,
			FirstName: *user.FirstName,
			LastName:  *user.LastName,
			Active:    user.Active,
		})
	}
	return &pb.GetUsersResponse{
		Users:      grpcUsers,
		NextCursor: nextCursor,
	}
}

func ToUpdateUserInput(req *pb.UpdateUserRequest) domain.UpdateUserInput {
	return domain.UpdateUserInput{
		FirstName: utils.ToPointer(req.FirstName),
		LastName:  utils.ToPointer(req.LastName),
		Password:  utils.ToPointer(req.Password),
	}
}

func SanitizePaginationCursor(limit int64) int64 {
	if limit <= 0 {
		return 10
	}
	if limit > 50 {
		return 50
	}
	return limit
}
