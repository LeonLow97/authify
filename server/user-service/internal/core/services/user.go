package services

import (
	"context"
	"log"

	"github.com/LeonLow97/internal/core/domain"
	"github.com/LeonLow97/internal/pkg/cursor"
	"golang.org/x/crypto/bcrypt"
)

func (s service) GetUsers(ctx context.Context, adminUserID int64, limit int64, cursorStr string) ([]domain.User, string, error) {
	// Check if user is an admin user
	isAdminUser, err := s.repo.IsAdminUser(ctx, adminUserID)
	if err != nil {
		log.Println("failed to get admin user")
		return nil, "", err
	}
	if !isAdminUser {
		log.Println("unauthorized access, user is not an admin")
		return nil, "", ErrUnauthorizedAdminAccess
	}

	// Decode the cursor
	var userCursor domain.UserCursor
	if err := cursor.DecodeCursor(cursorStr, &userCursor); err != nil {
		log.Println("failed to decode cursor in get users")
		return nil, "", err
	}

	users, err := s.repo.GetUsers(ctx, limit, userCursor)
	if err != nil {
		log.Println("failed to get users")
		return nil, "", err
	}

	// Encode the next cursor based on the last user's ID
	var nextCursor string
	if len(users) > 0 {
		lastUserID := users[len(users)-1].ID
		nextCursor, err = cursor.EncodeCursor(domain.UserCursor{ID: lastUserID})
		if err != nil {
			log.Println("failed to encode cursor in get users")
			return nil, "", err
		}
	}

	return users, nextCursor, nil
}

func (s service) UpdateUser(ctx context.Context, userID int64, updateUserInput domain.UpdateUserInput) error {
	var hashedPassword *string
	if updateUserInput.Password != nil && *updateUserInput.Password != "" {
		hashed, err := bcrypt.GenerateFromPassword([]byte(*updateUserInput.Password), bcrypt.DefaultCost)
		if err != nil {
			log.Printf("failed to generate updated password for user id '%d' with error: %v\n", userID, err)
			return err
		}
		hashedStr := string(hashed)
		hashedPassword = &hashedStr
	}

	updateUser := &domain.User{
		ID:             userID,
		HashedPassword: hashedPassword,
		FirstName:      updateUserInput.FirstName,
		LastName:       updateUserInput.LastName,
	}

	if err := s.repo.UpdateUserByID(ctx, updateUser); err != nil {
		log.Printf("failed to update user by id '%d' with error: %v\n", userID, err)
		return err
	}

	return nil
}
