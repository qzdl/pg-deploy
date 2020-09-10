-- types
-- http://stackoverflow.com/questions/25811017/ddg#25812436
-- cannot drop individual items
-- https://www.postgresql.org/docs/current/datatype-enum.html
-- "Existing values cannot be removed from an enum type, nor can the sort
-- ordering of such values be changed, short of dropping and re-creating the
-- enum type."
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
DROP TYPE IF EXISTS testp.enumsame;
DROP TYPE IF EXISTS testr.enumsame;
CREATE TYPE testp.enumsame AS ENUM ('arp', 'yarp', 'yep', 'yes', 'affirmative');
CREATE TYPE testr.enumsame AS ENUM ('arp', 'yarp', 'yep', 'yes', 'affirmative');

DROP TYPE IF EXISTS testp.enumdroplast;
DROP TYPE IF EXISTS testr.enumdroplast;
CREATE TYPE testp.enumdroplast AS ENUM ('arp', 'yarp', 'yep', 'yes', 'affirmative');
CREATE TYPE testr.enumdroplast AS ENUM ('arp', 'yarp', 'yep', 'yes');

DROP TYPE IF EXISTS testp.enumdropfirst;
DROP TYPE IF EXISTS testr.enumdropfirst;
CREATE TYPE testp.enumdropfirst AS ENUM (0,1,2,3,4);
CREATE TYPE testr.enumdropfirst AS ENUM (1,2,3,4);

DROP TYPE IF EXISTS testp.enumdropmid;
DROP TYPE IF EXISTS testr.enumdropmid;
CREATE TYPE testp.enumdropmid AS ENUM ('arp', 'yarp', 'yep', 'yes', 'affirmative');
CREATE TYPE testr.enumdropmid AS ENUM ('arp', 'yarp', 'yes', 'affirmative');

DROP TYPE IF EXISTS testp.enumaddlast;
DROP TYPE IF EXISTS testr.enumaddlast;
CREATE TYPE testp.enumaddlast AS ENUM ('arp', 'yarp', 'yep', 'yes');
CREATE TYPE testr.enumaddlast AS ENUM ('arp', 'yarp', 'yep', 'yes', 'affirmative');

DROP TYPE IF EXISTS testp.enumaddfirst;
DROP TYPE IF EXISTS testr.enumaddfirst;
CREATE TYPE testp.enumaddfirst AS ENUM ('arp', 'yarp', 'yep', 'yes');
CREATE TYPE testr.enumaddfirst AS ENUM ('affirmative', 'arp', 'yarp', 'yep', 'yes');

DROP TYPE IF EXISTS testp.enumaddmid;
DROP TYPE IF EXISTS testr.enumaddmid;
CREATE TYPE testp.enumaddmid AS ENUM ('arp', 'yarp', 'yep', 'yes');
CREATE TYPE testr.enumaddmid AS ENUM ('arp', 'affirmative', 'yarp', 'yep', 'yes');

SELECT * FROM object_difference('testp', 'testr', 'deploy.cte_type');
