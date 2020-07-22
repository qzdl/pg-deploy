BEGIN;


CREATE SCHEMA my_schema;

CREATE FUNCTION my_schema.old_dummy(val integer)
RETURNS integer AS $$
  BEGIN
  RETURN val;
  END; $$ LANGUAGE plpgsql IMMUTABLE;

CREATE FUNCTION my_schema.code(val integer, val2 integer DEFAULT 0)
RETURNS numeric AS $$
  BEGIN
  -- Cantor pairing
  RETURN (1/2*(val+val2)*(val+val2+1)+val2);
  END; $$
  LANGUAGE plpgsql IMMUTABLE COST 200 PARALLEL SAFE
  SET max_parallel_workers_per_gather = 2;


CREATE UNLOGGED TABLE my_schema.prices (
  price integer CONSTRAINT positive_price CHECK ( price > 0),
  disc_price numeric CHECK (disc_price > 0) DEFAULT NULL,
                     CHECK (disc_price < price),
  prod_descr text NOT NULL,
  prod_incremental integer DEFAULT 0
  );

CREATE INDEX ix_code ON my_schema( my_schema.code(price, prod_incremental));

CREATE TABLE my_schema.descr (
  prod_descr text NOT NULL,
  );

COMMIT;
