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

Dropping & recreating at %

', (select current_timestamp);
    
    drop function if exists public.reconsile_desired(
         og_schema_name character varying, ds_schema_name character varying, object_name character varying);

    select into func (select file.read(rdir || 'function.sql'));

raise notice '%', func;

execute func;

END $$;

-- check what exists
\df public.*
