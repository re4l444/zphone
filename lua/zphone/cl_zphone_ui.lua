-- zphone client ui core: render target, tap mapping, navigation, transitions, lock/home, keyboard host, banner, net.
-- the apps live in cl_zphone_apps.lua (included at the bottom). the look comes from UI.Theme and the helpers here,
-- so apps don't hardcode colours or margins. dev1: the screen is 512x1024 and i spent 40 minutes on a font size. dev2: it's a phone, not a billboard

ZPHONE.UI = ZPHONE.UI or {}
local UI = ZPHONE.UI

include("zphone/cl_zphone_anim.lua")
include("zphone/cl_zphone_keyboard.lua")
include("zphone/cl_zphone_prefs.lua")
include("zphone/cl_zphone_wallpaper.lua")

local A = ZPHONE.Anim

UI.W = ZPHONE.Config.RTWidth
UI.H = ZPHONE.Config.RTHeight
UI.Screen = "lock"
UI.Buttons = {}
UI.Unread = 0
UI.LastInput = CurTime()
UI.Keyboard = nil      -- { text, max, label, onChange, onDone, layer, shift }
UI.Thread = nil        -- phone number of the open conversation
UI.Drafts = UI.Drafts or {}
UI.Typing = UI.Typing or {}    -- thread -> { untilTime, who }, the dots shown while the other side types
UI.Cursor = nil        -- {x,y} in rt pixels, or nil if the mouse isn't on the screen
UI.Toast = nil         -- { text, untilTime } - a status line, not a popup
UI.Banner = nil        -- { text, hideAt, out } - the notification strip that drops from the top
UI.Flash = nil         -- last tapped button rect, for the tap flash
UI.Origin = nil        -- where the app being opened grows from, in rt pixels
UI.Page = UI.Page or {}
UI.AutoLockTime = 45

-- layout. everything is measured from these, so the screen stays consistent
UI.Pad = 28          -- side margin
UI.Radius = 24       -- cards
UI.TopH = 92         -- status bar + title strip
UI.ContentY = 104    -- where app content starts
UI.BarH = 96         -- the home bar at the bottom
UI.TypeH = 120       -- the taller strip that replaces it while the real keyboard is typing. shows the live text

UI.Theme = {
	bg = Color(12, 12, 16),
	bar = Color(20, 20, 26),
	card = Color(32, 32, 42),
	cardHi = Color(48, 48, 62),
	field = Color(20, 20, 28),
	text = Color(244, 244, 248),
	dim = Color(154, 154, 168),
	faint = Color(100, 100, 116),
	accent = Color(84, 152, 255),
	ok = Color(66, 196, 118),
	danger = Color(226, 80, 80),
	warn = Color(242, 186, 62),
}
local T = UI.Theme

-- ZPHONE.State is the server's truth, refreshed every ZPhoneSync
ZPHONE.State = ZPHONE.State or { accounts = {}, messages = {}, contacts = {}, spamNames = {}, blocked = {}, notes = "", active = nil, call = nil }

-- screen geometry guess. real iphone is ~71.5 x 146.7 mm, which is ~3.8 x 7.8 hammer units. your model may be scaled. tune it
ZPHONE.Tuning = ZPHONE.Tuning or {}
ZPHONE.Tuning.screen = ZPHONE.Tuning.screen or { pos = Vector(0, 0, 0), ang = Angle(0, 0, 0), w = 3.8, h = 7.8 }

-- ========== fonts ==========

surface.CreateFont("ZPhone_Clock", { font = "Arial", size = 150, weight = 300, antialias = true })
surface.CreateFont("ZPhone_Big", { font = "Arial", size = 76, weight = 300, antialias = true })
surface.CreateFont("ZPhone_Title", { font = "Arial", size = 44, weight = 700, antialias = true })
surface.CreateFont("ZPhone_Body", { font = "Arial", size = 32, weight = 500, antialias = true })
surface.CreateFont("ZPhone_Small", { font = "Arial", size = 24, weight = 500, antialias = true })
surface.CreateFont("ZPhone_Tiny", { font = "Arial", size = 20, weight = 600, antialias = true })
surface.CreateFont("ZPhone_Key", { font = "Arial", size = 36, weight = 600, antialias = true })

-- ========== render target + materials. created once, survives reloads by name check ==========

if not ZPHONE.RT then
	ZPHONE.RT = GetRenderTarget("zphone_screen_rt", UI.W, UI.H)
end
if not ZPHONE.ScreenMatLocal then
	ZPHONE.ScreenMatLocal = CreateMaterial("zphone_screen_local", "UnlitGeneric", {
		["$basetexture"] = ZPHONE.RT:GetName(),
	})
end
if not ZPHONE.ScreenMatIdle then
	ZPHONE.ScreenMatIdle = CreateMaterial("zphone_screen_idle", "UnlitGeneric", {
		["$basetexture"] = "models/debug/debugwhite",
		["$color"] = "[0.04 0.04 0.06]",
	})
end

-- ========== screen orientation ==========
-- the model's UVs don't line up with the render target, so the tuner lets you rotate 90 and/or flip each axis.
-- the choice lives in its OWN file (zphone_screen_orient.json), written the moment you pick it, so it can't be
-- lost to a missing "save" press or overwritten by an older tuning file. it's also reapplied every frame, see renderScreen.

ZPHONE.DefaultOrient = { rot = false, fx = false, fy = true }
ZPHONE.OrientFile = "zphone_screen_orient.json"

ZPHONE.OrientOptions = {
	{ label = "none", rot = false, fx = false, fy = false },
	{ label = "flip X", rot = false, fx = true, fy = false },
	{ label = "flip Y", rot = false, fx = false, fy = true },
	{ label = "flip X + Y", rot = false, fx = true, fy = true },
	{ label = "rotate 90", rot = true, fx = false, fy = false },
	{ label = "rotate 90 + flip X", rot = true, fx = true, fy = false },
	{ label = "rotate 90 + flip Y", rot = true, fx = false, fy = true },
	{ label = "rotate 90 + flip X + Y", rot = true, fx = true, fy = true },
}

ZPHONE.Tuning.orient = ZPHONE.Tuning.orient or table.Copy(ZPHONE.DefaultOrient)

-- builds the uv transform: rotate about the centre, then flip. stays centred on .5 .5
function ZPHONE.ApplyScreenOrient()
	if not ZPHONE.ScreenMatLocal then return end
	local o = ZPHONE.Tuning.orient

	-- 2x2 matrix, starts as identity
	local a, b, c, d = 1, 0, 0, 1
	if o.rot then
		a, b, c, d = 0, -1, 1, 0 -- 90 degrees
	end
	local sx = o.fx and -1 or 1
	local sy = o.fy and -1 or 1
	a, b = sx * a, sx * b
	c, d = sy * c, sy * d

	local m = Matrix()
	m:SetField(1, 1, a)
	m:SetField(1, 2, b)
	m:SetField(2, 1, c)
	m:SetField(2, 2, d)
	-- keep the centre fixed: translate by centre - A*centre
	m:SetField(1, 4, 0.5 - (a * 0.5 + b * 0.5))
	m:SetField(2, 4, 0.5 - (c * 0.5 + d * 0.5))

	ZPHONE.ScreenMatLocal:SetMatrix("$basetexturetransform", m)
end

-- set, apply and save in one go. save = false is for loading, so we don't write the file back over itself
function ZPHONE.SetOrient(o, save)
	ZPHONE.Tuning.orient = {
		rot = o.rot and true or false,
		fx = o.fx and true or false,
		fy = o.fy and true or false,
	}
	ZPHONE.ApplyScreenOrient()
	if save ~= false then
		file.Write(ZPHONE.OrientFile, util.TableToJSON(ZPHONE.Tuning.orient, true))
	end
end

function ZPHONE.LoadOrient()
	local raw = file.Read(ZPHONE.OrientFile, "DATA")
	local t = raw and util.JSONToTable(raw)
	if istable(t) then
		ZPHONE.SetOrient(t, false)
	else
		ZPHONE.SetOrient(ZPHONE.DefaultOrient, false)
	end
end
ZPHONE.LoadOrient()

-- ========== helpers ==========

-- register a tappable region. registered during draw, hit-tested on tap. later buttons are on top
function UI.Btn(x, y, w, h, fn)
	UI.Buttons[#UI.Buttons + 1] = { x = x, y = y, w = w, h = h, fn = fn }
end

function UI.HitTest(px, py)
	for i = #UI.Buttons, 1, -1 do
		local b = UI.Buttons[i]
		if px >= b.x and py >= b.y and px <= b.x + b.w and py <= b.y + b.h then
			return b
		end
	end
end

-- send an action to the server. payload is a table, server does the validating
function UI.Act(action, data)
	net.Start("ZPhoneAction")
		net.WriteString(action)
		net.WriteTable(data or {})
	net.SendToServer()
end

-- true while a screen transition is running. button rects don't follow the animation, so taps are ignored until it settles
function UI.Busy()
	return A.IsRunning("unlock") or A.IsRunning("lock") or A.IsRunning("appOpen") or A.IsRunning("call")
end

-- the y where app content has to stop: the top of the home bar normally, the top of the keyboard while it's open
function UI.BottomEdge(h)
	-- typing with the real keyboard: content stops above the typing strip, which is taller than the home bar
	if UI.Keyboard and UI.Keyboard.physical then return h - UI.TypeH end
	if UI.Keyboard then return ZPHONE.Keyboard.Top(h, A.Get("kb")) end
	return h - UI.BarH
end

-- ========== drawing helpers ==========
-- y on Text is the vertical centre of the line. x is the left edge, or the right edge with TEXT_ALIGN_RIGHT

function UI.Card(x, y, w, h, fn, col)
	draw.RoundedBox(UI.Radius, x, y, w, h, col or T.card)
	if fn then UI.Btn(x, y, w, h, fn) end
end

function UI.Pill(x, y, w, h, label, col, tcol, fn, font)
	draw.RoundedBox(h / 2, x, y, w, h, col or T.card)
	draw.SimpleText(label, font or "ZPhone_Small", x + w / 2, y + h / 2, tcol or T.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	if fn then UI.Btn(x, y, w, h, fn) end
end

function UI.Text(x, y, str, font, col, align)
	draw.SimpleText(str, font or "ZPhone_Body", x, y, col or T.text, align or TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

-- trims the end of a string with "..." so it fits maxW
function UI.Clip(str, font, maxW)
	str = tostring(str or "")
	surface.SetFont(font)
	if surface.GetTextSize(str) <= maxW then return str end
	while #str > 1 and surface.GetTextSize(str .. "...") > maxW do
		str = string.sub(str, 1, #str - 1)
	end
	return str .. "..."
end

-- trims the start of a string so the newest characters (the end) stay visible
function UI.ClipTail(str, font, maxW)
	str = tostring(str or "")
	surface.SetFont(font)
	while #str > 1 and surface.GetTextSize(str) > maxW do
		str = string.sub(str, 2)
	end
	return str
end

-- the title strip at the top of every app. right = optional { label, fn, col } chip, e.g. "back"
function UI.Title(w, text, right)
	local room = w - UI.Pad * 2 - (right and 150 or 0)
	draw.SimpleText(UI.Clip(text, "ZPhone_Title", room), "ZPhone_Title", UI.Pad, UI.TopH - 14, T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
	if right then
		UI.Pill(w - UI.Pad - 124, 46, 124, 46, right.label, right.col or T.cardHi, T.text, right.fn)
	end
end

-- what to call a number: your contact name, a spam sender, one of your own lines, or the formatted digits
function UI.NameOf(num)
	num = tostring(num or "")
	local S = ZPHONE.State
	if S.contacts and S.contacts[num] then return S.contacts[num] end
	if S.groups and S.groups[num] then return S.groups[num].name end
	if S.spamNames and S.spamNames[num] then return S.spamNames[num] end
	if S.alertNumber and num == S.alertNumber then return S.alertName or "city alerts" end
	for _, a in ipairs(S.accounts or {}) do
		if a.number == num then return a.name .. " (you)" end
	end
	return ZPHONE.Config.FormatNumber(tonumber(num) or 0)
end

-- "now", "3m", "2h", "4d" for a unix time
function UI.Ago(t)
	local d = math.max(0, os.time() - (t or 0))
	if d < 60 then return "now" end
	if d < 3600 then return math.floor(d / 60) .. "m" end
	if d < 86400 then return math.floor(d / 3600) .. "h" end
	return math.floor(d / 86400) .. "d"
end

-- ========== navigation ==========

-- navigate. origin is optional {x, y} in rt pixels: the icon an app is opening from
function UI.Go(screen, origin)
	local prev = UI.Screen
	UI.Keyboard = nil
	UI.LastInput = CurTime()
	if screen ~= "messages" then
		UI.Thread = nil
		UI.GroupNew = nil
	end
	if screen == "messages" then UI.Unread = 0 end
	if screen == prev then return end
	-- opening delivery always starts on the top-level menu, not wherever you left the sub-menu
	if screen == "delivery" then UI.DeliveryCat = nil end

	UI.Screen = screen
	if prev == "lock" and screen == "home" then
		A.Play("unlock")
	elseif screen == "lock" then
		A.Play("lock")
	elseif prev == "home" then
		UI.Origin = origin
		A.Play("appOpen")
	else
		-- app -> home and app -> app: a quick settle is enough
		A.Play("homeIn")
	end
end

function UI.Home()
	UI.Go("home")
end

function UI.Lock()
	UI.Go("lock")
end

function UI.Say(text, dur)
	UI.Toast = { text = text, untilTime = CurTime() + (dur or 2.5) }
	A.Play("toast")
end

-- the notification strip. no popup, a short line that drops in from the top and goes away on its own. tap it to open messages
function UI.Notify(text)
	UI.Banner = { text = text, hideAt = CurTime() + 2.8, out = false }
	A.Play("notifyIn")
end

function UI.PlaySound(key, lvl, pitch, vol)
	local ply = LocalPlayer()
	if not IsValid(ply) then return end

	-- silent mode: the ringer and the notification buzz go quiet. vibrate, if it's on, does the job instead
	if ZPHONE.Prefs.Get("silent") and (key == "ring" or key == "buzz") then
		if ZPHONE.Prefs.Get("vibrate") then ZPHONE.Vibrate() end
		return
	end
	if key == "tap" and not ZPHONE.Prefs.Get("keyClicks") then return end

	ply:EmitSound(ZPHONE.Config.Sounds[key], lvl or 45, pitch or 100, vol or 0.5)
end

-- wrap text to a pixel width. returns a table of lines
function UI.Wrap(text, font, maxw)
	surface.SetFont(font)
	local lines, line = {}, ""
	for word in string.gmatch(tostring(text or ""), "%S+") do
		local test = (line == "") and word or (line .. " " .. word)
		if surface.GetTextSize(test) > maxw and line ~= "" then
			lines[#lines + 1] = line
			line = word
		else
			line = test
		end
	end
	if line ~= "" then lines[#lines + 1] = line end
	return lines
end

-- ========== keyboard ==========
-- opts: text, max, label ("number" gives the numpad), onChange(text), onDone(text)

function UI.OpenKeyboard(opts)
	UI.Keyboard = {
		text = opts.text or "",
		max = opts.max or 200,
		onChange = opts.onChange,
		onDone = opts.onDone,
		label = opts.label or "",
		-- physical = true means the real keyboard types into it, and the on-screen keys stay hidden
		physical = opts.physical ~= false,
	}
	UI.LastInput = CurTime()
	A.Play("kb")
end

function UI.CloseKeyboard()
	UI.Keyboard = nil
end

-- ========== shared chrome ==========

local function drawStatusBar(w)
	-- nudges from the tuner's statusbar group, in screen pixels
	local sb = (ZPHONE.Tuning and ZPHONE.Tuning.statusbar) or { time = { x = 0, y = 0 }, battery = { x = 0, y = 0 } }

	draw.SimpleText(os.date("%H:%M"), "ZPhone_Small", UI.Pad + sb.time.x, 30 + sb.time.y, T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	-- battery, top right. the fill and its colour follow the percentage
	local batt = (ZPHONE.State and ZPHONE.State.power and ZPHONE.State.power.batt) or 100
	local bx, by, bw, bh = w - UI.Pad - 62 + sb.battery.x, 18 + sb.battery.y, 54, 26
	local col = batt > 20 and T.ok or (batt > 10 and Color(232, 170, 60) or T.danger)
	draw.RoundedBox(7, bx, by, bw, bh, Color(60, 60, 70))
	draw.RoundedBox(4, bx + 3, by + 3, math.max(0, (bw - 6) * batt / 100), bh - 6, col)
	draw.RoundedBox(2, bx + bw + 2, by + 8, 4, 10, Color(120, 120, 134))
	draw.SimpleText(batt .. "%", "ZPhone_Tiny", bx - 8, 30, T.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	if UI.Unread > 0 then
		draw.SimpleText(UI.Unread .. " new", "ZPhone_Small", bx - 84, 30, T.accent, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
end

-- the bar at the bottom of every app. the indicator is the way home. tapping anywhere on the bar does the same
local function drawBackBar(w, h)
	draw.RoundedBox(0, 0, h - UI.BarH, w, UI.BarH, T.bar)
	draw.RoundedBox(5, w / 2 - 70, h - 50, 140, 8, Color(120, 120, 134))
	UI.Btn(0, h - UI.BarH, w, UI.BarH, function() UI.Home() end)
end

-- the call strip. shows at the top of every screen while you're on a call, so you can always hang up
local function drawCallOverlay(w, h)
	local call = ZPHONE.State.call
	if not call then return end

	if call.state == "ringing" and call.incoming then
		-- incoming. this is the one overlay that takes over the whole screen
		draw.RoundedBox(0, 0, 0, w, h, Color(10, 10, 14, 245))
		draw.SimpleText("incoming", "ZPhone_Small", w / 2, 220, T.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(UI.Clip(call.peerName or "unknown", "ZPhone_Title", w - UI.Pad * 2), "ZPhone_Title", w / 2, 280, T.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(call.kind == "text" and "text call" or "voice call", "ZPhone_Small", w / 2, 330, T.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		local bw = (w - UI.Pad * 2 - 24) / 2
		UI.Pill(UI.Pad, h - 300, bw, 110, "decline", T.danger, T.text, function() UI.Act("calldecline", { id = call.id }) end, "ZPhone_Body")
		UI.Pill(UI.Pad + bw + 24, h - 300, bw, 110, "accept", T.ok, T.text, function() UI.Act("callaccept", { id = call.id }) end, "ZPhone_Body")
		return
	end

	if call.state == "active" then
		-- top strip, you're on a call, here's the hang up
		draw.RoundedBox(0, 0, 0, w, 88, Color(30, 90, 52))
		local label = (call.kind == "text" and "texting " or "on call with ") .. (call.peerName or "")
		draw.SimpleText(UI.Clip(label, "ZPhone_Small", w - 240), "ZPhone_Small", UI.Pad, 44, T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		UI.Pill(w - 196, 18, 168, 52, "hang up", T.danger, T.text, function() UI.Act("callhangup", { id = call.id }) end)
	end
end

-- ========== lock + home ==========

local function drawLock(w, h)
	drawStatusBar(w)
	draw.SimpleText(os.date("%H:%M"), "ZPhone_Clock", w / 2, 280, T.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(os.date("%A, %d %B"), "ZPhone_Body", w / 2, 390, T.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	if UI.Unread > 0 then
		local label = UI.Unread .. " new message" .. (UI.Unread == 1 and "" or "s")
		UI.Pill(w / 2 - 140, 450, 280, 60, label, T.cardHi, T.text)
	end

	draw.SimpleText("tap to unlock", "ZPhone_Small", w / 2, h - 150, T.faint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	-- the whole screen is the unlock button. yes, really. it's a phone, not a bank
	UI.Btn(0, 0, w, h, function()
		UI.PlaySound("unlock", 40, 100, 0.4)
		UI.Go("home")
	end)
end

local GRID_COLS = 4
local ICON = 100
local ROW_STEP = 150

local function drawHome(w, h)
	drawStatusBar(w)

	-- the grid: 4 columns, each cell centred in its own slot, so nothing can run off the sides
	local colW = (w - UI.Pad * 2) / GRID_COLS
	local y0 = UI.TopH + 30

	for i, app in ipairs(ZPHONE.Config.Apps) do
		local col = (i - 1) % GRID_COLS
		local row = math.floor((i - 1) / GRID_COLS)
		local cx = UI.Pad + (col + 0.5) * colW
		local x, y = cx - ICON / 2, y0 + row * ROW_STEP

		draw.RoundedBox(26, x, y, ICON, ICON, ZPHONE.AppColor(app.id))
		-- a faint highlight on the top half, so the icons read as objects rather than flat squares
		draw.RoundedBox(26, x + 3, y + 3, ICON - 6, ICON / 2 - 4, Color(255, 255, 255, 14))
		draw.SimpleText(string.sub(app.name, 1, 1), "ZPhone_Title", cx, y + ICON / 2, T.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(app.name, "ZPhone_Tiny", cx, y + ICON + 20, T.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		if app.id == "messages" and UI.Unread > 0 then
			draw.RoundedBox(12, x + ICON - 16, y - 10, 34, 30, T.danger)
			draw.SimpleText(UI.Unread, "ZPhone_Tiny", x + ICON - 3, y + 5, T.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		local id = app.id
		local origin = { x = cx, y = y + ICON / 2 }
		UI.Btn(cx - colW / 2, y - 6, colW, ICON + 56, function() UI.Go(id, origin) end)
	end

	-- a small summary card between the grid and the lock button
	local cy = y0 + 3 * ROW_STEP + 8
	UI.Card(UI.Pad, cy, w - UI.Pad * 2, 130, nil, T.card)
	draw.SimpleText(os.date("%A"), "ZPhone_Body", UI.Pad + 28, cy + 40, T.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText(os.date("%d %B %Y"), "ZPhone_Small", UI.Pad + 28, cy + 84, T.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	local summary = UI.Unread > 0 and (UI.Unread .. " unread") or "all quiet"
	draw.SimpleText(summary, "ZPhone_Small", w - UI.Pad - 28, cy + 65, UI.Unread > 0 and T.accent or T.faint, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	UI.Pill(w / 2 - 90, h - UI.BarH - 86, 180, 56, "lock", T.cardHi, T.text, function() UI.Lock() end)
end

-- an app screen: status bar, the app itself, the home bar
local function drawApp(scr, w, h)
	drawStatusBar(w)
	local fn = ZPHONE.AppDraw and ZPHONE.AppDraw[scr]
	if fn then
		fn(w, h)
	else
		UI.Go("home")
	end
	drawBackBar(w, h)
end

-- ========== banner ==========
-- drawn last, so it sits above everything and gets first pick of taps

local function drawBanner(w, h)
	local b = UI.Banner
	if not b then return end

	local v = A.Get("notifyIn")
	if CurTime() >= b.hideAt then
		if not b.out then
			A.Play("notifyOut")
			b.out = true
		end
		local o = A.Get("notifyOut")
		if not A.IsRunning("notifyOut") and o >= 1 then
			UI.Banner = nil
			return
		end
		v = 1 - o
	end

	local y = -100 + 118 * v
	draw.RoundedBox(24, UI.Pad, y, w - UI.Pad * 2, 84, Color(38, 38, 50, 245))
	draw.SimpleText(UI.Clip(b.text, "ZPhone_Body", w - UI.Pad * 2 - 48), "ZPhone_Body", w / 2, y + 42, T.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	UI.Btn(UI.Pad, y, w - UI.Pad * 2, 84, function()
		UI.Banner = nil
		UI.Go("messages")
	end)
end

-- ========== draw entry point ==========

function UI.Draw(w, h)
	UI.Buttons = {}

	-- a dead battery turns the screen off. nothing answers and nothing opens until an admin charges it
	local pw = ZPHONE.State and ZPHONE.State.power
	if pw and (pw.batt or 1) <= 0 then
		draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0))
		draw.SimpleText("battery dead", "ZPhone_Body", w / 2, h / 2 - 24, T.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText("ask an admin to charge it", "ZPhone_Small", w / 2, h / 2 + 24, T.faint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		return
	end
	local cx, cy = w / 2, h / 2

	local scr = UI.Screen
	ZPHONE.Wallpaper.Draw(w, h, scr == "lock")
	if A.IsRunning("unlock") then
		-- lock slides up and fades, home rises in from below
		local v = A.Get("unlock")
		A.Layer(cx, cy, 1, 0, (1 - v) * h, 1, function() drawHome(w, h) end)
		A.Layer(cx, cy, 1, 0, -v * h, 1 - v, function() drawLock(w, h) end)
	elseif A.IsRunning("lock") then
		-- home fades out under the lock screen, which settles in
		local v = A.Get("lock")
		A.Layer(cx, cy, 1, 0, 0, 1 - v, function() drawHome(w, h) end)
		A.Layer(cx, cy, 0.96 + 0.04 * v, 0, 0, v, function() drawLock(w, h) end)
	elseif A.IsRunning("appOpen") then
		-- the app grows out of the icon it was opened from
		local v = A.Get("appOpen")
		local o = UI.Origin or { x = cx, y = cy }
		A.Layer(cx, cy, 1, 0, 0, 1 - v, function() drawHome(w, h) end)
		A.Layer(o.x, o.y, 0.3 + 0.7 * v, 0, 0, v, function() drawApp(scr, w, h) end)
	elseif A.IsRunning("homeIn") then
		local v = A.Get("homeIn")
		A.Layer(cx, cy, 0.94 + 0.06 * v, 0, 0, v, function()
			if scr == "home" then drawHome(w, h) else drawApp(scr, w, h) end
		end)
	else
		if scr == "lock" then
			drawLock(w, h)
		elseif scr == "home" then
			drawHome(w, h)
		else
			drawApp(scr, w, h)
		end
	end

	if UI.Keyboard and UI.Keyboard.physical then
		ZPHONE.Typing.DrawBar(w, h)
	elseif UI.Keyboard then
		ZPHONE.Keyboard.Draw(w, h, A.Get("kb"))
	end

	-- the call overlay. an incoming call slides up from the bottom, everything else is static
	local call = ZPHONE.State.call
	if call and call.incoming and call.state == "ringing" then
		if UI.CallAnimId ~= call.id then
			UI.CallAnimId = call.id
			A.Play("call")
		end
		local v = A.Get("call")
		A.Layer(cx, cy, 1, 0, (1 - v) * h, 1, function() drawCallOverlay(w, h) end)
	else
		drawCallOverlay(w, h)
	end

	-- status line for errors and small confirmations. it's not a popup, it's a line of text that fades
	if UI.Toast and UI.Toast.untilTime > CurTime() then
		local v = A.Get("toast")
		A.Layer(cx, cy, 1, 0, (1 - v) * 24, v, function()
			local ty = UI.BottomEdge(h) - 74
			draw.RoundedBox(18, UI.Pad, ty, w - UI.Pad * 2, 58, Color(40, 40, 52, 235))
			draw.SimpleText(UI.Clip(UI.Toast.text, "ZPhone_Small", w - UI.Pad * 2 - 40), "ZPhone_Small", w / 2, ty + 29, T.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end)
	end

	-- tap flash on whatever was just pressed. fades out over the press animation
	if UI.Flash then
		local v = A.Get("press")
		if v < 1 then
			local f = UI.Flash
			draw.RoundedBox(12, f.x, f.y, f.w, f.h, Color(255, 255, 255, math.floor(40 * (1 - v))))
		end
	end

	-- cursor dot when the mouse is on the screen
	if UI.Cursor then
		draw.RoundedBox(6, UI.Cursor.x - 6, UI.Cursor.y - 6, 12, 12, Color(255, 255, 255, 220))
	end

	drawBanner(w, h)
end

-- ========== the screen-plane mapping ==========

-- world-space plane of the screen, from the phone transform + tuned screen offset
local function getScreenPlane(wep)
	local pos, ang = wep:GetPhoneTransform()
	if not pos then return end
	local s = ZPHONE.Tuning.screen
	local origin, sang = LocalToWorld(s.pos, s.ang, pos, ang)
	return origin, sang, s.w, s.h
end

-- where on the screen is the mouse pointing. called once per frame while the phone is up
local function updateCursor(wep)
	UI.Cursor = nil
	local view = render.GetViewSetup(true)
	if not view then return end

	local origin, sang, sw, sh = getScreenPlane(wep)
	if not origin then return end

	local mx, my = input.GetCursorPos()
	local dir = util.AimVector(view.angles, view.fov, mx, my, ScrW(), ScrH())
	local hit = util.IntersectRayWithPlane(view.origin, dir, origin, sang:Forward())
	if not hit then return end

	-- must be within a sane distance, otherwise you're pointing at a wall behind your phone
	if hit:Distance(LocalPlayer():EyePos()) > 90 then return end

	local local_ = WorldToLocal(hit, angle_zero, origin, sang)
	-- local_.x = right, local_.y = left (gmod), we flip y so the top of the screen is up
	local u = (-local_.y) / sw + 0.5
	local v = (-local_.z) / sh + 0.5
	if u < 0 or u > 1 or v < 0 or v > 1 then return end

	UI.Cursor = { x = u * UI.W, y = v * UI.H }
end

-- ========== per-frame: auto lock, screen clicker, rendering into the rt ==========

local clickerOn = false
local function setClicker(on)
	if on == clickerOn then return end
	clickerOn = on
	gui.EnableScreenClicker(on)
end

local function renderScreen()
	-- reapply the orientation every frame. it's a cheap matrix, and it means no other code path can leave the screen flipped
	ZPHONE.ApplyScreenOrient()

	render.PushRenderTarget(ZPHONE.RT)
	render.SetViewPort(0, 0, UI.W, UI.H)
	render.Clear(0, 0, 0, 255, true, true)
	cam.Start2D()
	local ok, err = pcall(UI.Draw, UI.W, UI.H)
	if ok then UI.DrawOverlays(UI.W, UI.H) end
	cam.End2D()
	render.PopRenderTarget()
	-- gmod has no render.GetViewPort, so we just put the viewport back to the whole screen
	render.SetViewPort(0, 0, ScrW(), ScrH())
	if not ok then
		-- if the ui breaks, it breaks loudly, once, then keeps trying. don't spam the console 60 times a second
		if not UI.ErrPrinted then
			ErrorNoHalt("[zphone ui] " .. tostring(err) .. "\n")
			UI.ErrPrinted = true
		end
	end
end

hook.Add("PreRender", "ZPhone_Screen", function()
	local ply = LocalPlayer()
	if not IsValid(ply) then return end
	local wep = ply:GetActiveWeapon()
	if not (IsValid(wep) and wep.isZPhone) then
		setClicker(false)
		return
	end

	-- only bother rendering the ui when the phone is actually out. pocket = no ui, no cost
	local blend = wep.Blend or 0
	-- the phone starting to come down ends any typing
	if blend < 1.9 and UI.Keyboard then UI.Keyboard = nil end
	if blend < 0.2 then
		setClicker(false)
		return
	end

	local raised = wep:IsRaised()
	setClicker(raised)
	if raised then
		updateCursor(wep)
	else
		UI.Cursor = nil
	end

	-- the screen clicker eats LMB, so PrimaryAttack never fires while the phone is up.
	-- we watch the button ourselves, edge-triggered so holding it doesn't spam taps
	local down = input.IsMouseDown(MOUSE_LEFT)
	if raised and down and not UI.MouseWasDown then
		UI.HandleTap()
	end
	UI.MouseWasDown = down

	-- auto lock when you've been idle, unless you're on a call, phones don't hang up on you
	if UI.Screen ~= "lock" and not ZPHONE.State.call and (CurTime() - UI.LastInput) > UI.AutoLockTime then
		UI.Lock()
	end

	renderScreen()
end)

-- the screen mapping and cursor are only for the local player. this is the tap handler the swep calls
function UI.HandleTap()
	UI.LastInput = CurTime()
	if not UI.Cursor or UI.Busy() then return end
	local b = UI.HitTest(UI.Cursor.x, UI.Cursor.y)
	if b and b.fn then
		UI.PlaySound("tap", 35, 100, 0.3)
		UI.Flash = { x = b.x, y = b.y, w = b.w, h = b.h }
		A.Play("press")
		b.fn()
	end
end

-- ========== ringing loop ==========

local function startRing()
	if timer.Exists("ZPhoneRingLoop") then return end
	timer.Create("ZPhoneRingLoop", 1.2, 0, function()
		UI.PlaySound("ring", 55, 100, 0.6)
	end)
end

local function stopRing()
	timer.Remove("ZPhoneRingLoop")
end

-- ========== net ==========

net.Receive("ZPhoneSync", function()
	local data = net.ReadTable() or {}
	ZPHONE.State = data
	ZPHONE.State.contacts = data.contacts or {}
	ZPHONE.State.messages = data.messages or {}
	ZPHONE.State.spamNames = data.spamNames or {}
	ZPHONE.State.blocked = data.blocked or {}

	-- battery and crack warnings, once each time they change. the first sync after joining counts as a change too
	local pw = data.power or {}
	local was = ZPHONE.LastPower or {}
	local batt = pw.batt or 100
	for _, mark in ipairs({ 20, 10 }) do
		if batt <= mark and (was.batt or 100) > mark then UI.Notify("battery at " .. mark .. "%") end
	end
	if batt <= 0 and (was.batt or 100) > 0 then UI.Notify("phone's dead") end
	if batt > (was.batt or 100) + 5 then UI.Notify("charged to " .. batt .. "%") end
	if pw.cracked and not was.cracked then UI.Notify("screen cracked") end
	ZPHONE.LastPower = { batt = batt, cracked = pw.cracked }

	if data.call and data.call.incoming and data.call.state == "ringing" then
		startRing()
	elseif not (data.call and data.call.state == "ringing") then
		stopRing()
	end
end)

net.Receive("ZPhoneEvent", function()
	local kind = net.ReadString()
	local data = net.ReadTable() or {}

	if kind == "typing" then
		-- the other side is typing. three seconds of dots, no buzz, no counter
		UI.Typing[data.with] = { untilTime = CurTime() + 3, who = data.name }
		return
	end

	if kind == "buzz" then
		-- notification: a buzz, a counter, and the strip that drops from the top
		UI.Unread = UI.Unread + 1
		UI.PlaySound("buzz", 45, 100, 0.5)
		UI.Notify(data.text and ("from " .. tostring(data.text)) or "new message")
	elseif kind == "sent" then
		UI.PlaySound("send", 35, 100, 0.4)
	elseif kind == "ring" then
		startRing()
	elseif kind == "accepted" then
		stopRing()
		UI.PlaySound("pickup", 40, 100, 0.5)
	elseif kind == "callend" then
		stopRing()
		UI.PlaySound("hangup", 40, 100, 0.5)
		UI.Say("call ended (" .. tostring(data.reason or "?") .. ")", 2)
	elseif kind == "error" then
		UI.Say(tostring(data.text or "error"), 3)
	elseif kind == "ordered" then
		UI.Say("order placed: " .. tostring(data.item or "?"), 3)
	end
end)

-- ========== apps ==========
-- the apps file adds ZPHONE.AppDraw[id] and ZPHONE.AppColor(id). it's loaded after everything above so it can use UI.*
include("zphone/cl_zphone_apps.lua")
include("zphone/cl_zphone_settings.lua")
include("zphone/cl_zphone_camera.lua")
-- the social feed app. loads after the apps, and registers ZPHONE.AppDraw.feed
include("zphone/cl_zphone_feed.lua")
-- physical typing: the real keyboard types into open fields. loads last, it only adds hooks and the bar
include("zphone/cl_zphone_typing.lua")
include("zphone/cl_zphone_map.lua")