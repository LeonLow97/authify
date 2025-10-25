package services

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/LeonLow97/internal/cache"
	"github.com/LeonLow97/internal/core/domain"
	"github.com/LeonLow97/internal/pkg/utils"
	"github.com/golang-jwt/jwt/v4"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
)

// Login performs authentication with bcrypt comparison of hashed password and provided password
func (s service) Login(ctx context.Context, loginInput domain.LoginInput) (*domain.User, string, error) {
	user, err := s.repo.GetUserByEmail(ctx, loginInput.Email)
	if err != nil {
		return nil, "", fmt.Errorf("failed to get user with error: %v", err)
	}

	if err := bcrypt.CompareHashAndPassword(
		[]byte(utils.FromPointer(user.HashedPassword)),
		[]byte(loginInput.Password),
	); err != nil {
		switch {
		case errors.Is(err, bcrypt.ErrMismatchedHashAndPassword) ||
			errors.Is(err, bcrypt.ErrHashTooShort):
			return nil, "", ErrInvalidCredentials
		default:
			return nil, "", fmt.Errorf("password verification failed for user %d: %w", user.ID, err)
		}
	}

	if !user.Active {
		return nil, "", ErrInactiveUser
	}

	// Create user session and store in cache
	sessionID := uuid.NewString()
	expiry := time.Duration(s.cfg.JWTConfig.Expiry) * time.Minute

	// Add small buffer to Redis TTL to handle clock drift and network latency
	const driftBuffer = time.Minute
	ttlSeconds := int64((expiry + driftBuffer).Seconds())

	if err := s.storeUserSessionInCache(ctx, sessionID, user.ID, ttlSeconds); err != nil {
		return nil, "", err
	}

	token, err := s.generateJWTToken(user.ID, sessionID, expiry)
	if err != nil {
		return nil, "", err
	}

	return user, token, nil
}

func (s service) SignUp(ctx context.Context, signupInput domain.SignUpInput) error {
	emailExists, err := s.repo.EmailExists(ctx, signupInput.Email)
	if err != nil {
		return fmt.Errorf("failed to check if email '%s' exists with error: %v", signupInput.Email, err)
	}
	if emailExists {
		return ErrEmailAlreadyExists
	}

	// Generate hashed password from plain text password via bcrypt
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(signupInput.Password), 10)
	if err != nil {
		return fmt.Errorf("failed to hash password for email '%s' with error: %v\n", signupInput.Email, err)
	}

	user := &domain.User{
		Email:          signupInput.Email,
		HashedPassword: utils.ToPointer(string(hashedPassword)),
		FirstName:      utils.ToPointer(signupInput.FirstName),
		LastName:       utils.ToPointer(signupInput.LastName),
	}
	if err := s.repo.InsertUser(ctx, user); err != nil {
		return fmt.Errorf("failed to insert user during signup with error: %v\n", err)
	}

	return nil
}

func (s service) generateJWTToken(userID int64, sessionID string, expiry time.Duration) (string, error) {
	expirationTime := time.Now().Add(expiry)
	claims := CustomClaims{
		SessionID: sessionID,
		UserID:    userID,
		RegisteredClaims: jwt.RegisteredClaims{
			Issuer:    "user-service",
			Subject:   fmt.Sprintf("%d", userID),
			ExpiresAt: jwt.NewNumericDate(expirationTime),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}
	generateToken := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signedToken, err := generateToken.SignedString([]byte(s.cfg.JWTConfig.SecretKey))
	if err != nil {
		return "", fmt.Errorf("failed to generate JWT token for user id '%d' with error: %v", userID, err)
	}
	return signedToken, nil
}

func (s service) storeUserSessionInCache(ctx context.Context, sessionID string, userID int64, ttlSeconds int64) error {
	key := fmt.Sprintf(cache.UserSession, sessionID)
	_, err := s.appCache.SetNX(ctx, key, userID, ttlSeconds)
	if err != nil {
		return fmt.Errorf("failed to set user session in cache with error: %w", err)
	}
	return nil
}
