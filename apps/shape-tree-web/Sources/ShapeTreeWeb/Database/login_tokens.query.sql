-- @query CreateLoginToken :exec
-- @param id: UUID
-- @param user_id: UUID
-- @param token_hash: String
-- @param expires_at: Date
INSERT INTO login_tokens (id, user_id, token_hash, expires_at) VALUES ($1, $2, $3, $4);

-- @query ConsumeLoginToken :one
-- @param token_hash: String
-- @returns user_id: UUID
DELETE FROM login_tokens WHERE token_hash = $1 AND expires_at > NOW() RETURNING user_id;

-- @query DeleteExpiredLoginTokens :exec
DELETE FROM login_tokens WHERE expires_at < NOW();
