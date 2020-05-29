
# Table of Contents

1.  [`DEPLOY_TEST`](#org9525226)
    1.  [Workflow](#orgf11d55e)
        1.  [Extension Install](#org23f073a)
    2.  [Usage](#org7d47076)
    3.  [Deploy/Rollback](#org0239ece)
    4.  [Project Structure](#orgf14fc22)
        1.  [sql/](#org49f8b7c)
        2.  [expected/](#org5a4b452)
    5.  [Troubleshooting](#org54bbdcf)
        1.  [`installcheck`: `psql: FATAL:  role "root" does not exist`](#org129514e)
        2.  [`installcheck`: `psql: FATAL:  Peer authentication failed for user "<USER>"`](#org4d30e32)


<a id="org9525226"></a>

# `DEPLOY_TEST`

A proof-of-concept Postgres extension for maintaining database schemata, as an
extension.

The general process of taking the objects in a database to a new version

Advantages:

-   Proper version control
    -   Deployment by commit, or by tag; e.g. hotfix
    -   Flexible to the semantic versioning scheme relevant to the project.
-   Code generation based on the differences between objects
    -   This applies for rollback, between versions, or arbitary &rsquo;dirty&rsquo; states
        (e.g at development time)
    -   catalog tables contian the necessary information to &rsquo;diff&rsquo;
-   Single source of truth for all declarations and changes to schemata.
-   Automatic test generation for functional, structural, etc tests; using standard
    Postgres test framework.
-   Can be deployed and used on local instances.
-   Tests can be triggered by git hook.


<a id="orgf11d55e"></a>

## Workflow


<a id="org23f073a"></a>

### Extension Install

Installation of the extension follows the standard Postgres Extension install process.

The server will not require a restart after install.

The procedure relies on `gmake`, with tests through `installcheck` managed by
environment variables, as seen below.

For a full list of environment variables relevant to PG, refer the official [docs](https://www.postgresql.org/docs/current/libpq-envars.html)

Make the extension available for the instance, generate [results/deploy<sub>test.out</sub>](results/deploy_test.out)
with the following commands &#x2013; and be sure to prepend `sudo` if the installation is
not governed by the executing user.

    make install
    make installcheck -e PGPORT=YOUR_PG_PORT -e PGUSER=YOUR_PG_USER -e OTHERVAR=READ_THE_DOCS


<a id="org7d47076"></a>

## Usage

Prepare reference database (all changesets & scripts applied, etc).

Dump the current state of the database; this is the base for the initial commit.

-   The `--clean` option to `pg_dump` will generate a `DROP` statement for each
    object:

    pg_dump --host localhost --port 8432 --dbname "something" --user postgres \
      --schema-only --no-owner --no-privileges  --clean --if-exists \
      | sed -e 's/CREATE TABLE/CREATE TABLE IF NOT EXISTS/g' \
      | grep -v DROP.TABLE > initial-commit-source.sql

-   Adjust the newly created [initial-commit-source.sql](initial-commit-source.sql) according to your needs.

-   Create the test suite in [sql/](sql/) as demonstrated.

-   Run the tests, with copy step to expected
    
        make install
        make installcheck -e PGPORT=YOUR_PG_PORT -e PGUSER=YOUR_PG_USER -e OTHERVAR=READ_THE_DOCS
        cp results/deploy_test.out expected/deploy_test.out
        make installcheck -e PGPORT=YOUR_PG_PORT -e PGUSER=YOUR_PG_USER -e OTHERVAR=READ_THE_DOCS

-   Save the state (e.g. git commit / tag) if tests pass.

NOTE: If structural changes against the **current** version exist in the database,
      it should be possible to write the version held by the extension to a new
      schema that is not owned by the extension. From here, the process above
      can be followed to get a new baseline.


<a id="org0239ece"></a>

## TODO Deploy/Rollback

The procedure


<a id="orgf14fc22"></a>

## TODO Project Structure


<a id="org49f8b7c"></a>

### [sql/](sql/)

This directory holds the sql scripts that generate the output for


<a id="org5a4b452"></a>

### TODO [expected/](expected/)


<a id="org54bbdcf"></a>

## Troubleshooting


<a id="org129514e"></a>

### `installcheck`: `psql: FATAL:  role "root" does not exist`

By default, the user/role mapping will be used when attempting to establish a
connection to the target database.

If `installcheck` has been run as `sudo make installcheck`, then the associated
`PGUSER` that will be attempted with login will be `root`, which is not
typically set up on the database server.

To fix, supply the `PGUSER` environment variable to `make` with the `-e` option:

    sudo make installcheck -e PGUSER='<user>'

If you get an error regarding peer authentication, refer [1.5.2](#org4d30e32)


<a id="org4d30e32"></a>

### `installcheck`: `psql: FATAL:  Peer authentication failed for user "<USER>"`

This error will likely arise when running `make installcheck` with supplying
environment variable `PGUSER`.

