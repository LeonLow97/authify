package cursor

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
)

// EncodeCursor converts a cursor struct to a base64 string
func EncodeCursor(cursor any) (string, error) {
	jsonData, err := json.Marshal(cursor)
	if err != nil {
		return "", fmt.Errorf("failed to encode cursor: %w", err)
	}
	return base64.StdEncoding.EncodeToString(jsonData), nil
}

// DecodeCursor decodes a base64 cursor string back into a struct
func DecodeCursor(cursorStr string, cursor any) error {
	if cursorStr == "" {
		return nil
	}
	data, err := base64.StdEncoding.DecodeString(cursorStr)
	if err != nil {
		return fmt.Errorf("failed to decode cursor: %w", err)
	}
	return json.Unmarshal(data, cursor)
}
