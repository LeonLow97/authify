package outbound

import (
	"github.com/LeonLow97/internal/ports"
	"github.com/jmoiron/sqlx"
)

type Repository struct {
	db *sqlx.DB
}

func NewRepository(db *sqlx.DB) ports.Repository {
	return &Repository{
		db: db,
	}
}
