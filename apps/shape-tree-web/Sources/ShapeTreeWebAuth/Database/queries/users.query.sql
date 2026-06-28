-- @query GetUserByEmail :one
-- @param email: String
-- @returns id: UUID, email: String, created_at: Date
SELECT id, email, created_at FROM users WHERE email = $1;

-- @query GetUserByID :one
-- @param id: UUID
-- @returns id: UUID, email: String, created_at: Date
SELECT id, email, created_at FROM users WHERE id = $1;

-- @query CreateUser :exec
-- @param id: UUID
-- @param email: String
INSERT INTO users (id, email) VALUES ($1, $2);
