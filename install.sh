#!/usr/bin/env bash
# --- pi-web custom theme: installer ---------------------------------------------
#   ./install.sh                 install with the default skin (greenscreen)
#   ./install.sh amber           pick another skin from this repo
#   ./install.sh greenscreen --no-launcher
#
# Does three things:
#   1. locates your @agegr/pi-web installation (npm global, npx cache, ...)
#   2. activates the skin (writes it into pi-web and remembers the choice)
#   3. optionally puts ./bin first in PATH so `pi-web` re-applies the skin
#      automatically after every upgrade
set -euo pipefail

THEME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$THEME_DIR/lib.sh"

SKIN="${1:-greenscreen}"
LAUNCHER="${2:-}"
[ "$SKIN" = "--help" ] && SKIN="greenscreen"

echo "pi-web custom theme — installer"
echo

# ---------------------------------------------------------------- locate pi-web
PKG_DIR="$(ct_pkg_dir)" || {
  echo "✗ cannot find the @agegr/pi-web package."
  echo
  echo "  install it first:"
  echo "    npm install -g @agegr/pi-web@latest"
  echo
  echo "  or, if it lives somewhere unusual:"
  echo "    PI_WEB_PKG=/path/to/node_modules/@agegr/pi-web ./install.sh"
  exit 1
}
echo "✓ pi-web package : $PKG_DIR"

CSS_FILE="$(ct_css_file "$PKG_DIR")" || true
if [ -z "$CSS_FILE" ]; then
  echo "✗ cannot find the theme CSS bundle inside that package."
  echo "  is this a complete pi-web build? (expected: .next/static/css/*.css)"
  exit 1
fi
echo "✓ theme bundle   : $(basename "$CSS_FILE")"

SKIN_FILE="$THEME_DIR/$SKIN/skin.css"
if [ ! -f "$SKIN_FILE" ]; then
  echo "✗ unknown skin: $SKIN"
  echo "  available: $(ls -d "$THEME_DIR"/*/ 2>/dev/null | xargs -n1 basename | tr '\n' ' ')"
  exit 1
fi

# ------------------------------------------------------------------- permissions
if [ ! -w "$CSS_FILE" ] || [ ! -w "$(dirname "$CSS_FILE")" ]; then
  echo "✗ no write permission on $CSS_FILE"
  echo "  (if pi-web was installed system-wide, re-run with sudo — or use a user-level npm prefix)"
  exit 1
fi

# ----------------------------------------------------------------- activate skin
printf '%s' "$SKIN" > "$THEME_DIR/active"
bash "$THEME_DIR/apply.sh" "$SKIN_FILE"

# --------------------------------------------------------------- launcher (PATH)
if [ "$LAUNCHER" != "--no-launcher" ]; then
  echo
  case "${SHELL:-}" in
    */zsh) RC="$HOME/.zshrc" ;;
    */bash) RC="$HOME/.bashrc" ;;
    *) RC="" ;;
  esac
  LINE="export PATH=\"$THEME_DIR/bin:\$PATH\""
  MARK="# pi-web custom theme: re-apply the skin on every start (survives upgrades)"
  if [ -z "$RC" ]; then
    echo "! could not detect your shell; add this line manually:"
    echo "    $LINE"
  elif grep -qF "$MARK" "$RC" 2>/dev/null \
    || grep -qF "$(basename "$THEME_DIR")/bin" "$RC" 2>/dev/null; then
    echo "✓ launcher already configured ($(basename "$RC"))"
  else
    {
      printf '\n%s\n%s\n' "$MARK" "$LINE"
    } >> "$RC"
    echo "✓ launcher added to $(basename "$RC")"
    echo "    $LINE"
    echo "  (applies to new shells; run \`source $RC\` for this one)"
  fi
fi

echo
echo "done. hard-refresh the browser (Cmd+Shift+R / Ctrl+Shift+R) to see it."
echo
echo "  change skin :  $THEME_DIR/use.sh <skin>"
echo "  status      :  $THEME_DIR/use.sh status"
echo "  back to stock:  $THEME_DIR/use.sh off"
