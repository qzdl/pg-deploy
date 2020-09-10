#!/usr/bin/env bash
# sh script to run the integration test.
# This script also demonstrates a way of usage that can be adopted
# to various scenarios. In the current example
# the source and target files are files in the current folder.
# In case of a git you can use something like
# git show HEAD^^:path/to/the/file
# to retrieve a given file as source or target.
# For more options in git to identify revisions by tag, date etc.
# consult man gitrevisions.

while [[ $# -gt 0 ]] do
key="$1"

case $key in
    -s|--source)
    SOURCE="$2"
    shift # past argument
    shift # past value
    ;;
    -t|--target)
    TARGET="$2"
    shift # past argument
    shift # past value
    ;;
    -h|--help)
    cat <<USAGE
    sh transform.sh -s|--source <SOURCE_SCHEMA_FILE> -s|--target <TARGET_SCHEMA_FILE>

    Calculate the transformation between the source and target schemas.
    Requires a running Pg on localhost:5432 (default port) with the credentials as
    the current user | user database. The user needs all the privileges to create and modify a database.
    It outputs the transformation SQL and a check file. The check file shall contain only
    SQL comments if applying the transformation file to the source schema the result is
    the target schema (there is no difference between the two).

USAGE
    exit

    *)    # unknown option
    echo "Unknown option: $key."
    echo "sh transform.sh -s|--source <SOURCE_SCHEMA_FILE> -s|--target <TARGET_SCHEMA_FILE>"
    echo "sh transform.sh -h|--help"
    exit
    ;;
esac
done

echo "SOURCE SCHEMA FILE  = ${source_schema}"
echo "TARGET SCHEMA FILE  = ${target_schema}"

DIFF_FILE='./'
if test -f "$DIFF_FILE"; then
  echo "Diff file $DIFF_FILE exists. Removing it."
  rm $DIFF_FILE || exit
fi
