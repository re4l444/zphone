local UI = ZPHONE.UI
local T = UI.Theme
local C = ZPHONE.Config
local P = ZPHONE.Prefs
ZPHONE.AppDraw = ZPHONE.AppDraw or {}

UI.SettingsTab = UI.SettingsTab or "display"

local TAB_IDS = { "display", "sounds", "battery", "wallpaper", "about", "blocked" }

local function toggleRow(y, w, label, sub, key)
	local on = P.Get(key) and true or false
	local function flip() P.Set(key, not on) end
	UI.Card(UI.Pad, y, w - UI.Pad * 2, 108, flip)
	UI.Text(UI.Pad + 28, y + 40, label, "ZPhone_Body", T.text)
	UI.Text(UI.Pad + 28, y + 80, sub, "ZPhone_Small", T.faint)
	UI.Pill(w - UI.Pad - 150, y + 26, 126, 56, on and "on" or "off", on and T.ok or T.card, T.text, flip)
	return y + 120
end

local function drawDisplay(w, h, y)
	local cw = w - UI.Pad * 2
	local b = P.Get("brightness") or 1

	UI.Card(UI.Pad, y, cw, 150)
	UI.Text(UI.Pad + 28, y + 42, "brightness", "ZPhone_Body", T.text)
	UI.Text(UI.Pad + 28, y + 108, math.floor(b * 100 + 0.5) .. "%", "ZPhone_Small", T.faint)
	local bw = 110
	UI.Pill(w - UI.Pad - 28 - bw * 2 - 12, y + 40, bw, 70, "-", T.cardHi, T.text, function()
		P.Set("brightness", math.Round(math.max(0.3, b - 0.1), 1))
	end, "ZPhone_Body")
	UI.Pill(w - UI.Pad - 28 - bw, y + 40, bw, 70, "+", T.cardHi, T.text, function()
		P.Set("brightness", math.Round(math.min(1, b + 0.1), 1))
	end, "ZPhone_Body")
	y = y + 170

	local pw = (ZPHONE.State and ZPHONE.State.power) or {}
	UI.Card(UI.Pad, y, cw, 130)
	UI.Text(UI.Pad + 28, y + 42, "screen", "ZPhone_Body", T.text)
	if pw.cracked then
		UI.Text(UI.Pad + 28, y + 96, "Your phone detected external damage.", "ZPhone_Small", T.danger)
	else
		UI.Text(UI.Pad + 28, y + 96, "No external damage detected", "ZPhone_Small", T.faint)
	end
end

local function drawSounds(w, h, y)
	y = toggleRow(y, w, "Silent mode", "Do not disturb mode.", "silent")
	y = toggleRow(y, w, "Vibrate when silent", "phone will vibrate in Silent mode.", "vibrate")
	toggleRow(y, w, "keyboard clicks", "a tap on every key and button", "keyClicks")
end

local function drawBattery(w, h, y)
	local cw = w - UI.Pad * 2
	local batt = (ZPHONE.State and ZPHONE.State.power and ZPHONE.State.power.batt) or 100
	local word = batt <= 0 and "dead" or batt <= 10 and "critical" or batt <= 20 and "low" or batt <= 50 and "okay" or "good"
	local col = batt > 20 and T.ok or (batt > 10 and Color(232, 170, 60) or T.danger)

	UI.Card(UI.Pad, y, cw, 180)
	UI.Text(UI.Pad + 28, y + 52, batt .. "%", "ZPhone_Title", T.text)
	UI.Text(UI.Pad + 28, y + 110, word, "ZPhone_Small", T.dim)
	local bx, by, bw = UI.Pad + 28, y + 140, cw - 56
	draw.RoundedBox(8, bx, by, bw, 16, Color(60, 60, 70))
	if batt > 0 then
		draw.RoundedBox(8, bx, by, bw * batt / 100, 16, col)
	end

	y = y + 200
	UI.Card(UI.Pad, y, cw, 170)
	local lines = UI.Wrap("it drains while you carry it, and faster while it's out. an admin can charge it, so be nice to them.", "ZPhone_Small", cw - 56)
	for i, line in ipairs(lines) do
		UI.Text(UI.Pad + 28, y + 40 + (i - 1) * 32, line, "ZPhone_Small", T.dim)
	end
end

local function drawWallpaper(w, h, y)
	for _, p in ipairs(ZPHONE.Wallpaper.Presets) do
		local id = p.id
		local selected = ZPHONE.Wallpaper.Choice == id
		UI.Card(UI.Pad, y, w - UI.Pad * 2, 100, function() ZPHONE.Wallpaper.Set(id) end)
		local sx, sy, sw, sh = UI.Pad + 16, y + 14, 84, 72
		local strips = 16
		for i = 0, strips - 1 do
			local t = i / (strips - 1)
			draw.RoundedBox(0, sx, sy + i * sh / strips, sw, sh / strips + 1, Color(
				math.floor(Lerp(t, p.top.r, p.bottom.r)),
				math.floor(Lerp(t, p.top.g, p.bottom.g)),
				math.floor(Lerp(t, p.top.b, p.bottom.b))
			))
		end
		if selected then

			surface.SetDrawColor(255, 255, 255, 255)
			for k = 0, 2 do
				surface.DrawOutlinedRect(sx - 3 + k, sy - 3 + k, sw + 6 - k * 2, sh + 6 - k * 2)
			end
		end

		UI.Text(UI.Pad + 130, y + 36, p.name, "ZPhone_Body", T.text)
		UI.Text(UI.Pad + 130, y + 72, selected and "in use" or "tap to use", "ZPhone_Small", selected and T.ok or T.faint)
		y = y + 112
	end
end

local function drawAbout(w, h, y)
	local cw = w - UI.Pad * 2
	local st = ZPHONE.State or {}
	local owner = (st.char and st.char ~= "") and st.char or LocalPlayer():Nick()

	local rows = { { "owner", owner }, { "model", "iPhone 13 Pro" } }
	for _, r in ipairs(rows) do
		UI.Card(UI.Pad, y, cw, 96)
		UI.Text(UI.Pad + 28, y + 30, r[1], "ZPhone_Small", T.faint)
		UI.Text(UI.Pad + 28, y + 66, UI.Clip(tostring(r[2]), "ZPhone_Body", cw - 56), "ZPhone_Body", T.text)
		y = y + 108
	end

	UI.Text(UI.Pad + 4, y + 10, "numbers", "ZPhone_Small", T.faint)
	y = y + 40
	if not st.accounts or #st.accounts == 0 then
		UI.Text(UI.Pad + 28, y + 30, "none yet. an admin has to hand you one", "ZPhone_Small", T.faint)
		return
	end
	for i, a in ipairs(st.accounts) do
		if i > 4 then break end
		UI.Card(UI.Pad, y, cw, 96)
		UI.Text(UI.Pad + 28, y + 30, UI.Clip(a.name or "", "ZPhone_Small", cw - 180), "ZPhone_Small", T.faint)
		UI.Text(UI.Pad + 28, y + 66, C.FormatNumber(a.number), "ZPhone_Body", T.text)
		if st.active == a.number then
			UI.Text(w - UI.Pad - 28, y + 66, "in use", "ZPhone_Small", T.ok, TEXT_ALIGN_RIGHT)
		end
		y = y + 108
	end
end

local function drawBlocked(w, h, y)
	local nums = {}
	for num in pairs(ZPHONE.State.blocked or {}) do nums[#nums + 1] = num end
	table.sort(nums)

	if #nums == 0 then
		UI.Text(w / 2, y + 60, "nobody's blocked. you're very approachable.", "ZPhone_Small", T.faint, TEXT_ALIGN_CENTER)
		return
	end

	for i, num in ipairs(nums) do
		if i > 7 then break end
		local n = num
		UI.Card(UI.Pad, y, w - UI.Pad * 2, 88)
		UI.Text(UI.Pad + 26, y + 44, UI.Clip(UI.NameOf(n), "ZPhone_Body", w - 230), "ZPhone_Body", T.text)
		UI.Pill(w - UI.Pad - 150, y + 16, 126, 56, "unblock", T.cardHi, T.text, function()
			UI.Act("block", { number = n, on = false })
		end)
		y = y + 100
	end
end

ZPHONE.AppDraw.settings = function(w, h)
	UI.Title(w, "Settings")

	local tab = UI.SettingsTab
	local tw = (w - UI.Pad * 2 - 24) / 3
	local ty = UI.ContentY
	for i, id in ipairs(TAB_IDS) do
		local col = (i - 1) % 3
		local row = math.floor((i - 1) / 3)
		local tabId = id
		UI.Pill(UI.Pad + col * (tw + 12), ty + row * 60, tw, 52, id, tab == id and T.accent or T.card, T.text, function()
			UI.SettingsTab = tabId
		end)
	end

	local y = ty + 136
	if tab == "sounds" then
		drawSounds(w, h, y)
	elseif tab == "battery" then
		drawBattery(w, h, y)
	elseif tab == "wallpaper" then
		drawWallpaper(w, h, y)
	elseif tab == "about" then
		drawAbout(w, h, y)
	elseif tab == "blocked" then
		drawBlocked(w, h, y)
	else
		drawDisplay(w, h, y)
	end
end

local crackPaths

local function buildCrack(w, h)
	local ox, oy = w * 0.64, h * 0.36 -- the impact point, a bit off-centre like a real drop
	local paths = {}
	local rays = 8
	for r = 1, rays do
		local ang = (r / rays) * math.pi * 2 + util.SharedRandom("zphone_crack_a", -0.15, 0.15, r)
		local len = w * (0.55 + util.SharedRandom("zphone_crack_l", 0, 0.7, r))
		local pts = { { ox, oy } }
		for s = 1, 6 do
			local t = s / 6
			local wob = util.SharedRandom("zphone_crack_w", -10, 10, r * 10 + s)
			pts[#pts + 1] = {
				ox + math.cos(ang) * len * t - math.sin(ang) * wob,
				oy + math.sin(ang) * len * t + math.cos(ang) * wob,
			}
		end
		paths[#paths + 1] = pts
		local bp = pts[4]
		local side = (r % 2 == 0) and 1 or -1
		local bang = ang + side * util.SharedRandom("zphone_crack_b", 0.5, 0.9, r)
		local blen = w * util.SharedRandom("zphone_crack_bl", 0.12, 0.24, r)
		paths[#paths + 1] = { bp, { bp[1] + math.cos(bang) * blen, bp[2] + math.sin(bang) * blen } }
	end
	return paths
end

function UI.DrawCrack(w, h)
	local pw = ZPHONE.State and ZPHONE.State.power
	if not (pw and pw.cracked) then return end

	crackPaths = crackPaths or buildCrack(w, h)
	for _, pts in ipairs(crackPaths) do
		for i = 2, #pts do
			local a, b = pts[i - 1], pts[i]
			surface.SetDrawColor(0, 0, 0, 120)
			surface.DrawLine(a[1] + 1, a[2] + 1, b[1] + 1, b[2] + 1)
			surface.SetDrawColor(255, 255, 255, 190)
			surface.DrawLine(a[1], a[2], b[1], b[2])
		end
	end
end

function UI.DrawOverlays(w, h)
	UI.DrawCrack(w, h)

	local b = P.Get("brightness") or 1
	if b < 1 then
		draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, math.floor((1 - b) * 230)))
	end
end
