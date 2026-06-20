-- @query CreateLoginToken :exec
-- @param id: UUID
-- @param user_id: UUID
-- @param token_hash: String
-- @param expires_at: Date
INSERT INTO login_tokens (id, user_id, token_hash, expires_at) VALUES ($1, $2, $3, $4);

-- @query GetLoginTokenByHash :one
-- @param token_hash: String
-- @returns id: UUID, user_id: UUID, token_hash: String, expires_at: Date
SELECT id, user_id, token_hash, expires_at
FROM login_tokens
WHERE token_hash = $1 AND expires_at > NOW();

-- @query DeleteLoginToken :exec
-- @param id: UUID
DELETE FROM login_tokens WHERE id = $1;

-- @query DeleteExpiredLoginTokens :exec
DELETE FROM login_tokens WHERE expires_at < NOW();
