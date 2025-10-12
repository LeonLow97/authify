package inbound

import (
	"github.com/LeonLow97/internal/core/domain"
	"github.com/LeonLow97/internal/pkg/utils"
	pb "github.com/LeonLow97/proto"
)

func SanitizeGetUsersRequest(req *pb.GetUsersRequest) {
	// Minimum limit
	if req.Limit < 10 {
		req.Limit = 10
	}
	// Maximum Limit
	if req.Limit > 50 {
		req.Limit = 50
	}
}

func ToUpdateUserInput(req *pb.UpdateUserRequest) domain.UpdateUserInput {
	return domain.UpdateUserInput{
		FirstName: utils.SanitizePointer(&req.FirstName),
		LastName:  utils.SanitizePointer(&req.LastName),
		Password:  utils.SanitizePointer(&req.Password),
	}
}
