
# Table of Contents

1.  [DEPLOY<sub>TEST</sub>](#org3e7e2d6)
    1.  [Workflow](#org61c50d7)
        1.  [Extension Install](#orgf240740)
    2.  [Usage](#org912a685)
    3.  [Deploy/Rollback](#orgb8a3187)
    4.  [Project Structure](#orge487b59)
        1.  [sql/](#org94f069b)
        2.  [expected/](#org9bb8dae)
    5.  [Bootstrapping from a live schema](#orgf96b7af)
    6.  [Troubleshooting](#org3b9066c)
        1.  [`installcheck`: `psql: FATAL:  role "root" does not exist`](#orge0a5b35)
        2.  [`installcheck`: `psql: FATAL:  Peer authentication failed for user "<USER>"`](#org13df87b)


<a id="org3e7e2d6"></a>

# DEPLOY<sub>TEST</sub>

A proof-of-concept Postgres extension for maintaining database schemas as an extension.

The general process of taking the objects in a database to a new version is as

Advantages:

-   Proper version control
    -   Deployment by commit, or by tag; e.g. hotfix
-   Code generation based on the differences between objects is possible
    -   This applies for rollback, between versions, or arbitary &rsquo;dirty&rsquo; states
        (e.g at development time)
-   Single source of truth for all declarations and changes to schemata.
-   Automatic test generation for functional, structural, etc tests; using standard
    Postgres test framework.
-   Can be deployed and used on local instances.
-   Tests can be triggered by git hook.


<a id="org61c50d7"></a>

## Workflow


<a id="orgf240740"></a>

### Extension Install

Installation of the extension follows the standard Postgres Extension install process.

The server will not require a restart after install.

The procedure relies on \`gmake\`, with tests through \`installcheck\`managed by
environment variables, as seen below.

For a full list of environment variables relevant to PG, refer the official
[docs](<https://www.postgresql.org/docs/current/libpq-envars.html>)

Make the extension available for the instance, generate \`results/deploy<sub>test.out</sub>\`.
Be sure to prepend \`sudo\` if the installation is not governed by the executing user.
\`\`\` shell
$ make install
$ make installcheck -e PGPORT=YOUR<sub>PG</sub><sub>PORT</sub> -e PGUSER=YOUR<sub>PG</sub><sub>USER</sub> -e OTHERVAR=READ<sub>THE</sub><sub>DOCS</sub>
\`\`\`


<a id="org912a685"></a>

## Usage

Prepare reference database (all changesets & scripts applied, etc).

Dump the current state of the database; this is the base for the initial commit.

-   `--clean` option will generate a `DROP` statement for each object

    pg_dump --host localhost --port 8432 --dbname "something" --user postgres \
      --schema-only --no-owner --no-privileges  --clean --if-exists \
      | sed -e 's/CREATE TABLE/CREATE TABLE IF NOT EXISTS/g' \
      | grep -v DROP.TABLE > initial-commit-source.sql

Adjust [initial-commit-source.sql](initial-commit-source.sql) according to your needs.

Create the test suite in [sql/](sql/) as demonstrated.

Run the tests, with copy step to expected

    make install
    make installcheck -e PGPORT=YOUR_PG_PORT -e PGUSER=YOUR_PG_USER -e OTHERVAR=READ_THE_DOCS
    cp results/deploy_test.out expected/deploy_test.out
    make installcheck -e PGPORT=YOUR_PG_PORT -e PGUSER=YOUR_PG_USER -e OTHERVAR=READ_THE_DOCS

Commit / Tag if tests pass.

NOTE: If structural changes against the **current** version exist in the databasem
      it should be possible to write the version held by the extension to a new
      schema that is not owned by the extension. From here, the process above
      can be followed to get a new baseline.


<a id="orgb8a3187"></a>

## TODO Deploy/Rollback


<a id="orge487b59"></a>

## TODO Project Structure


<a id="org94f069b"></a>

### [sql/](sql/)

This directory holds the sql scripts that generate the output for


<a id="org9bb8dae"></a>

### TODO [expected/](expected/)


<a id="orgf96b7af"></a>

## TODO Bootstrapping from a live schema

bump-version.sh
install.sh

    pg_dump --host localhost --port 8432 --dbname "something" --user postgres \
    --schema-only --no-owner --no-privileges --table 'test_deploy.*'


<a id="org3b9066c"></a>

## Troubleshooting


<a id="orge0a5b35"></a>

### `installcheck`: `psql: FATAL:  role "root" does not exist`

By default, the user/role mapping will be used when attempting to establish a
connection to the target database.

If \`installcheck\` has been run as \`sudo make installcheck\`, then the associated
\`PGUSER\` that will be attempted with login will be \`root\`, which is not
typically set up on the database server.

To fix, supply the \`PGUSER\` environment variable to \`make\` with the \`-e\` option:

    
    sudo make installcheck -e PGUSER='<user>'

If you get an error regarding peer authentication, refer [1.6.2](#org13df87b)


<a id="org13df87b"></a>

### `installcheck`: `psql: FATAL:  Peer authentication failed for user "<USER>"`

This error will likely arise when running `make installcheck` with supplying
environment variable `PGUSER`.

