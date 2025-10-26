package dto

import "github.com/LeonLow97/internal/core/domain"

type LoginRequest struct {
	Email    string `json:"email" validate:"required,email,min=10,max=100"`
	Password string `json:"password" validate:"required,password_format,min=8,max=20"`
}

type LoginResponse struct {
	FirstName string `json:"first_name,omitempty"`
	LastName  string `json:"last_name,omitempty"`
	Email     string `json:"email,omitempty"`
	Active    bool   `json:"active,omitempty"`
	Admin     bool   `json:"admin,omitempty"`
}

func FromLoginRequest(req *LoginRequest) domain.User {
	return domain.User{
		Email:    req.Email,
		Password: req.Password,
	}
}

func ToLoginResponse(u *domain.User) LoginResponse {
	return LoginResponse{
		FirstName: u.FirstName,
		LastName:  u.LastName,
		Email:     u.Email,
		Active:    u.Active,
		Admin:     u.Admin,
	}
}

type SignUpRequest struct {
	FirstName string `json:"first_name" validate:"required,min=1,max=50"`
	LastName  string `json:"last_name" validate:"required,min=1,max=50"`
	Password  string `json:"password" validate:"required,password_format,min=8,max=20"`
	Email     string `json:"email" validate:"required,email,min=10,max=100"`
}

func FromSignUpRequest(req *SignUpRequest) domain.User {
	return domain.User{
		FirstName: req.FirstName,
		LastName:  req.LastName,
		Password:  req.Password,
		Email:     req.Email,
	}
}

type User struct {
	ID        int64  `json:"id"`
	FirstName string `json:"first_name,omitempty"`
	LastName  string `json:"last_name,omitempty"`
	Email     string `json:"email,omitempty"`
	Active    bool   `json:"active,omitempty"`
	Admin     bool   `json:"admin,omitempty"`
	Token     string `json:"-"`
}

type GetUsersResponse struct {
	Users      []User `json:"users"`
	NextCursor string `json:"next_cursor"`
}

func ToGetUsersResponse(domainUsers []domain.User, nextCursor string) GetUsersResponse {
	users := make([]User, len(domainUsers))
	for i, u := range domainUsers {
		users[i] = User{
			ID:        u.ID,
			FirstName: u.FirstName,
			LastName:  u.LastName,
			Email:     u.Email,
			Active:    u.Active,
			Admin:     u.Admin,
		}
	}
	return GetUsersResponse{
		Users:      users,
		NextCursor: nextCursor,
	}
}

type UpdateUserRequest struct {
	FirstName string `json:"first_name" validate:"omitempty,min=1,max=50"`
	LastName  string `json:"last_name" validate:"omitempty,min=1,max=50"`
	Password  string `json:"password" validate:"omitempty,password_format,min=8,max=20"`
	Email     string `json:"email" validate:"omitempty,email,min=10,max=100"`
}

func FromUpdateUserRequest(req *UpdateUserRequest) domain.User {
	return domain.User{
		FirstName: req.FirstName,
		LastName:  req.LastName,
		Password:  req.Password,
		Email:     req.Email,
	}
}
