-- zphone physical typing. while a text field is open and the phone is up, the real keyboard types into it.
-- binds like WASD, jump, use and reload are blocked while typing, so you don't walk around. attacks still work:
-- LMB taps the screen, and RMB lowers the phone, which also closes the field.
-- Enter finishes the field. the bar at the bottom has "done" for mouse users, and "keys" to bring back the on-screen keys.
-- included from cl_zphone_ui.lua after the feed app.

local UI = ZPHONE.UI
local T = UI.Theme
local KB = ZPHONE.Keyboard
ZPHONE.Typing = ZPHONE.Typing or {}
local Typing = ZPHONE.Typing

-- true when the real keyboard should be typing into the phone right now
local function active()
	local kb = UI.Keyboard
	if not kb or not kb.physical then return false end
	local ply = LocalPlayer()
	if not IsValid(ply) then return false end
	local wep = ply:GetActiveWeapon()
	return IsValid(wep) and wep.isZPhone and (wep.Blend or 0) > 1.9
end

-- ========== key tables ==========
-- built from the KEY_ globals, so nothing depends on the order the engine numbers them in

local LETTERS, DIGITS, SYMBOLS = {}, {}, {}

for c = string.byte("a"), string.byte("z") do
	local ch = string.char(c)
	local key = _G["KEY_" .. string.upper(ch)]
	if key then LETTERS[key] = ch end
end

for d = 0, 9 do
	local key = _G["KEY_" .. d]
	if key then DIGITS[key] = tostring(d) end
	local pad = _G["KEY_PAD_" .. d]
	if pad then DIGITS[pad] = tostring(d) end
end

-- each symbol has its plain character and its shifted one
local SYMBOL_NAMES = {
	{ "KEY_SPACE", " ", " " },
	{ "KEY_PERIOD", ".", ">" },
	{ "KEY_COMMA", ",", "<" },
	{ "KEY_SLASH", "/", "?" },
	{ "KEY_MINUS", "-", "_" },
	{ "KEY_EQUAL", "=", "+" },
	{ "KEY_SEMICOLON", ";", ":" },
	{ "KEY_APOSTROPHE", "'", "\"" },
}
for _, s in ipairs(SYMBOL_NAMES) do
	local key = _G[s[1]]
	if key then SYMBOLS[key] = { s[2], s[3] } end
end

local SHIFTED_DIGIT = {
	["1"] = "!", ["2"] = "@", ["3"] = "#", ["4"] = "$", ["5"] = "%",
	["6"] = "^", ["7"] = "&", ["8"] = "*", ["9"] = "(", ["0"] = ")",
}

-- the character a key makes, or nil if it makes none. numeric fields only take digits
local function charFor(key, upper, numeric)
	if LETTERS[key] then
		if numeric then return nil end
		return upper and string.upper(LETTERS[key]) or LETTERS[key]
	end
	if DIGITS[key] then
		local d = DIGITS[key]
		if upper and not numeric then return SHIFTED_DIGIT[d] end
		return d
	end
	if SYMBOLS[key] then
		if numeric then return nil end
		return upper and SYMBOLS[key][2] or SYMBOLS[key][1]
	end
end

-- one key press into the open field
local function press(key)
	local kb = UI.Keyboard
	if not kb then return end

	if key == KEY_BACKSPACE then
		KB.Erase()
		return
	end

	-- Enter finishes the field, the same as "done" on the on-screen keys
	if key == KEY_ENTER or key == KEY_PAD_ENTER then
		UI.Keyboard = nil
		if kb.onDone then kb.onDone(kb.text) end
		return
	end

	local numeric = kb.label == "number"
	local upper = input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT)
	local ch = charFor(key, upper, numeric)
	if ch then KB.Insert(ch) end
end

hook.Add("PlayerButtonDown", "ZPhone_Typing", function(ply, button)
	if ply ~= LocalPlayer() or not active() then return end
	press(button)
end)

-- while typing, binds are blocked on press so WASD, jump, use and reload do nothing. releases still go through,
-- so a key that was already held when typing started can't get stuck on. attacks are left alone
hook.Add("PlayerBindPress", "ZPhone_TypingBinds", function(ply, bind, pressed)
	if ply ~= LocalPlayer() or not pressed or not active() then return end
	if string.find(bind, "attack", 1, true) then return end
	return true
end)

-- ========== the bar ==========
-- drawn in place of the home bar while the real keyboard is in use

function Typing.DrawBar(w, h)
	local kb = UI.Keyboard
	if not kb then return end
	local H = UI.TypeH
	local y = h - H

	draw.RoundedBox(0, 0, y, w, H, Color(34, 34, 46))
	-- registered first, so it's the fallback for taps on the strip. the pills below win over it, and it stops taps
	-- from reaching the home bar underneath
	UI.Btn(0, y, w, H, function() end)

	-- the live text, so you can see what you're typing whatever app it's going into
	draw.RoundedBox(24, UI.Pad, y + 12, w - UI.Pad * 2, 46, T.field)
	if kb.text == "" then
		UI.Text(UI.Pad + 20, y + 35, "type here", "ZPhone_Small", T.faint)
	else
		UI.Text(UI.Pad + 20, y + 35, UI.ClipTail(kb.text, "ZPhone_Small", w - UI.Pad * 2 - 40), "ZPhone_Small", T.text)
	end

	UI.Text(UI.Pad, y + 88, "typing", "ZPhone_Tiny", T.dim)
	UI.Pill(w - UI.Pad - 226, y + 64, 110, 46, "keys", T.cardHi, T.text, function()
		if UI.Keyboard then UI.Keyboard.physical = false end
	end)
	UI.Pill(w - UI.Pad - 104, y + 64, 104, 46, "done", T.ok, T.bg, function()
		local cur = UI.Keyboard
		if not cur then return end
		UI.Keyboard = nil
		if cur.onDone then cur.onDone(cur.text) end
	end)
end
