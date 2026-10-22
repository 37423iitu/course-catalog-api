\set ON_ERROR_STOP on
-- Run as a PostgreSQL administrator, connected to the postgres database.
-- In PowerShell: $env:CATALOG_DB_PASSWORD = 'your-password'
\getenv catalog_password CATALOG_DB_PASSWORD
\if :{?catalog_password}
\else
    \echo Set CATALOG_DB_PASSWORD before running bootstrap.sql.
    \quit 1
\endif
CREATE ROLE catalog_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD :'catalog_password';
CREATE DATABASE catalog_lab6 OWNER catalog_app ENCODING 'UTF8' TEMPLATE template0;
