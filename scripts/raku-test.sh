#!/usr/bin/env bash
# Run Raku unit tests. Used by pre-commit and for local runs.
set -euo pipefail

if [ "$#" -gt 0 ]; then
    for test in "$@"; do
        [[ -e "$test" ]] || continue
        raku -Ilib "$test"
    done
    exit 0
fi

for test in t/*.rakutest; do
    [[ -e "$test" ]] || continue
    raku -Ilib "$test"
done
