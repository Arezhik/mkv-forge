#!/usr/bin/env bash
# check-project.sh: catch Xcode project drift that Linux can't build-check.
#
# Usage (from anywhere in the repo):  scripts/check-project.sh
#
# Checks (docs/LESSONS.md L17, L19, L31, L33):
#   1. Every App/*.swift file is in project.pbxproj (file reference and Sources phase),
#      and every "X.swift in Sources" entry in project.pbxproj exists on disk.
#   2. App/project.yml and project.pbxproj agree on the bundle ID and the deployment target.
#   3. No two files differ only by letter case (Macs use a case-insensitive disk).
#   4. The shared scheme for the app exists.
#   5. Only the scene roots (struct ContentView, struct SettingsView) read @EnvironmentObject;
#      subviews get the model passed in, since Table cells, context menus and toolbar items
#      may not inherit the environment on macOS (L31).
#   6. The app icon: App/Assets.xcassets has AppIcon.appiconset, the catalog is in the
#      Resources phase, ASSETCATALOG_COMPILER_APPICON_NAME is AppIcon, and project.pbxproj
#      has no unresolved XcodeGen TEMP_ object IDs (L33).
# Works with macOS's bash 3.2 and BSD tools, and with GNU tools. Exit 0 = clean.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
PBX="$(ls -1 App/*.xcodeproj/project.pbxproj 2>/dev/null | head -1 || true)"
YML="App/project.yml"
FAIL=0
bad() { echo "check-project: $*" >&2; FAIL=1; }

[ -n "$PBX" ] && [ -f "$PBX" ] || { echo "check-project: no App/*.xcodeproj/project.pbxproj" >&2; exit 1; }
PROJ_DIR="$(dirname "$PBX")"
APP="$(basename "$PROJ_DIR" .xcodeproj)"

# 1. App sources on disk vs the project.
for f in App/*.swift; do
  [ -f "$f" ] || continue
  name="$(basename "$f")"
  grep -q "path = \"\{0,1\}$name\"\{0,1\}; sourceTree" "$PBX" || bad "$f is on disk but has no PBXFileReference in $PBX"
  grep -q "/\* $name in Sources \*/ = {isa = PBXBuildFile" "$PBX" || bad "$f is on disk but is not in the Sources build phase of $PBX"
done
BUILT="$(sed -n 's/.*\/\* \([^ ]*\.swift\) in Sources \*\/ = {isa = PBXBuildFile.*/\1/p' "$PBX" | sort -u)"
for name in $BUILT; do
  [ -f "App/$name" ] || bad "$PBX builds $name, but App/$name is missing"
done

# 2. project.yml vs project.pbxproj.
if [ -f "$YML" ]; then
  yml_val() { sed -n "s/^[[:space:]]*$1:[[:space:]]*\"\{0,1\}\([^\"]*\)\"\{0,1\}[[:space:]]*$/\1/p" "$YML" | sort -u; }
  pbx_val() { sed -n "s/^[[:space:]]*$1 = \"\{0,1\}\([^\";]*\)\"\{0,1\};.*/\1/p" "$PBX" | sort -u; }
  for key in PRODUCT_BUNDLE_IDENTIFIER MACOSX_DEPLOYMENT_TARGET; do
    y="$(yml_val "$key")"; p="$(pbx_val "$key")"
    [ -n "$p" ] || { bad "$key not found in $PBX"; continue; }
    [ "$(printf '%s\n' "$p" | wc -l | tr -d ' ')" = 1 ] || bad "$PBX has different $key values: $(echo $p)"
    [ -z "$y" ] || [ "$y" = "$p" ] || bad "$YML $key ($(echo $y)) != $PBX ($(echo $p))"
  done
fi

# 3. Paths that differ only by case.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1 && [ -n "$(git ls-files | head -1)" ]; then
  LIST="$(git ls-files)"
else
  LIST="$(find . -path ./.git -prune -o -path ./.build -prune -o -type f -print | sed 's|^\./||')"
fi
DUPES="$(printf '%s\n' "$LIST" | tr 'A-Z' 'a-z' | sort | uniq -d)"
[ -z "$DUPES" ] || bad "paths that differ only by case: $(echo $DUPES)"

# 4. Shared scheme.
[ -f "$PROJ_DIR/xcshareddata/xcschemes/$APP.xcscheme" ] || bad "missing shared scheme $PROJ_DIR/xcshareddata/xcschemes/$APP.xcscheme"

# 5. @EnvironmentObject only in the scene roots. Tracks the enclosing top-level type (a
#    declaration at column 0) and ignores // comments.
ENV_READERS="$(awk '
  FNR == 1 { owner = "" }
  { line = $0; sub(/\/\/.*/, "", line) }
  line ~ /^(public |internal |fileprivate |private |final |@MainActor )*(struct|class|enum|extension|actor)[ \t]/ {
    owner = line
    sub(/^(public |internal |fileprivate |private |final |@MainActor )*(struct|class|enum|extension|actor)[ \t]+/, "", owner)
    sub(/[^A-Za-z0-9_].*/, "", owner)
  }
  line ~ /@EnvironmentObject/ && owner != "ContentView" && owner != "SettingsView" {
    print FILENAME ":" FNR ": " (owner == "" ? "(top level)" : owner)
  }
' App/*.swift)"
[ -z "$ENV_READERS" ] || bad "@EnvironmentObject outside the scene roots ContentView and SettingsView; pass the model explicitly (docs/LESSONS.md L31):
$ENV_READERS"

# 6. App icon wiring and a cleanly generated project.
ICONSET="App/Assets.xcassets/AppIcon.appiconset"
[ -f "$ICONSET/Contents.json" ] || bad "missing $ICONSET/Contents.json (the app icon)"
grep -q '/\* Assets.xcassets in Resources \*/ = {isa = PBXBuildFile' "$PBX" || bad "App/Assets.xcassets is not in the Resources build phase of $PBX"
APPICON="$(sed -n 's/^[[:space:]]*ASSETCATALOG_COMPILER_APPICON_NAME = \([^;]*\);.*/\1/p' "$PBX" | sort -u)"
[ "$APPICON" = AppIcon ] || bad "$PBX should set ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon (found: $(echo $APPICON))"
if grep -q 'TEMP_' "$PBX"; then bad "$PBX has unresolved TEMP_ object IDs (an orphaned XcodeGen group, L33)"; fi

[ "$FAIL" -eq 0 ] || exit 1
echo "Project files are consistent: App sources, project.yml, case-unique paths, the $APP scheme, @EnvironmentObject only in scene roots, and the app icon"
