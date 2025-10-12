package validation

import (
	"strings"
)

// IsValidPassword checks if the provided string meets password complexity requirements.
// It enforces the password to contain at least one lowercase letter, one uppercase letter,
// one numeric digit, one special character, and have a minimum length of 8 characters.
func IsValidPassword(password string) bool {
	var (
		hasUpper, hasLower, hasDigit, hasSpecial bool
	)

	for _, char := range password {
		switch {
		case 'A' <= char && char <= 'Z':
			hasUpper = true
		case 'a' <= char && char <= 'z':
			hasLower = true
		case '0' <= char && char <= '9':
			hasDigit = true
		case strings.ContainsAny(string(char), "@$!%*?&"):
			hasSpecial = true
		}
	}

	return hasUpper && hasLower && hasDigit && hasSpecial
}
