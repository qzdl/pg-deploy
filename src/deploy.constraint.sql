/*
    reconcile_constraints:
    - diff of constraints for tables through anti-join
    - mark for ALTER



*/

DROP FUNCTION IF EXISTS deploy.reconcile_constraints(
    source_schema name, source_rel name, source_oid oid,
    target_schema name, target_rel name, target_oid oid);
    
CREATE OR REPLACE FUNCTION deploy.reconcile_constraints(
    source_schema name, source_rel name, source_oid oid,
    target_schema name, target_rel name, target_oid oid)
RETURNS SETOF text AS
$BODY$
DECLARE
    _constraints record;
    ddl text;
BEGIN
-- _constraints, added at the end, also requires a diff
    FOR _constraints IN
        WITH signs AS (
            SELECT
                'DROP' AS sign,
                conname, pg_get_constraintdef(c.oid) as constraintdef, c.oid as conoid
            FROM pg_constraint c
            WHERE conrelid = (
                SELECT attrelid FROM pg_attribute
                WHERE attrelid = source_oid
                  AND attname='tableoid'
            )
            UNION
            SELECT
                'ADD' as sign,
                conname, pg_get_constraintdef(c.oid) as constraintdef, c.oid as conoid
            FROM pg_constraint c
            WHERE conrelid = (
                SELECT attrelid FROM pg_attribute
                WHERE attrelid = target_oid
                  AND attname='tableoid'
            )
        ) -- cte
        SELECT sign, conname, constraintdef, conoid
        FROM signs
    LOOP
        RAISE NOTICE 'LOOP CONSTRAINT: %', _constraints;

        IF _constraints.sign = 'DROP' THEN
            ddl := 'ALTER TABLE '||source_schema||'.'||source_rel
                   ||' DROP CONSTRAINT '||_constraints.conname||'; ';
        END IF;

        IF _constraints.sign = 'ADD' THEN

            ddl := 'ALTER TABLE '||source_schema||'.'||source_rel
                   ||' ADD CONSTRAINT '||_constraints.conname||' '||_constraints.constraintdef;
        END IF;
        RETURN NEXT ddl;
    END LOOP; -- _constraints
END
$BODY$
    LANGUAGE plpgsql STABLE;
