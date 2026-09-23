# greenscreen

A terminal / CRT skin: monochrome phosphor, scanlines, sharp corners. It keeps pi-web's
layout untouched and only swaps colours, type and texture.

## What it does

| | |
|---|---|
| Type | JetBrainsMono Nerd Font everywhere (UI + terminal panel) |
| Corners | square — all border radii removed |
| Texture | CRT scanlines (1px / 3px) |
| Palette | phosphor green on near-black, dark green rules |
| Details | inverted text selection, block scrollbars |

The five built-in pi-web themes are re-mapped onto terminal palettes, so pi-web's own
theme switcher keeps working (icons and "follow system" included):

| pi-web theme | becomes | background | foreground |
|---|---|---|---|
| Light | Phosphor Green | `#08120e` | `#7cffb2` |
| **Dark** | **Matrix** | `#020403` | `#00ff41` |
| Mist | Cyberdeck Cyan | `#001014` | `#7ef9ff` |
| Rose | Neon Magenta | `#120016` | `#ff9dff` |
| Pine | Amber CRT | `#140d00` | `#ffb000` |

## Editing it

All colours live in the `[data-theme="…"]` blocks near the bottom of `skin.css`.
Change `--bg`, `--text`, `--accent` and you have a different skin.

```bash
# after editing, push it back into pi-web
../use.sh greenscreen
```

Hard-refresh the browser to preview.

> Keep the `/* === pi-web-hacker-theme:BEGIN/END === */` markers — `apply.sh` and
> `restore.sh` use them to identify the patch.

## Making a sibling skin

```bash
cp -r . ../amber
$EDITOR ../amber/skin.css
../use.sh amber
```

Nothing else is required: `use.sh` discovers any directory containing a `skin.css`.
