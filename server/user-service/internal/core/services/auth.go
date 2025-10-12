package services

import (
	"context"
	"log"
	"time"

	"github.com/LeonLow97/internal/core/domain"
	"github.com/LeonLow97/internal/pkg/utils"
	"golang.org/x/crypto/bcrypt"
)

// Login performs authentication with bcrypt comparison of hashed password and provided password
func (s service) Login(ctx context.Context, loginInput domain.LoginInput) (*domain.User, string, error) {
	// Retrieve user details by email
	user, err := s.repo.GetUserByEmail(ctx, loginInput.Email)
	if err != nil {
		log.Printf("failed to retrieve user by email '%s' during login with error: %v\n", loginInput.Email, err)
		return nil, "", err
	}

	// Compare hashed password with user supplied plain text password
	if err := bcrypt.CompareHashAndPassword([]byte(*user.HashedPassword), []byte(loginInput.Password)); err != nil {
		switch {
		case err == bcrypt.ErrMismatchedHashAndPassword,
			err == bcrypt.ErrHashTooShort:
			log.Printf("invalid credentials for user id '%d' when performing bcrypt comparison\n", user.ID)
			return nil, "", ErrInvalidCredentials
		default:
			log.Printf("failed to compare hash and password with error: %v\n", err)
			return nil, "", err
		}
	}

	// If user is inactive, block login operation
	if !user.Active {
		log.Printf("user id '%d' is inactive\n", user.ID)
		return nil, "", ErrInactiveUser
	}

	// Generate JWT token for user
	token, err := utils.GenerateJWTToken(user.ID, time.Duration(s.cfg.JWTConfig.Expiry)*time.Minute, s.cfg.JWTConfig.SecretKey)
	if err != nil {
		log.Printf("failed to generate JWT token for user id '%d'\n", user.ID)
		return nil, "", err
	}

	return user, token, err
}

func (s service) SignUp(ctx context.Context, signupInput domain.SignUpInput) error {
	emailExists, err := s.repo.EmailExists(ctx, signupInput.Email)
	if err != nil {
		log.Printf("failed to check if email has been taken for email '%s' with error: %v\n", signupInput.Email, err)
		return err
	}
	if emailExists {
		return ErrEmailAlreadyExists
	}

	// Generate hashed password from plain text password via bcrypt
	hashed, err := bcrypt.GenerateFromPassword([]byte(signupInput.Password), 10)
	if err != nil {
		log.Printf("failed to hash password for email '%s' with error: %v\n", signupInput.Email, err)
		return err
	}
	hashedStr := string(hashed)
	hashedPassword := &hashedStr

	user := &domain.User{
		Email:          signupInput.Email,
		HashedPassword: hashedPassword,
		FirstName:      &signupInput.FirstName,
		LastName:       &signupInput.LastName,
	}
	if err := s.repo.InsertUser(ctx, user); err != nil {
		log.Printf("failed to insert user during signup with error: %v\n", err)
		return err
	}

	return nil
}
