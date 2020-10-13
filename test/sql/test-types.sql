-- types
-- http://stackoverflow.com/questions/25811017/ddg#25812436
-- cannot drop individual items
-- https://www.postgresql.org/docs/current/datatype-enum.html
-- "Existing values cannot be removed from an enum type, nor can the sort
-- ordering of such values be changed, short of dropping and re-creating the
-- enum type."

BEGIN;
SET client_min_messages TO WARNING;
CREATE EXTENSION pgdeploy;

CREATE SCHEMA testr;
CREATE SCHEMA testp;
CREATE TYPE testp.myenum AS ENUM ('arp', 'yarp', 'yep', 'yes', 'affirmative');


-- @illegal: DROP VALUE
-- ALTER TYPE testp.myenum drop value 'arp';

CREATE TYPE testp.myrange AS RANGE (subtype = float8, subtype_diff = float8mi);
CREATE TYPE testp.mycomp AS (f1 int, f2 text);
CREATE TYPE testp.mycompint AS (f1 int, f2 int);
CREATE TYPE testp.empty;

-- base type (FIXME: on hold)
-- DROP function if exists testp.fin;
-- DROP function if exists testp.fout;
-- create or replace function testp.fin(a int) returns int as $body$ begin return 0; end; $body$ language plpgsql;
-- create or replace function testp.fout(a int) returns int as $body$ begin return 0; end; $body$ language plpgsql;
-- CREATE TYPE testp.io AS (input = testp.fin, output = testp.fout);


-- DIFFERENCE ENUM

CREATE TYPE testp.enumsame AS ENUM ('arp', 'yarp', 'yep', 'yes', 'affirmative');
CREATE TYPE testr.enumsame AS ENUM ('arp', 'yarp', 'yep', 'yes', 'affirmative');

CREATE TYPE testp.enumdroplast AS ENUM ('arp', 'yarp', 'yep', 'yes', 'affirmative');
CREATE TYPE testr.enumdroplast AS ENUM ('arp', 'yarp', 'yep', 'yes');

CREATE TYPE testp.enumdropfirst AS ENUM ('0','1','2','3','4');
CREATE TYPE testr.enumdropfirst AS ENUM ('1','2','3','4');

CREATE TYPE testp.enumdropmid AS ENUM ('arp', 'yarp', 'yep', 'yes', 'affirmative');
CREATE TYPE testr.enumdropmid AS ENUM ('arp', 'yarp', 'yes', 'affirmative');

CREATE TYPE testp.enumaddlast AS ENUM ('arp', 'yarp', 'yep', 'yes');
CREATE TYPE testr.enumaddlast AS ENUM ('arp', 'yarp', 'yep', 'yes', 'affirmative');

CREATE TYPE testp.enumaddfirst AS ENUM ('arp', 'yarp', 'yep', 'yes');
CREATE TYPE testr.enumaddfirst AS ENUM ('affirmative', 'arp', 'yarp', 'yep', 'yes');


CREATE TYPE testp.enumaddmid AS ENUM ('arp', 'yarp', 'yep', 'yes');
CREATE TYPE testr.enumaddmid AS ENUM ('arp', 'affirmative', 'yarp', 'yep', 'yes');

SELECT * FROM pgdeploy.object_difference('testp', 'testr', 'pgdeploy.cte_type');
-- CLEAN UP
DROP EXTENSION pgdeploy CASCADE;
ROLLBACK;
