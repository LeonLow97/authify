package domain

type User struct {
	ID        int64
	Password  string
	FirstName string
	LastName  string
	Email     string
	Active    bool
	Admin     bool
}
