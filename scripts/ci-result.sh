#!/bin/bash
set -eu
printf 'Scope=%s (%s), Swift=%s, native UI=%s\n' "$2" "$1" "$3" "$4"
case "$1/$2/$3/$4" in
    success/full/success/success|success/docs/skipped/skipped) exit 0 ;;
    *) exit 1 ;;
esac
