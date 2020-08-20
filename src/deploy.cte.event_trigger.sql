DROP FUNCTION IF EXISTS pg_deploy.cte_event_trigger(_ name, __ name);

CREATE FUNCTION pg_deploy.cte_event_trigger(_ name, __ name)
RETURNS TABLE(
    nspname name, objname name, oid oid, id text) AS
$BODY$
BEGIN
    RETURN QUERY
    SELECT
      (CASE WHEN STRPOS(evtname, '__deploy__') > 0
        THEN 'target'
        ELSE 'source' END)::name AS nspname,
          split_part(evtname, '__deploy__', 1)::name AS objname,
          e.oid AS oid,
          split_part(evtname, '__deploy__', 1)||evtevent||evtenabled
            ||array_to_string(
              ARRAY( SELECT quote_literal(x) FROM UNNEST(evttags) AS t(x)),'') AS id
      FROM pg_catalog.pg_event_trigger AS e
      ORDER BY nspname;
END;
$BODY$
    LANGUAGE plpgsql STABLE;

SELECT * FROM pg_deploy.cte_event_trigger(''::name,''::name);

SELECT * FROM pg_deploy.object_difference(
  'source'::name,'target'::name,'pg_deploy.cte_event_trigger'::name)
