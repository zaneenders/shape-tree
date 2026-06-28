CREATE TABLE hb_persist (
    id      TEXT PRIMARY KEY,
    data    JSONB NOT NULL,
    expires TIMESTAMPTZ NOT NULL
);
