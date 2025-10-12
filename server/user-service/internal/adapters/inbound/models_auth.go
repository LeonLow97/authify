package inbound

import (
	"strings"

	"github.com/LeonLow97/internal/core/domain"
	pb "github.com/LeonLow97/proto"
)

func ToLoginInput(req *pb.LoginRequest) domain.LoginInput {
	return domain.LoginInput{
		Email:    strings.TrimSpace(req.Email),
		Password: strings.TrimSpace(req.Password),
	}
}

func ToSignUpInput(req *pb.SignUpRequest) domain.SignUpInput {
	return domain.SignUpInput{
		Email:     strings.TrimSpace(req.Email),
		Password:  strings.TrimSpace(req.Password),
		FirstName: strings.TrimSpace(req.FirstName),
		LastName:  strings.TrimSpace(req.LastName),
	}
}
