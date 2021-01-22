-- this is my function file


create function staying_alive.chopi(a int)
returns int language plpgsql as $$ begin return 5; end; $$;
