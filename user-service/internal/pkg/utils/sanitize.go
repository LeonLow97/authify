package utils

func ToPointer[T any](v T) *T {
	return &v
}

func FromPointer[T any](v *T) T {
	return *v
}
