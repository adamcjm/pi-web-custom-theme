#!/usr/bin/env bash
# --- pi-web custom theme: restore -----------------------------------------------
# Puts the pristine pi-web files back, byte for byte, verified against the
# sha256 recorded when the backup was taken.
set -euo pipefail

THEME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$THEME_DIR/lib.sh"

BACKUP_DIR="$THEME_DIR/backup"
MANIFEST="$BACKUP_DIR/manifest.json"
FORCE="${1:-}"

PKG_DIR="$(ct_pkg_dir)" || {
  echo "✗ cannot locate the @agegr/pi-web package (set PI_WEB_PKG=/path/to/pi-web)"
  exit 1
}

[ -f "$MANIFEST" ] || { echo "✗ nothing to restore: $MANIFEST is missing"; exit 1; }

python3 - "$MANIFEST" "$PKG_DIR" "$FORCE" <<'PY'
import hashlib, json, os, shutil, sys

manifest_path, pkg_dir, force = sys.argv[1:4]
backup_dir = os.path.dirname(manifest_path)


def sha_file(path: str) -> str:
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


manifest = json.load(open(manifest_path))
# accept the older flat manifest format too
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
recorded = manifest.get("pi_web_version")

if recorded and recorded != version and force != "--force":
    print(f"! the installed pi-web is {version}, but the backup was taken from {recorded}.")
    print("  restoring a stale bundle can break the UI — pass --force to override.")
    sys.exit(1)

jobs = []
css = manifest.get("css") or {}
if css.get("target"):
    jobs.append(("css bundle", css["target"],
                 os.path.join(backup_dir, os.path.basename(css["target"]) + ".orig"),
                 css.get("sha256")))
sw = manifest.get("sw") or {}
if sw.get("target"):
    jobs.append(("service worker", sw["target"],
                 os.path.join(backup_dir, "sw.js.orig"), sw.get("sha256")))

if not jobs:
    print("✗ manifest has no restorable files")
    sys.exit(1)

failed = False
for label, target, backup, expected in jobs:
    if not os.path.exists(backup):
        print(f"✗ {label}: backup missing ({backup})")
        failed = True
        continue
    if not os.path.exists(target):
        print(f"✗ {label}: target missing ({target}) — was pi-web reinstalled?")
        failed = True
        continue
    backup_sha = sha_file(backup)
    if expected and backup_sha != expected:
        print(f"✗ {label}: backup sha256 mismatch, refusing to restore")
        failed = True
        continue

    if sha_file(target) == backup_sha:
        print(f"✓ {label}: already pristine (sha256 {backup_sha[:12]})")
        continue

    shutil.copyfile(backup, target)
    result = sha_file(target)
    if result == backup_sha:
        print(f"✓ {label}: restored (sha256 {result[:12]})")
    else:
        print(f"✗ {label}: restore produced {result[:12]}, expected {backup_sha[:12]}")
        failed = True

if failed:
    sys.exit(1)

manifest.pop("active_skin", None)
manifest["updated"] = __import__("datetime").datetime.now().isoformat(timespec="seconds")
json.dump(manifest, open(manifest_path, "w"), indent=2)
PY

echo
echo "pi-web is back to its original look. hard-refresh the browser (Cmd+Shift+R)."
