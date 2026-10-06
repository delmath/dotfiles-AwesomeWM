-- ~/.config/awesome/rice.lua — thèmes liés aux fonds d'écran de ~/Pictures/Wallpapers.
-- Chaque thème = un fond + une palette tirée de l'image. rc.lua lit rice.current().
local gears = require("gears")
local cairo = require("lgi").cairo

local home      = os.getenv("HOME")
local wall_dir  = home .. "/Pictures/Wallpapers/"
local cache_dir = home .. "/.cache/awesome-rice/"
local state     = cache_dir .. "current"

local M = {}

M.themes = {
    { name = "casque", wallpaper = "1280310.jpg",       -- nuit spatiale, veste jaune
      base = "#0a0c1a", mantle = "#10132a", surface0 = "#1d2244", surface1 = "#2c3362",
      text = "#e6e8f5", subtext = "#9aa0c4",
      accent = "#f5d51e", accent2 = "#7fe3c4", red = "#f0685c",
      green = "#8fe39a", yellow = "#f5d51e", blue = "#7c9cff",
      magenta = "#b79cf5", cyan = "#7fe3c4" },
    { name = "lune", wallpaper = "1296280.jpg",         -- gris chaud, confettis dorés
      base = "#151318", mantle = "#1d1a21", surface0 = "#2c2832", surface1 = "#3f3a47",
      text = "#e9e6ee", subtext = "#a39dae",
      accent = "#e9b949", accent2 = "#a8b9ee", red = "#ee7b5d",
      green = "#a9c98f", yellow = "#e9b949", blue = "#a8b9ee",
      magenta = "#c5a3d9", cyan = "#9fd0d6" },
    { name = "néon", wallpaper = "1310342.jpg",         -- bleu nuit, néons magenta
      base = "#0c0a22", mantle = "#131033", surface0 = "#221c4e", surface1 = "#33296f",
      text = "#e4e0ff", subtext = "#9b93cc",
      accent = "#e06cff", accent2 = "#5fd0ff", red = "#ff6b7d",
      green = "#7fe0a8", yellow = "#ffb86b", blue = "#6f8cff",
      magenta = "#e06cff", cyan = "#5fd0ff" },
}

gears.filesystem.make_directories(cache_dir)

local function read_index()
    local f = io.open(state)
    local i = f and tonumber(f:read("*l"))
    if f then f:close() end
    return (i and M.themes[i]) and i or 1
end

M.index = read_index()

function M.current() return M.themes[M.index] end

-- Passe au thème suivant (ou précédent avec step = -1) ; rc.lua redémarre ensuite awesome.
function M.cycle(step)
    M.index = (M.index - 1 + (step or 1)) % #M.themes + 1
    local f = io.open(state, "w")
    if f then f:write(M.index, "\n"); f:close() end
end

-- Les originaux font jusqu'à 7680x4320 : on garde une copie à la taille de l'écran.
function M.wallpaper(s, theme)
    theme = theme or M.current()
    local g = s.geometry
    local src_path = wall_dir .. theme.wallpaper
    local cache = string.format("%s%s-%dx%d.png", cache_dir, theme.wallpaper, g.width, g.height)
    if gears.filesystem.file_readable(cache) then return cache end
    if not gears.filesystem.file_readable(src_path) then return nil end

    local src = gears.surface.load_uncached(src_path)
    local sw, sh = gears.surface.get_size(src)
    local scale = math.max(g.width / sw, g.height / sh)
    local img = cairo.ImageSurface(cairo.Format.RGB24, g.width, g.height)
    local cr = cairo.Context(img)
    cr:translate((g.width - sw * scale) / 2, (g.height - sh * scale) / 2)
    cr:scale(scale, scale)
    cr:set_source_surface(src, 0, 0)
    cr:paint()
    img:write_to_png(cache)
    src:finish()
    return cache
end

local function write_if_changed(path, content)
    local f = io.open(path)
    local old = f and f:read("*a")
    if f then f:close() end
    if old == content then return end
    f = io.open(path, "w")
    if f then f:write(content); f:close() end
end

-- Couleurs du terminal et du lanceur, importées par alacritty.toml et config.rasi.
function M.export()
    local t = M.current()
    local ansi = string.format([[
black = "%s"
red = "%s"
green = "%s"
yellow = "%s"
blue = "%s"
magenta = "%s"
cyan = "%s"
]], t.surface0, t.red, t.green, t.yellow, t.blue, t.magenta, t.cyan)

    write_if_changed(home .. "/.config/alacritty/theme.toml", string.format([[
# Généré par ~/.config/awesome/rice.lua (thème « %s ») — ne pas éditer.
[colors.primary]
background = "%s"
foreground = "%s"

[colors.cursor]
cursor = "%s"
text = "%s"

[colors.selection]
background = "%s"
text = "CellForeground"

[colors.normal]
%swhite = "%s"

[colors.bright]
%swhite = "%s"
]], t.name, t.base, t.text, t.accent, t.base, t.surface1,
        ansi, t.subtext, ansi:gsub(t.surface0, t.surface1, 1), t.text))

    write_if_changed(home .. "/.config/rofi/colors.rasi", string.format([[
/* Généré par ~/.config/awesome/rice.lua (thème « %s ») — ne pas éditer. */
* {
    base:     %scc;
    mantle:   %s99;
    surface:  %scc;
    text:     %s;
    subtext:  %s;
    accent:   %s;
    accent2:  %s;
}
]], t.name, t.base, t.mantle, t.surface0, t.text, t.subtext, t.accent, t.accent2))
end

return M
