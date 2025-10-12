package domain

import (
	"strings"
	"time"

	"github.com/LeonLow97/internal/pkg/utils"
)

type AdminUser struct {
	UserID    int64     `db:"user_id"`
	Active    bool      `db:"active"`
	UpdatedAt time.Time `db:"updated_at"`
	CreatedAt time.Time `db:"created_at"`
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

// Sanitize trims leading and trailing whitespace from string fields in User struct
func (u *User) Sanitize() {
	u.FirstName = utils.SanitizePointer(u.FirstName)
	u.LastName = utils.SanitizePointer(u.LastName)
	u.Email = strings.TrimSpace(u.Email)
	u.HashedPassword = utils.SanitizePointer(u.HashedPassword)
}

type UpdateUserInput struct {
	FirstName *string
	LastName  *string
	Password  *string
}

type UserCursor struct {
	ID int64 `json:"id"`
}
