#!/usr/bin/env bash
# --- pi-web custom theme: apply -------------------------------------------------
# Writes a skin into the installed pi-web CSS bundle and service worker.
# Idempotent, and self-healing: if pi-web was upgraded or reinstalled, it
# archives the stale backup and rebuilds it from the fresh bundle.
set -euo pipefail

THEME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$THEME_DIR/lib.sh"

BACKUP_DIR="$THEME_DIR/backup"
MANIFEST="$BACKUP_DIR/manifest.json"
SKIN="${1:-}"

PKG_DIR="$(ct_pkg_dir)" || {
  echo "✗ cannot locate the @agegr/pi-web package."
  echo "  install it first:  npm install -g @agegr/pi-web@latest"
  echo "  or point at it:    PI_WEB_PKG=/path/to/pi-web $(basename "$0") <skin.css>"
  exit 1
}
if [ -z "$SKIN" ]; then
  echo "usage: $(basename "$0") <skin.css>"
  echo "       skins: $(ls -d "$THEME_DIR"/*/ 2>/dev/null | xargs -n1 basename | tr '\n' ' ')"
  exit 1
fi
[ -f "$SKIN" ] || { echo "✗ skin not found: $SKIN"; exit 1; }

CSS_FILE="$(ct_css_file "$PKG_DIR")"
[ -n "$CSS_FILE" ] || { echo "✗ cannot locate the theme CSS bundle in $PKG_DIR/.next/static/css"; exit 1; }
SW_FILE="$PKG_DIR/public/sw.js"

mkdir -p "$BACKUP_DIR"

python3 - "$MANIFEST" "$CSS_FILE" "$SW_FILE" "$PKG_DIR" "$SKIN" <<'PY'
import datetime, hashlib, json, os, re, shutil, sys

manifest_path, css_file, sw_file, pkg_dir, skin_path = sys.argv[1:6]
backup_dir = os.path.dirname(manifest_path)

CSS_BEGIN = "/* === pi-web-hacker-theme:BEGIN === */"
CSS_END = "/* === pi-web-hacker-theme:END === */"
SW_MARKS = ("pi-web-custom-theme", "pi-web-hacker-theme", "custom-theme/apply.sh",
            "pi-web-hacker/apply.sh")


def sha_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha_file(path: str) -> str:
    return sha_bytes(open(path, "rb").read())


def read_text(path: str) -> str:
    return open(path, encoding="utf-8", newline="").read()


def write_text(path: str, text: str) -> None:
    with open(path, "w", encoding="utf-8", newline="") as handle:
        handle.write(text)


def archive(path: str, label: str):
    """Move a stale backup aside instead of destroying it."""
    if not os.path.exists(path):
        return None
    arch_dir = os.path.join(backup_dir, "archive")
    os.makedirs(arch_dir, exist_ok=True)
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    dest = os.path.join(arch_dir, f"{os.path.basename(path)}.{label}-{stamp}")
    shutil.move(path, dest)
    return dest


manifest = {}
if os.path.exists(manifest_path):
    try:
        manifest = json.load(open(manifest_path))
    except Exception:
        manifest = {}

# migrate the old flat manifest format (pi-web 0.9.1 era)
if "css" not in manifest and manifest.get("target"):
    manifest = {
        "created": manifest.get("created"),
        "pi_web_version": manifest.get("pi_web_version"),
        "css": {
            "target": manifest.get("target"),
            "sha256": manifest.get("sha256"),
            "size": manifest.get("size"),
        },
    }

version = json.load(open(os.path.join(pkg_dir, "package.json")))["version"]
notes = []

# ---------------------------------------------------------------- css bundle --
css_text = read_text(css_file)
css_stripped, css_removed = re.subn(
    re.escape(CSS_BEGIN) + r".*?" + re.escape(CSS_END), "", css_text,
    count=1, flags=re.S,
)
css_backup = os.path.join(backup_dir, os.path.basename(css_file) + ".orig")
css_entry = manifest.get("css") or {}

if css_removed:
    if (os.path.exists(css_backup) and css_entry.get("target") == css_file
            and css_entry.get("sha256") == sha_file(css_backup)):
        css_pristine = read_text(css_backup)          # trust the verified backup
    else:
        css_pristine = css_stripped.rstrip() + "\n"   # strip in place
else:
    css_pristine = css_text                            # bundle is untouched

css_pristine_sha = sha_bytes(css_pristine.rstrip().encode("utf-8"))
backup_ok = (
    os.path.exists(css_backup)
    and css_entry.get("target") == css_file
    and css_entry.get("sha256") == sha_file(css_backup)
    and css_entry.get("source_sha256") in (None, css_pristine_sha)
    and css_entry.get("pi_web_version") in (None, version)
)
if not backup_ok:
    if os.path.exists(css_backup):
        archived = archive(css_backup, "css")
        notes.append(f"archived stale css backup → {os.path.basename(archived or '')}")
    if css_removed and not os.path.exists(css_backup):
        pass  # pristine already stripped above
    write_text(css_backup, css_pristine)
    notes.append("rebuilt css backup from the installed bundle")

manifest["css"] = {
    "target": css_file,
    "sha256": sha_file(css_backup),
    "source_sha256": css_pristine_sha,
    "size": os.path.getsize(css_backup),
    "pi_web_version": version,
}

patch = read_text(skin_path).strip()
begin = patch.index(CSS_BEGIN) if CSS_BEGIN in patch else -1
if begin < 0 or CSS_END not in patch:
    sys.exit(f"✗ {skin_path} is missing the {CSS_BEGIN} / {CSS_END} markers")
# keep only the marked block, in case the file carries extra prose
patch = patch[begin:patch.index(CSS_END) + len(CSS_END)]
write_text(css_file, css_pristine.rstrip() + "\n" + patch + "\n")

# ------------------------------------------------------------ service worker --
sw_entry = manifest.get("sw") or {}
sw_backup = os.path.join(backup_dir, "sw.js.orig")
sw_notes = []

if sw_file and os.path.exists(sw_file):
    sw_text = read_text(sw_file)
    sw_patched = any(mark in sw_text for mark in SW_MARKS)

    if sw_patched:
        if (os.path.exists(sw_backup) and sw_entry.get("target") == sw_file
                and sw_entry.get("sha256") == sha_file(sw_backup)):
            sw_pristine = read_text(sw_backup)
        elif os.path.exists(sw_backup) and not any(m in read_text(sw_backup) for m in SW_MARKS):
            # install migrated from an older layout: no manifest record, but the
            # backup itself is demonstrably pristine
            sw_pristine = read_text(sw_backup)
            sw_notes.append("adopted the existing pristine sw.js backup")
        else:
            sw_pristine = None            # cannot recover → keep the file as is
            sw_notes.append("! sw.js is patched but no verified backup exists; left untouched")
    else:
        sw_pristine = sw_text

    if sw_pristine is not None:
        sw_pristine_sha = sha_bytes(sw_pristine.encode("utf-8"))
        sw_backup_ok = (
            os.path.exists(sw_backup)
            and sw_entry.get("target") == sw_file
            and sw_entry.get("sha256") == sha_file(sw_backup)
            and sw_entry.get("pi_web_version") in (None, version)
        )
        if not sw_backup_ok:
            already_pristine_backup = (
                os.path.exists(sw_backup)
                and sha_file(sw_backup) == sha_bytes(sw_pristine.encode("utf-8"))
            )
            if not already_pristine_backup:
                if os.path.exists(sw_backup):
                    archived = archive(sw_backup, "sw")
                    notes.append(f"archived stale sw backup → {os.path.basename(archived or '')}")
                write_text(sw_backup, sw_pristine)
                notes.append("rebuilt sw.js backup from the installed file")

        tag = hashlib.sha256(patch.encode("utf-8")).hexdigest()[:8]
        src = sw_pristine
        src, n1 = re.subn(
            r"const CACHE_VERSION = .*?;",
            'const CACHE_VERSION = (new URL(self.location.href).searchParams.get("v") '
            '|| "dev") + "-h%s";' % tag,
            src, count=1,
        )
        src, n2 = re.subn(
            r"const response = await fetch\(request\);",
            "// pi-web-custom-theme: on a cache miss, bypass the immutable\n"
            "  // HTTP cache so a freshly applied skin reaches cached clients.\n"
            '  const response = await fetch(request, { cache: "reload" });',
            src, count=1,
        )
        if n1 and n2:
            write_text(sw_file, src)
            manifest["sw"] = {
                "target": sw_file,
                "sha256": sha_file(sw_backup),
                "size": os.path.getsize(sw_backup),
                "pi_web_version": version,
                "cache_tag": "h" + tag,
            }
            sw_notes.append(f"service worker patched (cache tag h{tag})")
        else:
            sw_notes.append("! could not patch sw.js (unexpected content); left untouched")
else:
    sw_notes.append("! public/sw.js not found — skipped")

manifest["pi_web_version"] = version
manifest["updated"] = datetime.datetime.now().isoformat(timespec="seconds")
manifest["active_skin"] = os.path.abspath(skin_path)
json.dump(manifest, open(manifest_path, "w"), indent=2)

print(f"✓ skin applied: {os.path.basename(os.path.dirname(skin_path))}/"
      f"{os.path.basename(skin_path)}  (pi-web {version})")
print(f"  css  → {css_file}")
for line in sw_notes:
    print(f"  sw   {line}" if not line.startswith("!") else f"  {line}")
for line in notes:
    print(f"  note {line}")
PY
