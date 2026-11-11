local UI = ZPHONE.UI
ZPHONE.Keyboard = ZPHONE.Keyboard or {}
local KB = ZPHONE.Keyboard

local PAD = 8
local KEY_H = 92
local HEADER_H = 110
local ROWS_H = 4 * (KEY_H + PAD)
local PANEL_H = HEADER_H + ROWS_H -- 510
local COL_BG = Color(24, 24, 32)
local COL_KEY = Color(66, 66, 80)
local COL_SPECIAL = Color(50, 50, 62)
local COL_SHIFT_ON = Color(84, 118, 176)
local COL_DEL = Color(96, 54, 58)
local COL_DONE = Color(44, 150, 84)
local COL_FIELD = Color(14, 14, 20)

local function keys(str, wt)
	local out = {}
	for i = 1, #str do
		out[#out + 1] = { k = string.sub(str, i, i), wt = wt }
	end
	return out
end

local function join(...)
	local out = {}
	for _, t in ipairs({ ... }) do
		for _, v in ipairs(t) do out[#out + 1] = v end
	end
	return out
end

local SPACER = { k = "", wt = 0.5 }

local LAYOUT = {
	alpha = {
		keys("qwertyuiop", 1),
		join({ SPACER }, keys("asdfghjkl", 1), { SPACER }),
		join({ { k = "SHIFT", wt = 1.5 } }, keys("zxcvbnm", 1), { { k = "DEL", wt = 1.5 } }),
		{ { k = "123", wt = 2.5 }, { k = "space", wt = 5 }, { k = "done", wt = 2.5 } },
	},
	sym = {
		keys("1234567890", 1),
		keys("@#$%&-+()/", 1),
		join(keys(".,?!'\"*:;", 1), { { k = "DEL", wt = 1 } }),
		{ { k = "ABC", wt = 2.5 }, { k = "space", wt = 5 }, { k = "done", wt = 2.5 } },
	},
	num = {
		keys("123", 1),
		keys("456", 1),
		keys("789", 1),
		{ { k = "DEL", wt = 1 }, { k = "0", wt = 1 }, { k = "done", wt = 1 } },
	},
}

local function buildKeys(rows, w, y0)
	local out = {}
	local y = y0
	for _, row in ipairs(rows) do
		local total = 0
		for _, key in ipairs(row) do total = total + key.wt end
		local unit = (w - PAD * (#row + 1)) / total
		local x = PAD
		for _, key in ipairs(row) do
			local kw = key.wt * unit
			if key.k ~= "" then
				out[#out + 1] = { k = key.k, x = x, y = y, w = kw, h = KEY_H }
			end
			x = x + kw + PAD
		end
		y = y + KEY_H + PAD
	end
	return out
end

function KB.Top(h, slide)
	return h - PANEL_H + (1 - (slide or 1)) * (PANEL_H + 40)
end

local function notify(kb)
	if kb.onChange then kb.onChange(kb.text) end
	UI.LastInput = CurTime()
end

function KB.Insert(s)
	local kb = UI.Keyboard
	if not kb then return end
	if kb.layer == "num" and not string.match(s, "^%d$") then return end
	if #kb.text >= kb.max then return end
	if kb.shift then
		s = string.upper(s)
		kb.shift = false
	end
	kb.text = kb.text .. s
	notify(kb)
end

function KB.Erase()
	local kb = UI.Keyboard
	if not kb or kb.text == "" then return end
	kb.text = string.sub(kb.text, 1, #kb.text - 1)
	notify(kb)
end

function KB.Press(k)
	local kb = UI.Keyboard
	if not kb then return end

	if k == "DEL" then
		KB.Erase()
	elseif k == "SHIFT" then
		kb.shift = not kb.shift
	elseif k == "123" then
		kb.layer = "sym"
	elseif k == "ABC" then
		kb.layer = "alpha"
	elseif k == "space" then
		KB.Insert(" ")
	elseif k == "done" then
		UI.Keyboard = nil
		if kb.onDone then kb.onDone(kb.text) end
	else
		KB.Insert(k)
	end
end

local function fitTail(text, font, maxW)
	surface.SetFont(font)
	local s = text
	while #s > 0 and surface.GetTextSize(s) > maxW do
		s = string.sub(s, 2)
	end
	return s
end

local function keyColor(k, kb)
	if k == "DEL" then return COL_DEL end
	if k == "done" then return COL_DONE end
	if k == "SHIFT" then return kb.shift and COL_SHIFT_ON or COL_SPECIAL end
	if k == "123" or k == "ABC" or k == "space" then return COL_SPECIAL end
	return COL_KEY
end

local function drawHeader(w, top, kb)
	local label = (kb.label ~= "" and kb.label) or "message"
	draw.SimpleText(label, "ZPhone_Small", PAD + 16, top + 14, Color(150, 150, 160), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText(#kb.text .. "/" .. kb.max, "ZPhone_Small", w - PAD - 16, top + 14, Color(110, 110, 120), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	local fx, fy, fw, fh = PAD, top + 40, w - PAD * 2, 60
	draw.RoundedBox(14, fx, fy, fw, fh, COL_FIELD)

	local inner = fw - 32
	if kb.text == "" then
		draw.SimpleText("type here", "ZPhone_Body", fx + 16, fy + fh / 2, Color(90, 90, 100), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	else
		local shown = fitTail(kb.text, "ZPhone_Body", inner - 10)
		draw.SimpleText(shown, "ZPhone_Body", fx + 16, fy + fh / 2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	if math.floor(CurTime() * 2) % 2 == 0 then
		surface.SetFont("ZPhone_Body")
		local tw = (kb.text == "") and 0 or surface.GetTextSize(fitTail(kb.text, "ZPhone_Body", inner - 10))
		local cx = fx + 16 + tw + 2
		surface.SetDrawColor(color_white)
		surface.DrawRect(cx, fy + 12, 3, fh - 24)
	end
end

function KB.Draw(w, h, slide)
	local kb = UI.Keyboard
	if not kb then return end
	kb.layer = kb.layer or ((kb.label == "number") and "num" or "alpha")

	local top = KB.Top(h, slide)

	draw.RoundedBox(0, 0, top - 12, w, h - top + 12, COL_BG)
	UI.Btn(0, top - 12, w, h - top + 12, function() end)

	drawHeader(w, top, kb)

	local rows = LAYOUT[kb.layer] or LAYOUT.alpha
	local list = buildKeys(rows, w, top + HEADER_H)
	for _, key in ipairs(list) do
		local k = key.k
		draw.RoundedBox(12, key.x, key.y, key.w, key.h, keyColor(k, kb))

		local label = KB.Label(k)
		if k == "SHIFT" then label = "shift"
		elseif k == "DEL" then label = "del" end
		draw.SimpleText(label, "ZPhone_Key", key.x + key.w / 2, key.y + key.h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		local press = k
		UI.Btn(key.x, key.y, key.w, key.h, function() KB.Press(press) end)
	end
end

function KB.Label(k)
	local kb = UI.Keyboard
	if kb and kb.shift and string.match(k, "^%l$") then return string.upper(k) end
	return k
end
