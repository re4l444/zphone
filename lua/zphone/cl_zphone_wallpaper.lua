-- zphone wallpapers. a vertical gradient with a couple of soft glows, under everything on the screen.
-- the choice is per player (data/zphone_settings.json on your own machine), picked in the Settings app.
-- included from cl_zphone_ui.lua before the UI draws anything.

ZPHONE.Wallpaper = ZPHONE.Wallpaper or {}
local WP = ZPHONE.Wallpaper

WP.Presets = {
	{ id = "dusk", name = "Dusk", top = Color(246, 128, 96), bottom = Color(78, 34, 110), glow = Color(255, 200, 150) },
	{ id = "ocean", name = "Ocean", top = Color(52, 120, 190), bottom = Color(12, 26, 66), glow = Color(140, 210, 255) },
	{ id = "forest", name = "Forest", top = Color(70, 150, 120), bottom = Color(10, 40, 34), glow = Color(170, 240, 200) },
	{ id = "rose", name = "Rose", top = Color(252, 156, 176), bottom = Color(120, 40, 84), glow = Color(255, 220, 230) },
	{ id = "midnight", name = "Midnight", top = Color(44, 44, 80), bottom = Color(6, 6, 14), glow = Color(120, 120, 200) },
}

-- the choice lives in the shared phone settings (cl_zphone_prefs.lua), so it survives restarts with everything else
function WP.Load()
	WP.Choice = ZPHONE.Prefs.Get("wallpaper") or "dusk"
end

function WP.Set(id)
	WP.Choice = id
	ZPHONE.Prefs.Set("wallpaper", id)
end

function WP.Current()
	for _, p in ipairs(WP.Presets) do
		if p.id == WP.Choice then return p end
	end
	return WP.Presets[1]
end

WP.Load()

-- the strip count. more is smoother, fewer is cheaper. the screen is only 1024 tall, 64 is plenty
local STRIPS = 64

-- dim: the lock screen sits a little darker so the clock reads
function WP.Draw(w, h, dim)
	local p = WP.Current()
	local strip = h / STRIPS
	for i = 0, STRIPS - 1 do
		local t = i / (STRIPS - 1)
		local col = Color(
			math.floor(Lerp(t, p.top.r, p.bottom.r)),
			math.floor(Lerp(t, p.top.g, p.bottom.g)),
			math.floor(Lerp(t, p.top.b, p.bottom.b))
		)
		draw.RoundedBox(0, 0, i * strip, w, strip + 1, col)
	end

	-- two soft glows. a rounded box with the radius at exactly half its size is a circle
	local s1 = w * 1.2
	draw.RoundedBox(s1 / 2, -w * 0.3, h * 0.18, s1, s1, Color(p.glow.r, p.glow.g, p.glow.b, 26))
	local s2 = w * 0.9
	draw.RoundedBox(s2 / 2, w * 0.25, h * 0.62, s2, s2, Color(p.glow.r, p.glow.g, p.glow.b, 18))

	if dim then
		draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 90))
	end
end
