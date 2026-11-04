#!/bin/sh
set -eu
PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
CHECK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sofra-store-tests.XXXXXX")"
trap 'rm -rf "$CHECK_DIR"' EXIT HUP INT TERM
xcrun swiftc -swift-version 5 -parse-as-library -module-cache-path "$CHECK_DIR/ModuleCache" \
  "$PROJECT_ROOT/Sofra/Models.swift" "$PROJECT_ROOT/Sofra/RecipeCatalog.swift" \
  "$PROJECT_ROOT/Sofra/PlanningModels.swift" "$PROJECT_ROOT/Sofra/DayPlanning.swift" \
  "$PROJECT_ROOT/Sofra/FoodStore.swift" "$PROJECT_ROOT/Tests/StoreChecks.swift" \
  -o "$CHECK_DIR/store-check"
"$CHECK_DIR/store-check" "$CHECK_DIR"
