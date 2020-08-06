DROP FUNCTION IF EXISTS deploy.cte_event_trigger(_ name, __ name);

CREATE FUNCTION deploy.cte_event_trigger(_ name, __ name)
RETURNS TABLE(
    nspname name, objname name, oid oid, id text) AS
$BODY$
BEGIN
    RETURN QUERY
    SELECT
      (CASE WHEN STRPOS(evtname, '--deploy--') > 0
        THEN 'target'
        ELSE 'source' END)::name AS nspname,
      split_part(evtname, '--deploy--', 1)::name AS objname,
      e.oid AS oid,
      split_part(evtname, '--deploy--', 1)||evtevent||evtenabled
      ||array_to_string(ARRAY(SELECT quote_literal(x) FROM UNNEST(evttags) AS t(x)),'') AS id
    FROM pg_catalog.pg_event_trigger AS e
    ORDER BY nspname;
END;
$BODY$
    LANGUAGE plpgsql STABLE;

SELECT * FROM deploy.cte_event_trigger('','');


SELECT * FROM deploy.object_difference('','','cte_event_trigger'::name)
