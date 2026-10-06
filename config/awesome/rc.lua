-- ~/.config/awesome/rc.lua — AwesomeWM 4.3 — thème suivant le fond d'écran (rice.lua), raccourcis i3.
local gears     = require("gears")
local awful     = require("awful")
require("awful.autofocus")
local wibox     = require("wibox")
local beautiful = require("beautiful")
local naughty   = require("naughty")
local hotkeys_popup = require("awful.hotkeys_popup")
local rice      = require("rice")

if awesome.startup_errors then
    naughty.notify { preset = naughty.config.presets.critical,
        title = "Erreur au démarrage", text = awesome.startup_errors }
end
do
    local in_error = false
    awesome.connect_signal("debug::error", function(err)
        if in_error then return end
        in_error = true
        naughty.notify { preset = naughty.config.presets.critical,
            title = "Erreur", text = tostring(err) }
        in_error = false
    end)
end

-- Palette du thème courant (une par fond d'écran, voir rice.lua).
-- C est une copie que apply_theme() met à jour sur place : tout ce qui lit C suit le thème.
local C = gears.table.clone(rice.current())
rice.export()

local function rounded(radius)
    return function(cr, width, height)
        gears.shape.rounded_rect(cr, width, height, radius)
    end
end

beautiful.init(gears.filesystem.get_themes_dir() .. "default/theme.lua")
-- Couleurs du thème : rappelé par apply_theme() à chaque changement de fond
local function apply_beautiful()
    beautiful.font          = "JetBrainsMono Nerd Font 10"
    beautiful.bg_normal     = C.base
    beautiful.bg_focus      = C.surface0
    beautiful.bg_urgent     = C.red
    beautiful.bg_systray    = C.mantle
    beautiful.fg_normal     = C.text
    beautiful.fg_focus      = C.accent
    beautiful.fg_urgent     = C.base
    beautiful.useless_gap   = 6
    beautiful.gap_single_client = true
    beautiful.border_width  = 2
    beautiful.border_normal = C.surface0
    beautiful.border_focus  = C.accent

    beautiful.taglist_bg_focus    = C.accent
    beautiful.taglist_fg_focus    = C.base
    beautiful.taglist_fg_occupied = C.accent2
    beautiful.taglist_fg_empty    = C.subtext
    beautiful.taglist_squares_sel   = nil
    beautiful.taglist_squares_unsel = nil

    beautiful.tasklist_bg_normal   = "#00000000"
    beautiful.tasklist_fg_normal   = C.subtext
    beautiful.tasklist_bg_focus    = "#00000000"
    beautiful.tasklist_fg_focus    = C.text
    beautiful.tasklist_bg_minimize = C.base .. "80"
    beautiful.tasklist_fg_minimize = C.surface1
    beautiful.tasklist_plain_task_name = true

    beautiful.notification_bg           = C.base .. "e6"
    beautiful.notification_fg           = C.text
    beautiful.notification_border_color = C.accent
    beautiful.notification_border_width = 2
    beautiful.notification_shape        = rounded(10)
    beautiful.notification_margin       = 10

    beautiful.hotkeys_bg           = C.base .. "e6"
    beautiful.hotkeys_fg           = C.text
    beautiful.hotkeys_modifiers_fg = C.subtext
    beautiful.hotkeys_border_color = C.accent
    beautiful.hotkeys_border_width = 2
    beautiful.hotkeys_shape        = rounded(12)

    -- icônes de layout recolorées dans la couleur du texte
    for _, name in ipairs { "tile", "tilebottom", "fairv", "max", "floating" } do
        beautiful["layout_" .. name] =
            gears.color.recolor_image(beautiful["layout_" .. name], C.text)
    end
end
apply_beautiful()

-- Programmes (repris de ta config i3)
local terminal    = "alacritty"
local browser     = os.getenv("HOME") .. "/Applications/zen/zen"
local filemanager = "dolphin"
local modkey      = "Mod4"
local launcher    = "rofi -show drun"
local lock_cmd    = "/host/usr/bin/ft_lock"

awful.layout.layouts = {
    awful.layout.suit.tile,
    awful.layout.suit.tile.bottom,
    awful.layout.suit.fair,
    awful.layout.suit.max,
    awful.layout.suit.floating,
}

local function set_wallpaper(s)
    local wall = rice.wallpaper(s)
    if wall then
        gears.wallpaper.maximized(wall, s)
    else
        gears.wallpaper.set(gears.color(C.mantle))
    end
end
screen.connect_signal("property::geometry", set_wallpaper)

-- ===== Barre =====
-- un seul bandeau « verre » : titre à gauche, tags au centre, heure à droite
local function clock_format()
    return "<span foreground='" .. C.subtext .. "'>%a %d %b</span>  <b>%H:%M</b>"
end
local mytextclock = wibox.widget.textclock(clock_format())
-- le calendrier fige ses couleurs à la création : apply_theme() en refait un
local function make_calendar() return awful.widget.calendar_popup.month {
    position = "tr", margin = 8, start_sunday = false, long_weekdays = false,
    style_month   = { bg_color = C.base .. "e6", border_color = C.accent,
                      border_width = 2, padding = 12, shape = rounded(12) },
    style_header  = { fg_color = C.accent, bg_color = "#00000000", border_width = 0 },
    style_weekday = { fg_color = C.subtext, bg_color = "#00000000", border_width = 0 },
    style_normal  = { fg_color = C.text, bg_color = "#00000000", border_width = 0 },
    style_focus   = { fg_color = C.base, bg_color = C.accent, border_width = 0,
                      shape = rounded(6) },
} end
local calendar = make_calendar()
-- comme calendar:attach(mytextclock, "tr", { on_hover = false }), mais sur le calendrier courant
mytextclock:buttons(gears.table.join(
    awful.button({}, 1, function()
        if not calendar.visible or calendar._calendar_clicked_on then
            calendar:call_calendar(0, "tr")
            calendar.visible = not calendar.visible
        end
        calendar._calendar_clicked_on = calendar.visible
    end),
    awful.button({}, 4, function() calendar:call_calendar(-1) end),
    awful.button({}, 5, function() calendar:call_calendar(1) end)
))

local taglist_buttons = gears.table.join(
    awful.button({}, 1, function(t) t:view_only() end),
    awful.button({ modkey }, 1, function(t)
        if client.focus then client.focus:move_to_tag(t) end end),
    awful.button({}, 3, awful.tag.viewtoggle)
)

-- tag = un point : allongé et coloré si actif, clair si occupé, sombre si vide
local function update_tag_dot(self, t)
    local dot = self:get_children_by_id("dot")[1]
    dot.forced_width = t.selected and 22 or 8
    if t.selected then dot.bg = C.accent
    elseif t.urgent then dot.bg = C.red
    elseif #t:clients() > 0 then dot.bg = C.accent2
    else dot.bg = C.text .. "40" end
end

awful.screen.connect_for_each_screen(function(s)
    awful.tag({ "1", "2", "3", "4", "5", "6" }, s, awful.layout.layouts[1])
    set_wallpaper(s)
    s.mypromptbox = awful.widget.prompt()
    s.mylayoutbox = awful.widget.layoutbox(s)
    s.mylayoutbox:buttons(gears.table.join(
        awful.button({}, 1, function() awful.layout.inc(1) end),
        awful.button({}, 3, function() awful.layout.inc(-1) end)
    ))
    s.mytaglist = awful.widget.taglist {
        screen = s, filter = awful.widget.taglist.filter.all,
        buttons = taglist_buttons,
        layout = { spacing = 8, layout = wibox.layout.fixed.horizontal },
        widget_template = {
            { { widget = wibox.widget.base.empty_widget },
              id = "dot", forced_height = 8, forced_width = 8,
              shape = gears.shape.rounded_bar, widget = wibox.container.background },
            valign = "center", widget = wibox.container.place,
            create_callback = update_tag_dot,
            update_callback = update_tag_dot,
        },
    }
    -- icône + titre de la fenêtre qui a le focus
    s.mytasklist = awful.widget.tasklist {
        screen = s, filter = awful.widget.tasklist.filter.focused,
        widget_template = {
            { { { id = "clienticon", widget = awful.widget.clienticon },
                top = 6, bottom = 6, widget = wibox.container.margin },
              { id = "text_role", widget = wibox.widget.textbox },
              spacing = 8, layout = wibox.layout.fixed.horizontal },
            id = "background_role", widget = wibox.container.background,
            create_callback = function(self, c)
                self:get_children_by_id("clienticon")[1].client = c
            end,
        },
    }
    -- teinte de la barre ; picom floute le fond d'écran derrière
    s.mywibox = awful.wibar { position = "top", screen = s, height = 28, bg = C.base .. "80" }
    s.mywibox:setup {
        { layout = wibox.layout.align.horizontal, expand = "none",
          { layout = wibox.layout.fixed.horizontal, spacing = 10,
            { s.mytasklist, width = 600, strategy = "max",
              widget = wibox.container.constraint },
            s.mypromptbox },
          s.mytaglist,
          { layout = wibox.layout.fixed.horizontal, spacing = 12,
            -- la zone de notification ne sait pas être transparente : pastille opaque
            { { { wibox.widget.systray(), left = 8, right = 8,
                  widget = wibox.container.margin },
                id = "systray_pill", bg = C.mantle, shape = gears.shape.rounded_bar,
                widget = wibox.container.background },
              top = 4, bottom = 4, widget = wibox.container.margin },
            mytextclock,
            { s.mylayoutbox, top = 7, bottom = 7, widget = wibox.container.margin } },
        },
        left = 14, right = 14, widget = wibox.container.margin,
    }
end)

-- Change de fond et de thème sans redémarrer awesome : un restart réaffiche un instant
-- les fenêtres de tous les tags, ce qui donne l'impression de passer par le tag 1.
local function apply_theme()
    for k, v in pairs(rice.current()) do C[k] = v end
    rice.export()
    apply_beautiful()
    mytextclock:set_format(clock_format())
    calendar.visible = false
    calendar = make_calendar()
    for s in screen do
        set_wallpaper(s)
        s.mywibox.bg = C.base .. "80"
        local pill = s.mywibox:get_children_by_id("systray_pill")[1]
        if pill then pill.bg = C.mantle end
        s.mytaglist._do_taglist_update()
        s.mytasklist._do_tasklist_update()
        if s.selected_tag then s.selected_tag:emit_signal("property::layout") end
    end
    for _, c in ipairs(client.get()) do
        c.border_color = (c == client.focus) and C.accent or C.surface0
    end
    awful.spawn.with_shell("~/.config/LuminaHUD/start.sh")
end

-- Capture enregistrée dans ~/Pictures/Screenshots et copiée dans le presse-papiers.
-- "-s -u -t 0" : zone tracée à la souris, sans curseur, sans sélection de fenêtre au clic.
local function screenshot(options)
    awful.spawn.with_shell(
        "f=~/Pictures/Screenshots/\"$(date +'Screenshot from %Y-%m-%d %H-%M-%S').png\"; "
        .. "maim " .. options .. " \"$f\" && xclip -selection clipboard -t image/png -i \"$f\"")
end

-- ===== Raccourcis globaux style i3 =====
local globalkeys = gears.table.join(
    awful.key({ modkey }, "s", hotkeys_popup.show_help,
        { description = "aide", group = "awesome" }),
    awful.key({ modkey, "Shift" }, "r", awesome.restart,
        { description = "redémarrer", group = "awesome" }),
    awful.key({ modkey, "Shift" }, "e", awesome.quit,
        { description = "quitter (retour GNOME)", group = "awesome" }),

    awful.key({ modkey }, "Return", function() awful.spawn(terminal) end,
        { description = "terminal", group = "launcher" }),
    awful.key({ modkey }, "b", function() awful.spawn(browser) end,
        { description = "navigateur", group = "launcher" }),
    awful.key({ modkey }, "d", function() awful.spawn(filemanager) end,
        { description = "fichiers", group = "launcher" }),
    awful.key({ modkey }, "space", function() awful.spawn(launcher) end,
        { description = "lanceur", group = "launcher" }),
    awful.key({ modkey, "Shift" }, "x", function() awful.spawn(lock_cmd) end,
        { description = "verrouiller", group = "launcher" }),

    -- Focus vim : j gauche, k bas, l haut, ; droite
    awful.key({ modkey }, "j", function() awful.client.focus.bydirection("left") end,
        { description = "focus gauche", group = "client" }),
    awful.key({ modkey }, "k", function() awful.client.focus.bydirection("down") end,
        { description = "focus bas", group = "client" }),
    awful.key({ modkey }, "l", function() awful.client.focus.bydirection("up") end,
        { description = "focus haut", group = "client" }),
    awful.key({ modkey }, "semicolon", function() awful.client.focus.bydirection("right") end,
        { description = "focus droite", group = "client" }),
    awful.key({ modkey }, "Left",  function() awful.client.focus.bydirection("left") end),
    awful.key({ modkey }, "Down",  function() awful.client.focus.bydirection("down") end),
    awful.key({ modkey }, "Up",    function() awful.client.focus.bydirection("up") end),
    awful.key({ modkey }, "Right", function() awful.client.focus.bydirection("right") end),

    awful.key({ modkey, "Shift" }, "j", function() awful.client.swap.bydirection("left") end,
        { description = "déplacer gauche", group = "client" }),
    awful.key({ modkey, "Shift" }, "k", function() awful.client.swap.bydirection("down") end,
        { description = "déplacer bas", group = "client" }),
    awful.key({ modkey, "Shift" }, "l", function() awful.client.swap.bydirection("up") end,
        { description = "déplacer haut", group = "client" }),
    awful.key({ modkey, "Shift" }, "semicolon", function() awful.client.swap.bydirection("right") end,
        { description = "déplacer droite", group = "client" }),
    awful.key({ modkey, "Shift" }, "Left",  function() awful.client.swap.bydirection("left") end),
    awful.key({ modkey, "Shift" }, "Down",  function() awful.client.swap.bydirection("down") end),
    awful.key({ modkey, "Shift" }, "Up",    function() awful.client.swap.bydirection("up") end),
    awful.key({ modkey, "Shift" }, "Right", function() awful.client.swap.bydirection("right") end),

    awful.key({ modkey }, "w", function() awful.layout.set(awful.layout.suit.max) end,
        { description = "layout max", group = "layout" }),
    awful.key({ modkey }, "e", function() awful.layout.set(awful.layout.suit.tile) end,
        { description = "layout tile", group = "layout" }),
    awful.key({ modkey }, "a", function() awful.layout.set(awful.layout.suit.fair) end,
        { description = "layout fair", group = "layout" }),
    awful.key({ modkey }, "f", function() awful.layout.set(awful.layout.suit.floating) end,
        { description = "layout flottant", group = "layout" }),

    awful.key({ modkey, "Shift" }, "w", function() rice.cycle(1); apply_theme() end,
        { description = "fond d'écran + thème suivant", group = "awesome" }),
    awful.key({ modkey, "Control" }, "w", function() rice.cycle(-1); apply_theme() end,
        { description = "fond d'écran + thème précédent", group = "awesome" }),

    awful.key({}, "Print", function() screenshot("") end,
        { description = "capture de l'écran", group = "launcher" }),
    awful.key({ "Shift" }, "Print", function() screenshot("-s -u -t 0") end,
        { description = "capture d'une zone", group = "launcher" }),
    awful.key({ modkey, "Shift" }, "s", function() screenshot("-s -u -t 0") end,
        { description = "capture d'une zone", group = "launcher" }),

    awful.key({ modkey }, "Tab", awful.tag.viewnext,
        { description = "tag suivant", group = "tag" }),
    awful.key({ modkey, "Shift" }, "Tab", awful.tag.viewprev,
        { description = "tag précédent", group = "tag" }),

    awful.key({}, "XF86AudioRaiseVolume", function()
        awful.spawn("pactl set-sink-volume @DEFAULT_SINK@ +10%") end),
    awful.key({}, "XF86AudioLowerVolume", function()
        awful.spawn("pactl set-sink-volume @DEFAULT_SINK@ -10%") end),
    awful.key({}, "XF86AudioMute", function()
        awful.spawn("pactl set-sink-mute @DEFAULT_SINK@ toggle") end),
    awful.key({}, "XF86AudioMicMute", function()
        awful.spawn("pactl set-source-mute @DEFAULT_SOURCE@ toggle") end)
)
for i = 1, 6 do
    globalkeys = gears.table.join(globalkeys,
        awful.key({ modkey }, "#" .. i + 9, function()
            local t = awful.screen.focused().tags[i]
            if t then t:view_only() end
        end, { description = "tag " .. i, group = "tag" }),
        awful.key({ modkey, "Shift" }, "#" .. i + 9, function()
            if client.focus then
                local t = client.focus.screen.tags[i]
                if t then client.focus:move_to_tag(t) end
            end
        end, { description = "vers tag " .. i, group = "tag" })
    )
end
root.keys(globalkeys)

local clientkeys = gears.table.join(
    awful.key({ modkey }, "q", function(c) c:kill() end,
        { description = "fermer", group = "client" }),
    awful.key({ modkey }, "F11", function(c)
        c.fullscreen = not c.fullscreen; c:raise() end,
        { description = "plein écran", group = "client" }),
    awful.key({ modkey }, "m", function(c)
        c.maximized = not c.maximized; c:raise() end,
        { description = "maximiser", group = "client" }),
    awful.key({ modkey, "Shift" }, "f", function(c)
        c.floating = not c.floating; c:raise() end,
        { description = "flottant", group = "client" }),
    awful.key({ modkey, "Shift" }, "Return", function(c)
        c.floating = not c.floating; c:raise() end,
        { description = "flottant", group = "client" })
)
local clientbuttons = gears.table.join(
    awful.button({}, 1, function(c)
        c:emit_signal("request::activate", "mouse_click", { raise = true }) end),
    awful.button({ modkey }, 1, function(c)
        c:emit_signal("request::activate", "mouse_click", { raise = true })
        awful.mouse.client.move(c) end),
    awful.button({ modkey }, 3, function(c)
        c:emit_signal("request::activate", "mouse_click", { raise = true })
        awful.mouse.client.resize(c) end)
)

-- une fenêtre flottante qui couvre tout l'écran est ramenée à 80% et centrée
local function fit_floating(c)
    if not c.valid or c.fullscreen or c.maximized then return end
    if not (c.floating or awful.layout.get(c.screen) == awful.layout.suit.floating) then return end
    local wa, g = c.screen.workarea, c:geometry()
    if g.width >= wa.width * 0.95 and g.height >= wa.height * 0.95 then
        c:geometry({ width = math.floor(wa.width * 0.8),
                     height = math.floor(wa.height * 0.8) })
        awful.placement.centered(c, { honor_workarea = true })
    end
end
client.connect_signal("property::floating", fit_floating)

awful.rules.rules = {
    { rule = {},
      properties = {
          border_width = beautiful.border_width,
          border_color = beautiful.border_normal,
          focus = awful.client.focus.filter, raise = true,
          keys = clientkeys, buttons = clientbuttons,
          screen = awful.screen.preferred,
          placement = awful.placement.no_overlap + awful.placement.no_offscreen,
          -- les fenêtres suivent le layout à l'ouverture, même si l'appli demande à être maximisée
          maximized = false, maximized_horizontal = false, maximized_vertical = false,
      } },
    { rule_any = { class = { "Pavucontrol", "Lxappearance", "gnome-calculator" } },
      properties = { floating = true } },
    { rule = { class = "Google-chrome" },
      properties = { fullscreen = false },
      callback = function(c)
          -- chrome restaure sa propre taille après le manage
          gears.timer.start_new(0.3, function() fit_floating(c); return false end)
      end },
}

client.connect_signal("manage", function(c)
    if awesome.startup and not c.size_hints.user_position
        and not c.size_hints.program_position then
        awful.placement.no_offscreen(c)
    end
end)
client.connect_signal("focus",   function(c) c.border_color = C.accent end)
client.connect_signal("unfocus", function(c) c.border_color = C.surface0 end)

local function run_once(cmd)
    awful.spawn.with_shell(
        "pgrep -u $USER -fx '" .. cmd .. "' > /dev/null || (" .. cmd .. ")")
end
run_once("picom")

-- L'heure et la date sont déjà sur le bureau (LuminaHUD) : la barre ne les affiche que
-- lorsque des fenêtres recouvrent le bureau, pour ne pas les montrer deux fois.
local function update_clock_visibility()
    mytextclock.visible = #screen.primary.clients > 0
end
local function schedule_clock_visibility()
    gears.timer.delayed_call(update_clock_visibility)
end
for _, signal in ipairs { "manage", "unmanage", "tagged", "untagged", "property::minimized" } do
    client.connect_signal(signal, schedule_clock_visibility)
end
tag.connect_signal("property::selected", schedule_clock_visibility)
schedule_clock_visibility()

-- awesome.restart() (Mod+Shift+r) revient sinon sur le tag 1 :
-- on note le tag affiché de chaque écran à la sortie et on le rouvre au démarrage.
local tag_state = os.getenv("HOME") .. "/.cache/awesome-rice/tags"
awesome.connect_signal("exit", function(restarting)
    if not restarting then return end
    local f = io.open(tag_state, "w")
    if not f then return end
    for s in screen do
        if s.selected_tag then f:write(s.index, " ", s.selected_tag.index, "\n") end
    end
    f:close()
end)
do
    local f = io.open(tag_state)
    if f then
        for line in f:lines() do
            local si, ti = line:match("^(%d+) (%d+)$")
            local s = si and tonumber(si) <= screen.count() and screen[tonumber(si)]
            local t = s and s.tags[tonumber(ti)]
            if t then t:view_only() end
        end
        f:close()
        os.remove(tag_state)
    end
end
-- Relancé à chaque démarrage d'awesome pour suivre le thème du rice (LUMINA_THEME)
awful.spawn.with_shell("~/.config/LuminaHUD/start.sh")
