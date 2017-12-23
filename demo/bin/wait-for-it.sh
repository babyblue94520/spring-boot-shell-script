#!/bin/sh
set -e

curl_cmd="$1"
shift
cmd="$@"

until curl "$curl_cmd"
do
  >&2 echo "Postgres is unavailable - sleeping"
  sleep 1
done

>&2 echo "Postgres is up - executing command"
exec $cmd