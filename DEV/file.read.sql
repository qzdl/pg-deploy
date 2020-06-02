/*
  FUNCTION: `file.read`

    This function will read the entire contents of a file into `text`, and
    return it. This is useful at development time when working from files that
    contain definitions of objects that you would like to change.

    There is a `schema` created called `file`, into which the function is
    created. The function will create a temporary table to spool the contents
    into, then directly select the contents of that table, and remove it.

    Large files may cause memory issues, as the 'loadiing' will have to pass
    through the heap, relying on the system function for importing large objects
    - `lo_import`.

  USAGE: `select file.read('absolute/path/to/file')`

  DEPLOY: {C-c C-b}

  CHECK: <eval-elisp (sql-send-string "\\df file.*")>
         <eval-elisp (sql-send-string "select file.read('/home/qzdl/git/pg-deploy/DEV/file.read.sql')")>

  ATTRIBUTION: https://stackoverflow.com/questions/45241088/how-load-whole-content-file-in-function/45295368#45295368

*/

CREATE SCHEMA IF NOT EXISTS file;

CREATE OR REPLACE FUNCTION file.read(path CHARACTER VARYING)
  RETURNS TEXT AS $$
DECLARE
  var_file_oid OID;
  var_record   RECORD;
  var_result   BYTEA := '';
BEGIN
  SELECT lo_import(path)
  INTO var_file_oid;
  FOR var_record IN (SELECT data
                     FROM pg_largeobject
                     WHERE loid = var_file_oid
                     ORDER BY pageno) LOOP
    var_result = var_result || var_record.data;
  END LOOP;
  PERFORM lo_unlink(var_file_oid);
  RETURN convert_from(var_result, 'utf8');
END;
$$ LANGUAGE plpgsql;
