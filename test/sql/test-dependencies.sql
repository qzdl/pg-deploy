--  test-dependencies.sql

--- prep
drop table if exists testp.tdep;
drop function if exists testp.fdep;
drop index if exists testp.idep;

create table testp.tdep(a int);
create function testp.fdep(n int) returns int as $$ begin return n + 1; end; $$ language plpgsql immutable;
create index idep ON testp.tdep (testp.fdep(a));
alter table testp.tdep add CONSTRAINT cdep CHECK (a > testp.fdep(a) -1);



--- test
-- drop function testp.fdep;

-- i think the view can be interrogated here; walk the tree down and collect object definitions
select * from report.dependency_tree(ARRAY((select oid from pg_proc where proname = 'fdep')));

--- ROW TRIGGER DEPENDENCY

--- EVENT TRIGGER DEPENDENCY
CREATE OR REPLACE FUNCTION testp.etdep() RETURNS event_trigger AS $$
BEGIN
    RAISE NOTICE 'IM TRIGGERED: % %', tg_event, tg_tag;
END;
$$ LANGUAGE plpgsql;

CREATE EVENT TRIGGER etdep ON ddl_command_start EXECUTE procedure testp.etdep();

drop function testp.etdep;
