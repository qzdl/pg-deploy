-- EVENT TRIGGERS
-- logic ripped and translated to SQL from pg_dump.c

DROP EVENT TRIGGER IF EXISTS etdep;
DROP FUNCTION IF EXISTS testp.etdep;

CREATE OR REPLACE FUNCTION testp.etdep() RETURNS event_trigger AS $$
BEGIN
    RAISE NOTICE 'IM (EVENT) TRIGGERED: % %', tg_event, tg_tag;
END;
$$ LANGUAGE plpgsql;

CREATE EVENT TRIGGER etdep ON ddl_command_start EXECUTE procedure testp.etdep();



-- generated pattern testing
-- regular names are implicitly 'source', that which contains `__deploy__` is target

-- NO LEFT, RIGHT
-- returns: CREATE EVENT TRIGGER nlr ddl_...
CREATE EVENT TRIGGER nlr__deploy__ ddl_command_start EXECUTE procedure testp.etdep();

-- NO RIGHT, LEFT
-- returns: DROP EVENT TRIGGER nrl ddl_...
CREATE EVENT TRIGGER nrl__deploy__ ddl_command_start EXECUTE procedure testp.etdep();
