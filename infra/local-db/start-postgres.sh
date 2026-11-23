#!/bin/sh
set -eu
# The pinned image interpolates this password into its first SQL bootstrap.
# Reject unsupported input before its entrypoint can initialize a volume.
LC_ALL=C
export LC_ALL
case ${POSTGRES_PASSWORD:-} in
    ''|*[!0-9a-f]*) echo 'Expected a Jarvis-generated database password.' >&2; exit 64 ;;
esac
if [ "${#POSTGRES_PASSWORD}" -ne 64 ]; then
    echo 'Expected a Jarvis-generated database password.' >&2
    exit 64
fi
exec docker-entrypoint.sh "$@"
