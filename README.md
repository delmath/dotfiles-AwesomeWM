# dotfiles-AwesomeWM

Mon rice AwesomeWM 4.3 : une barre « verre », des raccourcis à la i3, et trois thèmes
liés chacun à un fond d'écran. Changer de fond change d'un coup les couleurs d'awesome,
d'alacritty, de rofi et du HUD.

Pensé pour Arch, et en particulier pour Arch dans [JuNest](https://github.com/fsquillace/junest)
sur les postes de 42 (pas de droits root, GNOME imposé).

## Contenu

| Chemin | Rôle |
| --- | --- |
| `config/awesome/rc.lua` | config awesome : barre, raccourcis, règles |
| `config/awesome/rice.lua` | les thèmes (fond + palette) et l'export des couleurs |
| `config/picom.conf` | flou, coins arrondis, transparence |
| `config/alacritty/` | terminal, importe `theme.toml` généré par `rice.lua` |
| `config/rofi/` | lanceur, importe `colors.rasi` généré par `rice.lua` |
| `config/LuminaHUD/` | [LuminaHUD](https://github.com/delmath/LuminaHUD) : horloge, météo, ISS, crypto, 42 |
| `bin/nog-awesome.sh` | gèle GNOME et lance awesome dans JuNest |
| `bin/gpurun`, `bin/chrome` | lancer une appli avec le GPU / le Chrome de l'hôte depuis JuNest |
| `wallpapers/` | les trois fonds d'écran des thèmes |

## Installation

```sh
git clone git@github.com:delmath/dotfiles-AwesomeWM.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

Le script :

1. installe les paquets avec `pacman` puis `yay` (`luminahud-git` vient de l'AUR) ;
2. crée des liens symboliques de `~/.config`, `~/.local/bin` et `~/Pictures/Wallpapers`
   vers le dépôt — un fichier déjà en place est renommé en `.bak.<date>`, rien n'est écrasé ;
3. crée `~/.config/LuminaHUD/42.env` (vide) et l'entrée de menu « Awesome (JuNest) ».

`./install.sh --no-packages` ne fait que les liens.

Paquets installés : `awesome picom rofi alacritty ttf-jetbrains-mono-nerd
papirus-icon-theme python libpulse` et `luminahud-git`.

Comme ce sont des liens, modifier `~/.config/awesome/rc.lua` modifie le dépôt :
il reste à faire `git commit` et `git push`.

### Lancer awesome

- **Arch classique** : choisir awesome dans le gestionnaire de connexion, ou `exec awesome`
  dans `~/.xinitrc`.
- **JuNest à 42** : lancer « Awesome (JuNest) » depuis le menu GNOME (ou
  `~/.local/bin/nog-awesome.sh`). Le script met GNOME en pause, lance awesome sur le même
  écran, et relance GNOME quand on quitte awesome (`Mod+Shift+e`).

### Blocs 42 du HUD

Créer une application sur <https://profile.intra.42.fr/oauth/applications/new>
(n'importe quelle URI de redirection, aucun scope), puis remplir `~/.config/LuminaHUD/42.env` :

```sh
FT_UID=...
FT_SECRET=...
FT_LOGIN=ton_login
```

Ce fichier n'est pas dans le dépôt. La météo est réglée sur Lyon : changer `LATITUDE` et
`LONGITUDE` en haut de `config/LuminaHUD/scripts/hud.py`.

### À adapter

En haut de `config/awesome/rc.lua` (section « Programmes ») :

- `browser` pointe vers `~/Applications/zen/zen` ;
- `filemanager` est `dolphin` (pas installé par le script) ;
- `lock_cmd` est `/host/usr/bin/ft_lock`, propre aux postes de 42.

Le HUD est placé pour un écran 1920x1080.

## Raccourcis

`Mod` est la touche Super. `Mod+s` affiche l'aide complète.

| Raccourci | Action |
| --- | --- |
| `Mod+Entrée` | terminal (alacritty) |
| `Mod+Espace` | lanceur (rofi) |
| `Mod+b` / `Mod+d` | navigateur / fichiers |
| `Mod+q` | fermer la fenêtre |
| `Mod+j` `k` `l` `;` ou flèches | focus gauche / bas / haut / droite |
| `Mod+Shift` + les mêmes | déplacer la fenêtre |
| `Mod+1`…`6` | aller au tag |
| `Mod+Shift+1`…`6` | envoyer la fenêtre sur le tag |
| `Mod+Tab` / `Mod+Shift+Tab` | tag suivant / précédent |
| `Mod+e` `w` `a` `f` | layout tile / max / fair / flottant |
| `Mod+m` / `Mod+F11` | maximiser / plein écran |
| `Mod+Shift+f` | fenêtre flottante |
| `Mod+Shift+w` / `Mod+Ctrl+w` | thème suivant / précédent |
| `Mod+Shift+x` | verrouiller |
| `Mod+Shift+r` | redémarrer awesome |
| `Mod+Shift+e` | quitter awesome |

## Thèmes

| Thème | Fond | Ambiance |
| --- | --- | --- |
| casque | `1280310.jpg` | nuit spatiale, jaune |
| lune | `1296280.jpg` | gris chaud, or |
| néon | `1310342.jpg` | bleu nuit, magenta et cyan |

Pour en ajouter un : poser l'image dans `wallpapers/`, relancer `./install.sh --no-packages`,
et ajouter une entrée dans `M.themes` de `config/awesome/rice.lua` (mêmes clés que les
autres). Le HUD, lui, se règle par thème dans `config/LuminaHUD/config`.

## Désinstaller

Supprimer les liens et remettre les `.bak.<date>` s'il y en a :

```sh
find ~/.config ~/.local/bin ~/Pictures/Wallpapers -lname "$HOME/dotfiles/*" -delete
```
