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
CREATE SCHEMA if NOT EXISTS testr;
CREATE SCHEMA if NOT EXISTS testp;
DROP TABLE if EXISTS testr.a;
DROP TABLE if EXISTS testp.a;

CREATE TABLE testr.a(i int, ii text, iii bit);
CREATE TABLE testp.a(ii text, iv numeric CONSTRAINT positive_price CHECK (iv > 0));


SELECT pgdeploy.reconcile_table_attributes('testr', 'testp', 'a', 'a');

END;
