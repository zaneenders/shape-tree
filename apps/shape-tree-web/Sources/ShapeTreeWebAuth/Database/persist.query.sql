-- @query PersistGet :one
-- @param id: String
-- @returns data: String, expires: Date
SELECT data::text, expires FROM hb_persist WHERE id = $1 AND expires > NOW();

-- @query PersistSet :exec
-- @param id: String
-- @param data: String
-- @param expires: Date
INSERT INTO hb_persist (id, data, expires) VALUES ($1, $2::jsonb, $3)
ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data, expires = EXCLUDED.expires;

-- @query PersistCreate :exec
-- @param id: String
-- @param data: String
-- @param expires: Date
INSERT INTO hb_persist (id, data, expires) VALUES ($1, $2::jsonb, $3);

-- @query PersistRemove :exec
-- @param id: String
DELETE FROM hb_persist WHERE id = $1;

-- @query PersistDeleteExpired :exec
DELETE FROM hb_persist WHERE expires < NOW();
