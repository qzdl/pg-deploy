# DEPLOY_TEST
A proof-of-concept Postgres extension for maintaining database schemas as an extension.

The general process of taking the objects in a database to a new version is as

Advantages:
- Proper version control
    - Deployment by commit, or by tag; e.g. hotfix
- Code generation based on the differences between objects is possible
    - This applies for rollback, between versions, or arbitary 'dirty' states (e.g at development time)
- Single source of truth for all declarations and changes to schemata.
- Automatic test generation for functional, structural, etc tests; using standard
  Postgres test framework.
- Can be deployed and used on local instances.
- Tests can be triggered by git hook.
-

## Workflow
### Extension Install
Installation of the extension follows the standard Postgres Extension install process.

The server will not require a restart after install.

The procedure relies on `gmake`, with tests through `installcheck`managed by
environment variables, as seen below.

For a full list, refer the official [docs](https://www.postgresql.org/docs/current/libpq-envars.html)

Make the extension available for the instance, generate `results/deploy_test.out`.
Be sure to prepend `sudo` if the installation is not governed by the executing user.
``` shell
$ make install
$ make installcheck -e PGPORT=YOUR_PG_PORT -e PGUSER=YOUR_PG_USER -e OTHERVAR=READ_THE_DOCS
```

## Usage
Prepare reference database (all changesets & scripts applied, etc).


Dump the current state of the database; this is the base for the initial commit.
- `--clean` option will generate a `DROP` statement for each object
``` shell
pg_dump --host localhost --port 8432 --dbname "something" --user postgres \
  --schema-only --no-owner --no-privileges  --clean --if-exists \
  | sed -e 's/CREATE TABLE/CREATE TABLE IF NOT EXISTS/g' \
  | grep -v DROP.TABLE > initial-commit-source.sql

```

Adjust `initial-commit-source.sql` according to your needs.

Create the test suite in `sql/` as demonstrated.

Run the tests, with copy step to expected
``` shell
$ make install
$ make installcheck -e PGPORT=YOUR_PG_PORT -e PGUSER=YOUR_PG_USER -e OTHERVAR=READ_THE_DOCS
$ cp results/deploy_test.out expected/deploy_test.out
$ make installcheck -e PGPORT=YOUR_PG_PORT -e PGUSER=YOUR_PG_USER -e OTHERVAR=READ_THE_DOCS
```

Commit if tests pass.

NOTE: If structural changes against the *current* version exist in the databasem it should
      be possible to write the version held by the extension to a new schema that is
    not owned by the extension. From here, the process
      above can be followed to get a new baseline.

## Deploy/Rollback
TODO

## Structure
### sql/
This directory holds the sql scripts that generate the output for

### expected/
TODO


## TODO
bump-version.sh
install.sh

```
pg_dump --host localhost --port 8432 --dbname "something" --user postgres \
--schema-only --no-owner --no-privileges --table 'test_deploy.*'
```
