package domain

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
