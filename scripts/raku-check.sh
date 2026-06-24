#!/usr/bin/env bash
# Syntax-check Raku source files with lib/ on the include path.
set -euo pipefail

for file in "$@"; do
    raku -Ilib -c "$file"
done
