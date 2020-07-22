BEGIN;

CREATE SCHEMA my_schema;

CREATE FUNCTION my_schema.new_dummy(val integer)
RETURNS integer AS $$
  BEGIN
  RETURN val+2;
  END; $$ LANGUAGE plpgsql IMMUTABLE;


CREATE FUNCTION my_schema.cantor_pairing(x numeric not null, y numeric not null)
RETURNS numeric AS $$
  BEGIN
  -- Cantor pairing
  RETURN (0.5*(x+y)*(x+y+1)+x);
  END; $$
  LANGUAGE plpgsql
  PARALLEL SAFE;

CREATE TABLE my_schema.prices (
  price numeric CONSTRAINT positive_price CHECK ( price > 0),
  price_modifier integer DEFAULT NULL,
  prod_descr text NOT NULL,
  prod_incremental numeric DEFAULT 2,
  some_future_feature varchar(40)
  );

  ALTER TABLE my_schema IS 'new commend describing the table.';

  CREATE TABLE my_schema.descr (
    prod_descr text NOT NULL,
    id integer PRIMARY KEY,
    some_future_feature varchar(20),
    UNIQUE(prod_descr)
    );

CREATE INDEX ix_my_schema_prices ON my_schema.cantor_pairing(price, prod_incremental);
ALTER TABLE my_schema.descr ADD CONSTRAINT fk_prod_descr FOREIGN KEY (prod_descr)
            REFERENCES my_schema.prices(prod_descr);


COMMIT;
