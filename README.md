
# Table of Contents

1.  [`DEPLOY_TEST`](#org757db1b)
    1.  [Workflow](#org30bf2dc)
        1.  [Extension Install](#org82aaf99)
    2.  [Usage](#orga57ddd9)
    3.  [Limitations](#Limitations)
    4.  [For Developers](#forDevs)
    5.  [Troubleshooting during installation](#org55c182b)
    6.  [Todo](#todo)


    
# <a name="#org757db1b"></a> `DEPLOY_TEST`

Postgres extension for maintaining database schemata using git.


Advantages:

-  Benefits of git
    - Proper version control with rollback
    - Deployment by commit, by tag or as your semantic versioning scheme requires
    - Tests, deployment can be triggered by git hook etc
    - Branches for different scenarios (archive, production system etc., where
      minor changes may be present)
    - git hooks
    - history
    - etc.
-   Single source of truth for all declarations and changes to schemata in a
    repository
-   Using the database for generating the code for depoyment means syntax check
    for the schema
-   Make your own automated testing pipeline for the generated code

How it works - some theory:

The definition of the database object describe the state of the database in
regard its structure. This state is defined by a set of CREATE statements. A
change in this definition results in a new state, that is also a set of create
statements. We can establish the differences between the two states with the
help of the PostgreSQL catalog tables and we can generate SQL code that can
transform one state into an other. With other works: if we create a schema using
the current state - new_schema - and using the previous state - old_schema - in
a running database. Then the main function of the extension calculates the
differences between the two schemas and generates an SQL code. This code can
transform old_schema into the new_schema. The code generation based on the
differences between objects, regardless if that is a new commit or a rollback,
only the direction of transformation must be defined:

For instance, if the new_schema has a new table then the table declaration must
be calculated and applied to the old_schema. The other direction would be a DROP
statement that removes the excess table.

To test the generated code simply apply the generated code to the original
database schema and call the comparison function of the pg-deploy extension. The
result should be a text without any sql commands: after applying the changes to
the source state it should be transformed into the target state, so there should
be no difference.

After proving the generated code further commands can be added to it before
deployment - eg. rebuilding indices, vacuuming etc.


Caveats

- chain renaming is rollback boundary:
    if object A is renamed as B, B is renamed as C and a new A is made in
    subsequent changes, it is impossible to restore the initial state. If that
    is a table, it is not possible to decide if it is a new table or a renamed
    old one. With other words: RENAMEing objects is not encouraged.
- runtime errors are not checked:
    In case of changing the name of a function from or to its qualified form but
    inside a function or dependent function the change is not made the result
    leads to runtime errors. Tests are great tools to prevent such situation.
- dyamically created tables shall not be part of the schema definition:
    dynamically created tables are accidental for the particular database and
    not consistent across databases. Such tables are table partitions or tables
    with time stamps generated dynamically. Be aware if such tables are included
    in your schema definition.


### <a name="#org82aaf99"></a> Extension Install

Installation of the extension follows the standard Postgres Extension install
process.

The server will not require a restart after install.

The procedure relies on `gmake`, with tests through `installcheck` managed by
environment variables, as seen below.

For a full list of environment variables relevant to PG, refer the official
[docs](https://www.postgresql.org/docs/current/libpq-envars.html)

Make the extension available for the instance, generate
[results/deploy<sub>test.out</sub>](results/deploy_test.out) with the following
commands &#x2013; and be sure to prepend `sudo` if the installation is not
governed by the executing user.

    make install
    make installcheck -e PGPORT=YOUR_PG_PORT -e PGUSER=YOUR_PG_USER -e OTHERVAR=READ_THE_DOCS

*usr/lib/postgresql/10/lib/pgxs/src/makefiles*../../src/test/regress/pg<sub>regress</sub> &#x2013;inputdir=./ &#x2013;bindir=&rsquo;/usr/lib/postgresql/10/bin&rsquo;    &#x2013;dbname=contrib<sub>regression</sub> deploy<sub>test</sub>
(using postmaster on Unix socket, default port)
`============` dropping database &ldquo;contrib<sub>regression</sub>&rdquo; `============`
NOTICE:  database &ldquo;contrib<sub>regression</sub>&rdquo; does not exist, skipping
DROP DATABASE
`============` creating database &ldquo;contrib<sub>regression</sub>&rdquo; `============`
CREATE DATABASE
ALTER DATABASE
`============` running regression test queries        `============`
test deploy<sub>test</sub>              &#x2026; ok

`===================`
 All 1 tests passed.
`===================`


## <a name="#orga57ddd9"></a> Usage

### Preparation

-   Install the extension
-   Prepare reference database. This database will be used to calculate the differences between the states (commits)
    but shall not have any user schema defined. (Must be blank.)
-   Set the proper permissions, so that the user who connects to the database in the context of this Extension
    can create schema.
-   Create the extension for the database.

### First commit

-   Create a git repository for your object declarations (tables, procedures, ect.)
    , that you want to keep in the version controll system.
-   pg_dump the schema so that you can restore it.
-   Use this dump as the base of your initial commit, adjust it according to your needs and commit it.

### Further changes and rollbacks
-   Make your changes. Any change in the object definitions are simply modifications of the definition
    as if the object would be newly created. Any object deletion is a deletion in the file.
-   To prepare the reference database so, that your target state goes into one schema and the current goes into an other.
-   Call the extension's main function. If the reconciliation is successful, the return value is an SQL file that can be
    used to create the state transition.
-   Test the code: as the source and target schema must exist on the reference database that is used by the extension,
    modify the code so, that you can apply it to the source schema in the reference database. Call the crExtension's reconcile
    function to calculate the differences again. The result should be text without any SQL executable code in it.
-   Add your custom changes - eg. vacuum, index rebuild, statistics, etc. Deploy the code in your system.

Note: For an example check the DEV/reconcile.sh script.



## <a name="#limitations"></a> Limitations
- Base types are not supported 

## <a name="#forDevs"></a> For Developers

### Testing - standard PostgreSQL test

The extension has standard PostgreSQL unit tests.

### Integration tests

The integration tests simulate a real environment and the workflow.

-   The preparatory steps are as described in the Usage section for end users.
-   The two states used for development are the integration_tests/source.sql and integration_tests/target.sql files.
    These files serve for testing and to be modified only when new test case or edge case is implemented.
-   The developer executes the helper script integration_tests/transform.sh in order to get his test results. For details see the transform.sh file.


NOTE: If structural changes against the **current** version exist in the database,
      it should be possible to write the version held by the extension to a new
      schema that is not owned by the extension. From here, the process above
      can be followed to get a new baseline.


### <a name="#org55c182b"></a> Troubleshooting during installation


### `installcheck`: `psql: FATAL:  role "root" does not exist`

By default, the user/role mapping will be used when attempting to establish a
connection to the target database.

If `installcheck` has been run as `sudo make installcheck`, then the associated
`PGUSER` that will be attempted with login will be `root`, which is not
typically set up on the database server.

To fix, supply the `PGUSER` environment variable to `make` with the `-e` option:

    sudo make installcheck -e PGUSER='<user>'


### `installcheck`: `psql: FATAL:  Peer authentication failed for user "<USER>"`

This error will likely arise when running `make installcheck` with supplying
environment variable `PGUSER`.
The fix for this depends on the authentication configuration of the target instance;

-   ascertain how authentication is configured by finding `pg_hba.conf` &#x2013; this
    can generally be found at `/etc/postgresql/<VERSION>/main/pg_hba.conf`;
    replace `<VERSION>` with the applicable version
-   so, either:
    -   change local login (first entry) from `peer` to `md5` or any other relevant
        auth method;
        -   `md5` allows for password auth from the user&rsquo;s UNIX login
        -   `trust` will just allow any arbitrary local connections

    -   check your environment variables to `make installlcheck`, and adjust the
        parameters given to suit your auth config; e.g. `PGPASSWORD` as the
        substitute for the connection parameter for `password`
-   if necessary, reload the server to apply the auth changes with the following
    command

        /etc/init.d/postgresql reload
-   in any case, [RTFM](https://www.postgresql.org/docs/current/libpq-envars.html)

Some useful links for troubleshooting this process:

-   [PostgreSQL: Documentation: 12: 20.3. Authentication Methods](https://www.postgresql.org/docs/12/auth-methods.html)
-   [postgresql - Getting error: Peer authentication failed for user &ldquo;postgres&rdquo;, w&#x2026;](https://stackoverflow.com/questions/18664074/getting-error-peer-authentication-failed-for-user-postgres-when-trying-to-ge)

# <a name="#todo"></a>TODO

- when creating the source and target schema consider the case of fully qualified naming (schema.obj_name)
- create the DEV/XXX_a.sql and DEV/XXX_b.sql and the DEV/YYY.sh for integration test
- create the DEV/reconcile.sh as an example. (That may work on the current repository on the DEV/XXX_a.sql states? )
