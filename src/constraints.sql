CREATE FUNCTION deploy.reconcile_constraints(
    source_schema text,
    target_schema text,
    source_rel text,
    target_rel
)
RETURNS SETOF text AS
$BODY$
DECLARE
    _constraints record;
BEGIN
-- _constraints, added at the end, also requires a diff
        FOR _constraints IN
            SELECT conname, pg_get_constraintdef(c.oid) as constrainddef
            FROM pg_constraint c
            WHERE conrelid=(
                  SELECT attrelid FROM pg_attribute
                  WHERE attrelid = (
                      SELECT oid FROM pg_class
                      WHERE relname = target_rel
                        AND relnamespace = (SELECT ns.oid FROM pg_namespace ns WHERE ns.nspname = target_schema)
                  ) AND attname='tableoid'
            )
        LOOP
            RAISE NOTICE 'CONSTRAINT FOR %', _constraints.conname;
             SELECT INTO col_ddl
                'CONSTRAINT '||_constraints.conname||' '||_constraints.constrainddef;
              RETURN NEXT col_ddl; -- constraint return; returns less
        END LOOP; -- _constraints
       RAISE NOTICE 'return next %', col_ddl;
END
$BODY$
    LANGUAGE plpgsql STABLE;
