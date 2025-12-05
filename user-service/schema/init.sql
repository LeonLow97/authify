/*
	Localhost
*/
-- psql postgres # connect to postgres

CREATE ROLE authify WITH LOGIN PASSWORD 'dba872b7';
CREATE DATABASE authify_users_db OWNER authify;
GRANT ALL PRIVILEGES ON DATABASE authify_users_db TO authify;

-- psql -U authify -d authify_users_db # connect to authify_users_db

/*
	Docker
*/
-- docker exec -it <container_name> bash
-- psql -U authify -d authify_users_db
-- authify_users_db=#
