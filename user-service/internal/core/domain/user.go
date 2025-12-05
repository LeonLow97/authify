package domain

import (
	"time"
)

type LoginInput struct {
	Email    string
	Password string
}

type SignUpInput struct {
	Email     string
	Password  string
	FirstName string
	LastName  string
}

type User struct {
	ID             int64     `db:"id"`
	Email          string    `db:"email"`
	HashedPassword *string   `db:"hashed_password"`
	FirstName      *string   `db:"first_name"`
	LastName       *string   `db:"last_name"`
	Active         bool      `db:"active"`
	Admin          bool      `db:"admin"`
	UpdatedAt      time.Time `db:"updated_at"`
	CreatedAt      time.Time `db:"created_at"`
}

type UpdateUserInput struct {
	FirstName *string
	LastName  *string
	Password  *string
}

type UserCursor struct {
	ID int64 `json:"id"`
}
