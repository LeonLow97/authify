package dto

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

type SignUpRequest struct {
	FirstName string `json:"first_name" validate:"required,min=1,max=50"`
	LastName  string `json:"last_name" validate:"required,min=1,max=50"`
	Password  string `json:"password" validate:"required,password_format,min=8,max=20"`
	Email     string `json:"email" validate:"required,email,min=10,max=100"`
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

type UpdateUserRequest struct {
	FirstName string `json:"first_name" validate:"omitempty,min=1,max=50"`
	LastName  string `json:"last_name" validate:"omitempty,min=1,max=50"`
	Password  string `json:"password" validate:"omitempty,password_format,min=8,max=20"`
	Email     string `json:"email" validate:"omitempty,email,min=10,max=100"`
}
