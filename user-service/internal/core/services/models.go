package services

import "github.com/golang-jwt/jwt/v4"

type CustomClaims struct {
	SessionID string `json:"session_id"`
	UserID    int64  `json:"user_id"`
	jwt.RegisteredClaims
}
