package handler

import (
	"log"
	"strings"

	"github.com/LeonLow97/internal/pkg/validation"
	"github.com/go-playground/validator/v10"
)

func (h Handler) ValidateStruct(v any) error {
	return h.validator.Struct(v)
}

// validatorInstance creates and returns a new validator instance with custom validations
func validatorInstance() *validator.Validate {
	validatorInstance := validator.New()

	// Valid Password format
	if err := validatorInstance.RegisterValidation("password_format", func(f1 validator.FieldLevel) bool {
		return validation.IsValidPassword(strings.TrimSpace(f1.Field().String()))
	}); err != nil {
		log.Println("failed to register password format validation")
	}

	return validatorInstance
}
