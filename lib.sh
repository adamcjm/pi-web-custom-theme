# shellcheck shell=bash
# --- shared helpers for the pi-web custom-theme scripts -------------------------
# Sourced by apply.sh / restore.sh / use.sh / bin/pi-web. Not meant to be run.

# Directory this repo lives in (works no matter where it was cloned).
ct_repo_dir() {
  local src="${BASH_SOURCE[1]:-$0}"
  cd "$(dirname "$src")" && pwd
}

# Locate the installed @agegr/pi-web package.
# Order: $PI_WEB_PKG → npm global root → the pi-web shim in PATH → common prefixes.
ct_pkg_dir() {
  if [ -n "${PI_WEB_PKG:-}" ]; then
    [ -d "$PI_WEB_PKG" ] && { printf '%s' "$PI_WEB_PKG"; return 0; }
    echo "✗ PI_WEB_PKG is set but not a directory: $PI_WEB_PKG" >&2
    return 1
  fi

  local root
  if command -v npm >/dev/null 2>&1; then
    root="$(npm root -g 2>/dev/null || true)"
    if [ -n "$root" ] && [ -d "$root/@agegr/pi-web" ]; then
      printf '%s' "$root/@agegr/pi-web"; return 0
    fi
  fi

  local shim resolved
  shim="$(command -v pi-web 2>/dev/null || true)"
  if [ -n "$shim" ]; then
    resolved="$(python3 -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' "$shim" 2>/dev/null || true)"
    case "$resolved" in
      */node_modules/@agegr/pi-web/*)
        printf '%s' "${resolved%%/node_modules/@agegr/pi-web/*}/node_modules/@agegr/pi-web"
        return 0 ;;
    esac
  fi

  local candidate
  for candidate in \
    "$HOME/.local/lib/node_modules/@agegr/pi-web" \
    "/usr/local/lib/node_modules/@agegr/pi-web" \
    "/opt/homebrew/lib/node_modules/@agegr/pi-web" \
    "$HOME/.npm-global/lib/node_modules/@agegr/pi-web" \
    "$HOME/.bun/install/global/node_modules/@agegr/pi-web"; do
    [ -d "$candidate" ] && { printf '%s' "$candidate"; return 0; }
  done

  return 1
}

# The CSS bundle that carries the theme variables.
ct_css_file() {
  local pkg="$1" dir
  dir="$pkg/.next/static/css"
  [ -d "$dir" ] || return 1
  grep -rlE -- 'data-theme="?pine' "$dir"/*.css 2>/dev/null | head -1
}

# Locate the launcher that npm installed (for the wrapper to delegate to).
ct_real_launcher() {
  local pkg="$1" candidate
  for candidate in "$pkg/bin/pi-web.js" "$pkg/bin/pi-web"; do
    [ -f "$candidate" ] && { printf '%s' "$candidate"; return 0; }
  done
  return 1
}
