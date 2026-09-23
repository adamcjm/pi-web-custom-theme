#!/usr/bin/env bash
# --- pi-web custom theme: switch ------------------------------------------------
#   use.sh <skin>   activate a skin (and keep it across pi-web restarts)
#   use.sh off      deactivate everything, back to the stock look
#   use.sh status   show what is currently installed
set -euo pipefail

THEME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$THEME_DIR/lib.sh"

PKG_DIR="$(ct_pkg_dir 2>/dev/null || true)"
ACTIVE="$THEME_DIR/active"

list_skins() {
  local found=0
  for dir in "$THEME_DIR"/*/; do
    [ -f "${dir}skin.css" ] || continue
    printf '  %s\n' "$(basename "$dir")"
    found=1
  done
  [ "$found" = 1 ] || echo "  (none installed)"
}

show_status() {
  echo "theme dir : $THEME_DIR"
  echo "pi-web pkg: ${PKG_DIR:-✗ not found (install: npm install -g @agegr/pi-web)}"
  if [ -f "$ACTIVE" ]; then
    echo "switch    : ON  (active skin: $(cat "$ACTIVE"))"
  else
    echo "switch    : off (pi-web starts with its stock look)"
  fi

  CSS_FILE="$(ct_css_file "${PKG_DIR:-/nonexistent}" 2>/dev/null || true)"
  if [ -n "$CSS_FILE" ]; then
    if grep -q 'pi-web-hacker-theme' "$CSS_FILE"; then
      echo "css       : patched   ($(basename "$CSS_FILE"))"
    else
      echo "css       : pristine  ($(basename "$CSS_FILE"))"
    fi
  else
    echo "css       : not found"
  fi

  SW="${PKG_DIR:-/nonexistent}/public/sw.js"
  if [ -f "$SW" ]; then
    if grep -qE 'pi-web-custom-theme|pi-web-hacker-theme|custom-theme/apply\.sh|pi-web-hacker/apply\.sh' "$SW"; then
      TAG="$(grep -oE '\-h[0-9a-f]{8}' "$SW" | head -1 | tr -d '-')"
      echo "sw.js     : patched   (cache tag ${TAG:-unknown})"
    else
      echo "sw.js     : pristine"
    fi
  fi

  if [ -f "$THEME_DIR/backup/manifest.json" ]; then
    python3 - "$THEME_DIR/backup/manifest.json" <<'PY'
import json, sys

m = json.load(open(sys.argv[1]))
parts = []
for key in ("css", "sw"):
    entry = m.get(key) or {}
    if entry.get("sha256"):
        parts.append(f"{key} {entry['sha256'][:8]}")
if not parts and m.get("target"):
    parts.append(f"css {str(m.get('sha256', '?'))[:8]} (legacy record)")
version = m.get("pi_web_version", "?")
updated = m.get("updated", "")
suffix = f", updated {updated}" if updated else ""
print(f"backup    : {', '.join(parts) or '?'}  (pi-web {version}{suffix})")
PY
  else
    echo "backup    : none"
  fi
}

case "${1:-}" in
  ""|-h|--help|help)
    echo "usage: use.sh <skin> | off | status"
    echo
    echo "available skins:"
    list_skins
    echo
    echo "  use.sh greenscreen   switch the skin on"
    echo "  use.sh off           back to the stock look"
    echo "  use.sh status        show current state"
    ;;
  status)
    show_status
    ;;
  off|none|restore)
    rm -f "$ACTIVE"
    exec "$THEME_DIR/restore.sh"
    ;;
  *)
    THEME="$1"
    SKIN="$THEME_DIR/$THEME/skin.css"
    if [ ! -f "$SKIN" ]; then
      echo "✗ unknown skin: $THEME"
      echo "available:"
      list_skins
      exit 1
    fi
    printf '%s' "$THEME" > "$ACTIVE"
    echo "switch    : ON  ($THEME)"
    exec "$THEME_DIR/apply.sh" "$SKIN"
    ;;
esac
