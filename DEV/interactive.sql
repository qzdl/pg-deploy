/* interactive.sql

  This file is a scratch-workspace for developing this extension, based on the
  file definitions of everything here. 

  This SO question got my brain going about having the definition read and applied:
    <www-url "https://stackoverflow.com/questions/27808534/how-to-execute-a-string-result-of-a-stored-procedure-in-postgres">

*/

DO $$
DECLARE
    rdir text :=  '/home/qzdl/git/pg-deploy/';
    func text;

BEGIN
    raise notice '
==========================================
DROP / RECREATE FUNCTION AT  %
==========================================
', (select current_timestamp);

    -- NOTE: can this be done programmatically?
    drop function if exists public.reconsile_desired(
         og_schema_name character varying, ds_schema_name character varying, object_name character varying);

    select into func (select file.read(rdir || 'function.sql'));

raise notice '%', func;

execute func;

        RAISE NOTICE '
==========================================
COMPLETED at %
==========================================', (select current_timestamp);

END $$;

-- now we can make stuff and test whatever
-- check what exists
\df public.*;

create schema if not exists testr;
create schema if not exists testp;
drop table if exists testr.a;
drop table if exists testp.a;

create table testr.a(i int, ii text, iii bit);
create table testp.a(ii text, iii bit, iv text);

select public.reconsile_desired('testr', 'testp', 'a')
