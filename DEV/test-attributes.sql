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
CREATE SCHEMA if NOT EXISTS testr;
CREATE SCHEMA if NOT EXISTS testp;
DROP TABLE if EXISTS testr.a;
DROP TABLE if EXISTS testp.a;

-- create objs for diff
-- expecting:
--   DROP i
--   DROP iii
--   ADD iv text
CREATE TABLE testr.a(i int, ii text, iii bit);
CREATE TABLE testp.a(ii text, iv numeric CONSTRAINT positive_price CHECK (iv > 0));

SELECT deploy.reconcile_tables('testr', 'testp', 'a', 'a');
