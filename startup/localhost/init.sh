# API Gateway
cd ../api-gateway
go run ./cmd/api/*.go

# User Service
cd ../user-service
go run ./cmd/api/*.go

# Redis Server
redis-server

# Postgres
psql postgres # connect to postgres

CREATE ROLE authify WITH LOGIN PASSWORD 'dba872b7';
CREATE DATABASE authify_users_db OWNER authify;
GRANT ALL PRIVILEGES ON DATABASE authify_users_db TO authify;

psql -U authify -d authify_users_db # connect to authify_users_db
# Run user-service/schema/users.sql to create table
