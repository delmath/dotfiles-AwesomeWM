#!/bin/bash
# Installe les dotfiles : paquets (Arch), puis liens symboliques vers ce dépôt.
# Un fichier déjà présent est renommé en <fichier>.bak.<date> avant d'être remplacé.
#
#   ./install.sh                 paquets + liens
#   ./install.sh --no-packages   liens seulement
set -eu

REPO="$(cd "$(dirname "$0")" && pwd)"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
STAMP="$(date +%Y%m%d-%H%M%S)"
PACKAGES="awesome picom rofi alacritty ttf-jetbrains-mono-nerd papirus-icon-theme python libpulse maim xclip"
AUR_PACKAGES="luminahud-git"

install_packages=1
for arg in "$@"; do
    case "$arg" in
        --no-packages) install_packages=0 ;;
        -h|--help) sed -n '2,6s/^# \{0,1\}//p' "$0"; exit 0 ;;
        *) echo "option inconnue : $arg" >&2; exit 1 ;;
    esac
done

link() {
    local src="$1" dest="$2"
    if [ "$(readlink "$dest" 2>/dev/null)" = "$src" ]; then
        return
    fi
    mkdir -p "$(dirname "$dest")"
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        mv "$dest" "$dest.bak.$STAMP"
        echo "  sauvegarde : $dest.bak.$STAMP"
    fi
    ln -s "$src" "$dest"
    echo "  $dest -> $src"
}

if [ "$install_packages" = 1 ]; then
    if command -v pacman > /dev/null; then
        echo "Paquets :"
        # shellcheck disable=SC2086
        sudo pacman -S --needed $PACKAGES
        if command -v yay > /dev/null; then
            # shellcheck disable=SC2086
            yay -S --needed $AUR_PACKAGES
        else
            echo "  yay introuvable : installer $AUR_PACKAGES à la main (AUR)" >&2
        fi
    else
        echo "pacman introuvable : installer à la main $PACKAGES $AUR_PACKAGES" >&2
    fi
fi

echo "Configuration :"
# Fichier par fichier : les fichiers générés (theme.toml, colors.rasi) et 42.env
# restent dans ~/.config, hors du dépôt.
(cd "$REPO/config" && find . -type f ! -name '*.example' | sed 's|^\./||') | while read -r file; do
    link "$REPO/config/$file" "$CONFIG/$file"
done

echo "Scripts :"
for script in "$REPO"/bin/*; do
    link "$script" "$HOME/.local/bin/$(basename "$script")"
done

echo "Fonds d'écran :"
for wallpaper in "$REPO"/wallpapers/*; do
    link "$wallpaper" "$HOME/Pictures/Wallpapers/$(basename "$wallpaper")"
done

# rc.lua y enregistre les captures d'écran
mkdir -p "$HOME/Pictures/Screenshots"

if [ ! -e "$CONFIG/LuminaHUD/42.env" ]; then
    install -m 600 "$REPO/config/LuminaHUD/42.env.example" "$CONFIG/LuminaHUD/42.env"
    echo "À remplir pour les blocs 42 du HUD : $CONFIG/LuminaHUD/42.env"
fi

# Entrée de menu pour lancer awesome depuis GNOME (JuNest)
desktop="$HOME/.local/share/applications/nog-awesome.desktop"
mkdir -p "$(dirname "$desktop")"
cat > "$desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Awesome (JuNest)
Comment=Gèle GNOME et lance AwesomeWM
Exec=$HOME/.local/bin/nog-awesome.sh
Icon=preferences-desktop-display
Terminal=false
Categories=System;
EOF
chmod +x "$desktop"
echo "Lanceur : $desktop"

echo "Terminé."
