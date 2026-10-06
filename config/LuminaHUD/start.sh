#!/bin/sh
# (Re)starts LuminaHUD with the theme of the current awesome rice (1, 2 or 3).
pkill -x LuminaHUD
LUMINA_THEME=$(cat "$HOME/.cache/awesome-rice/current" 2>/dev/null || echo 1)
export LUMINA_THEME
exec LuminaHUD
