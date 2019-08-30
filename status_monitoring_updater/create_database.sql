-- This script must be ran with psql because it contains psql commands
-- Setup
CREATE DATABASE peertube_index;
\c peertube_index;

CREATE TYPE instance_status AS ENUM ('discovered', 'ok', 'error', 'banned');
-- This type must exist to allowing importing the remote schema
-- TODO: use same type names between the two databases to avoid this duplication type creation
CREATE TYPE status AS ENUM ('ok', 'error', 'discovered', 'banned');

CREATE TABLE instance (
    host varchar PRIMARY KEY NOT NULL,
    status instance_status NOT NULL,
    reason varchar,
    date timestamp NOT NULL
);

CREATE TABLE history (
    status instance_status,
    count int NOT NULL,
    import_time timestamp,
    PRIMARY KEY(status, import_time)
);

CREATE EXTENSION postgres_fdw;

CREATE SERVER source_database
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (host :source_host, dbname :source_database);

CREATE USER MAPPING FOR CURRENT_USER
SERVER source_database
OPTIONS (user :source_user);

CREATE SCHEMA imported_schema;

IMPORT FOREIGN SCHEMA public
FROM SERVER source_database INTO imported_schema;
