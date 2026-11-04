#!/bin/sh
set -eu
PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
CHECK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/next-models.XXXXXX")"
trap 'rm -rf "$CHECK_DIR"' EXIT HUP INT TERM
xcrun swiftc -module-cache-path "$CHECK_DIR/ModuleCache"   "$PROJECT_ROOT/Sofra/Models.swift" "$PROJECT_ROOT/Sofra/RecipeCatalog.swift" "$PROJECT_ROOT/Sofra/PlanningModels.swift" "$PROJECT_ROOT/Tests/main.swift"   -o "$CHECK_DIR/model-check"
"$CHECK_DIR/model-check"
