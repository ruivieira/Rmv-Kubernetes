#!/usr/bin/env bash
# Basic Raku linting checks for pre-commit.
# Checks for common style issues in Raku source files.
set -euo pipefail

status=0

for file in "$@"; do
    # Trailing whitespace
    if grep -Pn '\s+$' "$file"; then
        echo "  ^^^ trailing whitespace in $file"
        status=1
    fi

    # Tabs (prefer spaces)
    if grep -Pn '\t' "$file"; then
        echo "  ^^^ tabs found in $file (use spaces)"
        status=1
    fi

    # Missing final newline
    if [ -s "$file" ] && [ "$(tail -c 1 "$file" | wc -l)" -eq 0 ]; then
        echo "$file: missing final newline"
        status=1
    fi

    # use v6 without .d/.c qualifier (should be v6.d or v6.c)
    if grep -Pn '^use v6\s*;' "$file"; then
        echo "  ^^^ use 'v6.d' or 'v6.c' instead of bare 'v6' in $file"
        status=1
    fi
done

exit $status
