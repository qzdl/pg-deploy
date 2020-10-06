--              ██     ██          ██ ██                ██
--             ░██    ░██         ░░ ░██               ░██
--   ██████   ██████ ██████ ██████ ██░██      ██   ██ ██████  █████   ██████
--  ░░░░░░██ ░░░██░ ░░░██░ ░░██░░█░██░██████ ░██  ░██░░░██░  ██░░░██ ██░░░░
--   ███████   ░██    ░██   ░██ ░ ░██░██░░░██░██  ░██  ░██  ░███████░░█████
--  ██░░░░██   ░██    ░██   ░██   ░██░██  ░██░██  ░██  ░██  ░██░░░░  ░░░░░██
-- ░░████████  ░░██   ░░██ ░███   ░██░██████ ░░██████  ░░██ ░░██████ ██████
--  ░░░░░░░░    ░░     ░░  ░░░    ░░ ░░░░░    ░░░░░░    ░░   ░░░░░░ ░░░░░░
-- attributes:
--
BEGIN;
SET client_min_messages TO WARNING;
CREATE EXTENSION pgdeploy;
CREATE SCHEMA if NOT EXISTS testr;
CREATE SCHEMA if NOT EXISTS testp;
CREATE TABLE testr.a(i int, ii text, iii bit);
CREATE TABLE testp.a(ii text, iv numeric CONSTRAINT positive_price CHECK (iv > 0));

SELECT pgdeploy.reconcile_table_attributes(
    'testr'::name, 'a'::name, 'testr.a'::regclass::oid
    ,'testp'::name, 'a'::name, 'testp.a'::regclass::oid);

-- CLEAN UP
DROP EXTENSION pgdeploy CASCADE;
ROLLBACK;
