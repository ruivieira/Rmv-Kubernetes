#!/usr/bin/env bash
# Stamps {{$NEXT}} in Changes with the version from META6.json and today's date.
set -euo pipefail

CHANGES=Changes

grep -q '{{\$NEXT}}' "$CHANGES" || exit 0

VERSION=$(raku -e 'use JSON::Tiny; print from-json("META6.json".IO.slurp)<version>')
DATE=$(date +%Y-%m-%d)

ENTRIES=""
if git rev-parse HEAD &>/dev/null; then
    LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    if [ -n "$LAST_TAG" ]; then
        RANGE="${LAST_TAG}..HEAD"
    else
        RANGE="HEAD"
    fi
    ENTRIES=$(git log "$RANGE" --pretty=format:'    - %s' --no-merges)
fi

if [ -n "$ENTRIES" ]; then
    REPLACEMENT="$VERSION  $DATE\n$ENTRIES"
else
    REPLACEMENT="$VERSION  $DATE"
fi

sed -i "s/{{\\\$NEXT}}/$REPLACEMENT/" "$CHANGES"
git add "$CHANGES"
