#!/usr/bin/env sh
# Persona consistency gate.
#
# Agent files cannot include shared content, so the
# engineer personas carry verbatim copies of their
# shared sections, and the task-tag taxonomy is spelled
# out in three prose locations. Nothing but this script
# stops those copies drifting apart. It fails when:
#   1. Process / Rules / Report back differ across the
#      engineer personas,
#   2. the Domain rules preamble differs between the
#      frontend personas, or
#   3. an engineer's task tag ([backend], [aspnet], ...)
#      is missing from the architect, the orchestrator,
#      or the plugin README.
# Line endings are normalised before comparing, so only
# content drift fails.
set -eu
cd "$(dirname "$0")/.."

agents=dotnet-personas/agents
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
status=0

# Body of section $2 in file $1, \r stripped. Exits
# nonzero when the heading is absent, so a renamed
# heading cannot pass as two identical empty sections.
extract() {
  awk -v h="$2" '
    {sub(/\r$/, "")}
    $0 == h {found = 1; on = 1; next}
    /^## /  {on = 0}
    on      {print}
    END     {exit !found}
  ' "$1"
}

check_section() {
  h=$1; ref=$2; shift 2
  if ! extract "$agents/$ref" "$h" >"$tmp/ref"; then
    echo "FAIL: section '$h' missing from $ref"
    status=1
    return
  fi
  for f in "$@"; do
    if ! extract "$agents/$f" "$h" >"$tmp/cur"; then
      echo "FAIL: section '$h' missing from $f"
      status=1
      continue
    fi
    if ! diff -u "$tmp/ref" "$tmp/cur" >"$tmp/diff"; then
      echo "FAIL: '$h' drifted between $ref and $f"
      cat "$tmp/diff"
      status=1
    fi
  done
}

engineers="backend-engineer.md aspnet-engineer.md blazor-engineer.md"
for h in "## Process, in order" "## Rules" "## Report back"; do
  # shellcheck disable=SC2086
  check_section "$h" $engineers
done

# The frontend personas share their Domain rules
# preamble (heading up to the "Invariants:" marker)
# word for word.
preamble() {
  awk '
    {sub(/\r$/, "")}
    /^## Domain rules$/ {on = 1; next}
    /^Invariants:$/     {on = 0}
    on                  {print}
  ' "$1"
}
preamble "$agents/aspnet-engineer.md" >"$tmp/a"
preamble "$agents/blazor-engineer.md" >"$tmp/b"
if ! [ -s "$tmp/a" ]; then
  echo "FAIL: Domain rules preamble missing from aspnet-engineer.md"
  status=1
elif ! diff -u "$tmp/a" "$tmp/b" >"$tmp/diff"; then
  echo "FAIL: Domain rules preamble drifted between aspnet and blazor"
  cat "$tmp/diff"
  status=1
fi

# Every engineer persona's tag must be wired into the
# places that route it. Tags derive from filenames, so
# adding <name>-engineer.md demands the wiring for
# [<name>] automatically.
for f in "$agents"/*-engineer.md; do
  tag=$(basename "$f" -engineer.md)
  for doc in "$agents/software-architect.md" \
             dotnet-personas/commands/feature.md \
             dotnet-personas/README.md; do
    if ! grep -q "\[$tag\]" "$doc"; then
      echo "FAIL: tag [$tag] not mentioned in $doc"
      status=1
    fi
  done
done

if [ "$status" -eq 0 ]; then
  echo "OK: engineer personas consistent"
fi
exit "$status"
