package outbound

import (
	"github.com/LeonLow97/internal/ports"
	"github.com/jmoiron/sqlx"
)

type Outbound struct {
	db *sqlx.DB
}

func NewOutbound(db *sqlx.DB) ports.Outbound {
	return &Outbound{
		db: db,
	}
}
