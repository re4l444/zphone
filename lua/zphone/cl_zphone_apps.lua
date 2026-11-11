local UI = ZPHONE.UI
local T = UI.Theme
ZPHONE.AppDraw = ZPHONE.AppDraw or {}

local COLORS = {
	messages = Color(56, 178, 96),
	contacts = Color(88, 108, 158),
	phone = Color(52, 168, 84),
	taxi = Color(226, 178, 52),
	delivery = Color(232, 116, 52),
	map = Color(64, 150, 214),
	notes = Color(212, 186, 70),
	camera = Color(70, 70, 82),
	feed = Color(236, 84, 124),
	settings = Color(110, 110, 124),
}
function ZPHONE.AppColor(id)
	return COLORS[id] or Color(60, 60, 70)
end

-- an account number is 10 digits: area code, exchange, line
local NUM_DIGITS = 10

-- what's typed so far, shaped like a number as you go: 2, (212) 8, (212) 834-7
local function shapeDigits(d)
	local a, b, c = string.sub(d, 1, 3), string.sub(d, 4, 6), string.sub(d, 7, 10)
	if #d <= 3 then return a end
	if #d <= 6 then return "(" .. a .. ") " .. b end
	return "(" .. a .. ") " .. b .. "-" .. c
end

local function digitsOnly(s)
	return (string.gsub(tostring(s or ""), "%D", ""))
end

UI.Dial = UI.Dial or ""

local function pager(key, total, per, x, y, w)
	local pages = math.max(1, math.ceil(total / per))
	local page = math.Clamp(UI.Page[key] or 1, 1, pages)
	UI.Page[key] = page
	if pages > 1 then
		local bw = (w - 12) / 2
		UI.Pill(x, y, bw, 52, "prev", T.card, T.dim, function()
			UI.Page[key] = (page > 1) and (page - 1) or pages
		end)
		UI.Pill(x + bw + 12, y, bw, 52, "next   " .. page .. "/" .. pages, T.card, T.dim, function()
			UI.Page[key] = (page % pages) + 1
		end)
	end
	local s = (page - 1) * per + 1
	return s, math.min(total, s + per - 1)
end

local function bottomButton(w, h, label, col, tcol, fn)
	local y = UI.BottomEdge(h) - 84
	UI.Pill(UI.Pad, y, w - UI.Pad * 2, 64, label, col, tcol, fn, "ZPhone_Body")
end

--messages

UI.MsgTab = UI.MsgTab or "inbox"
UI.ReadSent = UI.ReadSent or {}
UI.TypingSent = UI.TypingSent or {}
UI.GroupNew = UI.GroupNew or nil
local function pingTyping(to)
	local now = CurTime()
	if (UI.TypingSent[to] or 0) > now then return end
	UI.TypingSent[to] = now + 2.5
	UI.Act("typing", { to = to })
end

local function inboundCount(peer)
	local n = 0
	for _, m in ipairs(ZPHONE.State.messages or {}) do
		if m.with == peer and not m.out then n = n + 1 end
	end
	return n
end

local function receiptText(m, peer, group)
	local seen = m.seen or {}
	if group then
		local names = {}
		for num in pairs(seen) do
			if num ~= ZPHONE.State.active then names[#names + 1] = UI.NameOf(num) end
		end
		if #names == 0 then return nil end
		table.sort(names)
		return "seen by " .. table.concat(names, ", ")
	end
	if seen[peer] then return "read " .. os.date("%H:%M", seen[peer]) end
	return "sent"
end

local function sendAction(peer)
	return (ZPHONE.State.groups or {})[peer] and "groupsend" or "sendmsg"
end

local function threadsFor(spam)
	local spamNames = ZPHONE.State.spamNames or {}
	local map, list = {}, {}
	for _, m in ipairs(ZPHONE.State.messages or {}) do
		local isSpam = spamNames[m.with] ~= nil
		if isSpam == spam then
			local t = map[m.with]
			if not t then
				t = { with = m.with }
				map[m.with] = t
				list[#list + 1] = t
			end
			t.last = m
		end
	end
	table.sort(list, function(a, b) return (a.last.t or 0) > (b.last.t or 0) end)
	return list
end

local function drawThread(w, h)
	local peer = UI.Thread
	local group = (ZPHONE.State.groups or {})[peer]
	local spam = (ZPHONE.State.spamNames or {})[peer] ~= nil
	local blocked = (ZPHONE.State.blocked or {})[peer] ~= nil
	local alert = peer == ZPHONE.State.alertNumber
	local noReply = spam or alert

	UI.Title(w, UI.NameOf(peer), { label = "back", fn = function()
		UI.Thread = nil
		UI.Keyboard = nil
	end })

	local count = inboundCount(peer)
	if UI.ReadSent[peer] ~= count then
		UI.ReadSent[peer] = count
		UI.Act("read", { with = peer })
	end

	local sy = UI.ContentY
	local kind
	if group then
		kind = "group  -  " .. #group.members .. " people"
	elseif spam then
		kind = "spam sender"
	elseif alert then
		kind = "official alerts"
	else
		kind = shapeDigits(peer)
	end
	UI.Text(UI.Pad + 4, sy + 22, kind, "ZPhone_Small", T.faint)
	if group then
		UI.Pill(w - UI.Pad - 150, sy, 150, 44, "leave", Color(74, 38, 40), T.danger, function()
			UI.Act("leavegroup", { id = peer })
			UI.Thread = nil
			UI.Keyboard = nil
		end)
	elseif not alert then
		UI.Pill(w - UI.Pad - 150, sy, 150, 44, blocked and "unblock" or "block",
			blocked and T.cardHi or Color(74, 38, 40),
			blocked and T.text or T.danger,
			function() UI.Act("block", { number = peer, on = not blocked }) end)
	end

	local inputY = UI.BottomEdge(h) - 84
	local top, bottom = sy + 62, inputY - 14

	local msgs = {}
	for _, m in ipairs(ZPHONE.State.messages or {}) do
		if m.with == peer then msgs[#msgs + 1] = m end
	end
	if #msgs == 0 then
		UI.Text(w / 2, (top + bottom) / 2, noReply and "you can't reply to this one" or "say hi.", "ZPhone_Small", T.faint, TEXT_ALIGN_CENTER)
	end

	local y = bottom
	local typing = UI.Typing[peer]
	if typing and typing.untilTime > CurTime() and not noReply then
		local dots = string.rep(".", (math.floor(CurTime() * 3) % 3) + 1)
		local label = group and (UI.NameOf(typing.who) .. "  " .. dots) or dots
		surface.SetFont("ZPhone_Body")
		local tw = surface.GetTextSize(label)
		local bw, bh = tw + 40, 50
		y = y - bh
		draw.RoundedBox(22, UI.Pad, y, bw, bh, T.cardHi)
		draw.SimpleText(label, "ZPhone_Body", UI.Pad + 20, y + bh / 2, T.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		y = y - 10
	end

	local seenOut = false
	for i = #msgs, math.max(1, #msgs - 40), -1 do
		local m = msgs[i]
		if m.system then
			y = y - 30
			if y < top then break end
			UI.Text(w / 2, y + 14, UI.Clip(m.text, "ZPhone_Tiny", w - UI.Pad * 2), "ZPhone_Tiny", T.faint, TEXT_ALIGN_CENTER)
			y = y - 6
		else
			if m.out and not seenOut then
				seenOut = true
				local receipt = receiptText(m, peer, group)
				if receipt then
					y = y - 30
					if y < top then break end
					UI.Text(w - UI.Pad - 8, y + 14, UI.Clip(receipt, "ZPhone_Tiny", w - UI.Pad * 2), "ZPhone_Tiny", T.faint, TEXT_ALIGN_RIGHT)
				end
			end

			local lines = UI.Wrap(m.text, "ZPhone_Body", 360)
			surface.SetFont("ZPhone_Body")
			local tw = 0
			for _, ln in ipairs(lines) do
				local lw = surface.GetTextSize(ln)
				tw = math.max(tw, lw)
			end
			local bw = math.min(tw + 40, 390)
			local bh = #lines * 38 + 24
			local label = (group and not m.out) and UI.NameOf(m.from) or nil
			local extra = label and 26 or 0

			y = y - bh - extra
			if y < top then break end

			local bx = m.out and (w - UI.Pad - bw) or UI.Pad
			if label then UI.Text(bx + 20, y + 13, UI.Clip(label, "ZPhone_Tiny", bw - 20), "ZPhone_Tiny", T.dim) end
			local by = y + extra
			draw.RoundedBox(22, bx, by, bw, bh, m.out and Color(44, 118, 228) or T.cardHi)
			for li, ln in ipairs(lines) do
				draw.SimpleText(ln, "ZPhone_Body", bx + 20, by + 12 + (li - 1) * 38, T.text)
			end
			y = y - 10
		end
	end

	if noReply then
		UI.Pill(UI.Pad, inputY, w - UI.Pad * 2, 64, "this doesn't take replies", T.field, T.dim)
		return
	end

	local draft = UI.Drafts[peer] or ""
	local sendW = 96
	local fieldW = w - UI.Pad * 2 - sendW - 12

	draw.RoundedBox(32, UI.Pad, inputY, fieldW, 64, T.field)
	if draft == "" then
		UI.Text(UI.Pad + 26, inputY + 32, "message", "ZPhone_Body", T.faint)
	else
		UI.Text(UI.Pad + 26, inputY + 32, UI.ClipTail(draft, "ZPhone_Body", fieldW - 52), "ZPhone_Body", T.text)
	end
	UI.Btn(UI.Pad, inputY, fieldW, 64, function()
		UI.OpenKeyboard({
			text = UI.Drafts[peer] or "",
			max = ZPHONE.Config.MaxMessageLength,
			label = "message",
			onChange = function(t)
				UI.Drafts[peer] = t
				pingTyping(peer)
			end,
			onDone = function()
				local d = UI.Drafts[peer] or ""
				if d == "" then return end
				UI.Act(sendAction(peer), { to = peer, text = d })
				UI.Drafts[peer] = ""
			end,
		})
	end)

	UI.Pill(w - UI.Pad - sendW, inputY, sendW, 64, "send", draft ~= "" and T.ok or T.cardHi, T.text, function()
		local d = UI.Drafts[peer] or ""
		if d == "" then return end
		UI.Act(sendAction(peer), { to = peer, text = d })
		UI.Drafts[peer] = ""
		UI.Keyboard = nil
	end)
end

local function drawNewGroup(w, h)
	local G = UI.GroupNew
	local cfg = ZPHONE.Config.Groups
	local cw = w - UI.Pad * 2

	UI.Title(w, "New group", { label = "back", fn = function()
		UI.GroupNew = nil
		UI.Keyboard = nil
	end })

	local y = UI.ContentY
	draw.RoundedBox(32, UI.Pad, y, cw, 64, T.field)
	if G.name == "" then
		UI.Text(UI.Pad + 26, y + 32, "group name (optional)", "ZPhone_Small", T.faint)
	else
		UI.Text(UI.Pad + 26, y + 32, UI.ClipTail(G.name, "ZPhone_Body", cw - 52), "ZPhone_Body", T.text)
	end
	UI.Btn(UI.Pad, y, cw, 64, function()
		UI.OpenKeyboard({
			text = G.name,
			max = cfg.maxName,
			label = "group",
			onChange = function(t) G.name = t end,
			onDone = function(t) G.name = t end,
		})
	end)

	local list = {}
	for num, name in pairs(ZPHONE.State.contacts or {}) do
		list[#list + 1] = { number = num, name = name }
	end
	table.sort(list, function(a, b) return string.lower(a.name) < string.lower(b.name) end)

	local ly = y + 84
	if #list == 0 then
		UI.Text(w / 2, ly + 60, "no contacts yet. add some first, then come back.", "ZPhone_Small", T.faint, TEXT_ALIGN_CENTER)
	end
	local s, e = pager("newgroup", #list, 5, UI.Pad, ly + 5 * 96 + 4, cw)
	for i = s, e do
		local c = list[i]
		local num = c.number
		local on = G.picked[num] == true
		UI.Card(UI.Pad, ly, cw, 84, function()
			if on then
				G.picked[num] = nil
				return
			end
			local n = 0
			for _ in pairs(G.picked) do n = n + 1 end
			if n + 2 > cfg.maxMembers then
				UI.Say("a group takes " .. cfg.maxMembers .. " people, tops", 2)
				return
			end
			G.picked[num] = true
		end)
		UI.Text(UI.Pad + 26, ly + 30, UI.Clip(c.name, "ZPhone_Body", cw - 150), "ZPhone_Body", T.text)
		UI.Text(UI.Pad + 26, ly + 66, ZPHONE.Config.FormatNumber(tonumber(num) or 0), "ZPhone_Tiny", T.dim)
		UI.Pill(w - UI.Pad - 118, ly + 20, 92, 44, on and "in" or "add", on and T.ok or T.cardHi, on and T.bg or T.text)
		ly = ly + 96
	end

	local n = 0
	for _ in pairs(G.picked) do n = n + 1 end
	if n == 0 then
		bottomButton(w, h, "pick at least one contact", Color(42, 66, 108), T.dim, function() end)
	else
		bottomButton(w, h, "create group  (" .. (n + 1) .. " people)", T.ok, T.bg, function()
			local nums = {}
			for num in pairs(G.picked) do nums[#nums + 1] = num end
			UI.Act("creategroup", { name = G.name, members = nums })
			UI.GroupNew = nil
			UI.Keyboard = nil
		end)
	end
end

ZPHONE.AppDraw.messages = function(w, h)
	if UI.Thread then return drawThread(w, h) end
	if UI.GroupNew then return drawNewGroup(w, h) end

	UI.Title(w, "Messages")

	local inbox, spam = threadsFor(false), threadsFor(true)
	local tab = UI.MsgTab
	local list = (tab == "spam") and spam or inbox
	local ty = UI.ContentY
	local tw = (w - UI.Pad * 2 - 12) / 2
	UI.Pill(UI.Pad, ty, tw, 52, "inbox  " .. #inbox, tab == "inbox" and T.accent or T.card, T.text, function()
		UI.MsgTab = "inbox"
	end)
	UI.Pill(UI.Pad + tw + 12, ty, tw, 52, "spam  " .. #spam, tab == "spam" and T.warn or T.card, tab == "spam" and T.bg or T.dim, function()
		UI.MsgTab = "spam"
	end)

	local y0 = ty + 68
	local per, rowH = 5, 116
	local s, e = pager("msgs_" .. tab, #list, per, UI.Pad, y0 + per * rowH + 4, w - UI.Pad * 2)

	if #list == 0 then
		UI.Text(w / 2, y0 + 120, tab == "spam" and "no spam. yet." or "no messages. the silence is deafening.", "ZPhone_Small", T.faint, TEXT_ALIGN_CENTER)
	end

	local y = y0
	for i = s, e do
		local t = list[i]
		local peer = t.with
		UI.Card(UI.Pad, y, w - UI.Pad * 2, 104, function() UI.Thread = peer end)
		UI.Text(UI.Pad + 26, y + 32, UI.Clip(UI.NameOf(peer), "ZPhone_Body", w - 210), "ZPhone_Body", T.text)
		local g = (ZPHONE.State.groups or {})[peer]
		local who = t.last.out and "you: " or (g and (UI.NameOf(t.last.from) .. ": ") or "")
		local preview = who .. (t.last.text or "")
		UI.Text(UI.Pad + 26, y + 72, UI.Clip(preview, "ZPhone_Small", w - 110), "ZPhone_Small", T.dim)
		UI.Text(w - UI.Pad - 26, y + 32, UI.Ago(t.last.t), "ZPhone_Tiny", T.faint, TEXT_ALIGN_RIGHT)
		y = y + rowH
	end

	local hw = (w - UI.Pad * 2 - 12) / 2
	local by = UI.BottomEdge(h) - 84
	UI.Pill(UI.Pad, by, hw, 64, "+ message", Color(42, 66, 108), T.text, function()
		UI.OpenKeyboard({
			text = "",
			max = NUM_DIGITS,
			label = "number",
			onDone = function(txt)
				local num = digitsOnly(txt)
				if #num == NUM_DIGITS then
					UI.Thread = num
				else
					UI.Say("needs 10 digits", 2)
				end
			end,
		})
	end, "ZPhone_Body")
	UI.Pill(UI.Pad + hw + 12, by, hw, 64, "+ group", Color(42, 66, 108), T.text, function()
		UI.GroupNew = { name = "", picked = {} }
	end, "ZPhone_Body")
end

--contact

local function sortedContacts()
	local list = {}
	for num, name in pairs(ZPHONE.State.contacts or {}) do
		list[#list + 1] = { number = num, name = name }
	end
	table.sort(list, function(a, b) return string.lower(a.name) < string.lower(b.name) end)
	return list
end

-- the add-contact form: you type the number and the name yourself. the name is what the contact is saved as
local function drawNewContact(w, h)
	local C = UI.ContactNew
	local cw = w - UI.Pad * 2

	UI.Title(w, "New contact", { label = "back", fn = function()
		UI.ContactNew = nil
		UI.Keyboard = nil
	end })

	local y = UI.ContentY
	UI.Text(UI.Pad + 6, y, "number", "ZPhone_Small", T.dim)
	draw.RoundedBox(32, UI.Pad, y + 22, cw, 64, T.field)
	if C.number == "" then
		UI.Text(UI.Pad + 26, y + 54, "10 digits", "ZPhone_Body", T.faint)
	else
		UI.Text(UI.Pad + 26, y + 54, shapeDigits(C.number), "ZPhone_Body", T.text)
	end
	UI.Btn(UI.Pad, y + 22, cw, 64, function()
		UI.OpenKeyboard({
			text = C.number,
			max = NUM_DIGITS,
			label = "number",
			onChange = function(t) C.number = t end,
			onDone = function(t) C.number = t end,
		})
	end)

	local ny = y + 110
	UI.Text(UI.Pad + 6, ny, "name", "ZPhone_Small", T.dim)
	draw.RoundedBox(32, UI.Pad, ny + 22, cw, 64, T.field)
	if C.name == "" then
		UI.Text(UI.Pad + 26, ny + 54, "what do you call them", "ZPhone_Body", T.faint)
	else
		UI.Text(UI.Pad + 26, ny + 54, UI.ClipTail(C.name, "ZPhone_Body", cw - 52), "ZPhone_Body", T.text)
	end
	UI.Btn(UI.Pad, ny + 22, cw, 64, function()
		UI.OpenKeyboard({
			text = C.name,
			max = 24,
			label = "name",
			onChange = function(t) C.name = t end,
			onDone = function(t) C.name = t end,
		})
	end)

	local name = string.Trim(C.name)
	if #C.number == NUM_DIGITS and name ~= "" then
		bottomButton(w, h, "save contact", T.ok, T.bg, function()
			UI.Act("addcontact", { number = C.number, name = name })
			UI.ContactNew = nil
			UI.Keyboard = nil
		end)
	else
		bottomButton(w, h, "a 10 digit number and a name", Color(42, 66, 108), T.dim, function() end)
	end
end

ZPHONE.AppDraw.contacts = function(w, h)
	if UI.ContactNew then return drawNewContact(w, h) end

	UI.Title(w, "Contacts")
	local list = sortedContacts()

	local y0 = UI.ContentY + 8
	local per = 5
	local s, e = pager("contacts", #list, per, UI.Pad, y0 + per * 110 + 4, w - UI.Pad * 2)

	if #list == 0 then
		UI.Text(w / 2, y0 + 120, "no contacts yet. you're a loner, it's fine.", "ZPhone_Small", T.faint, TEXT_ALIGN_CENTER)
	end

	local y = y0
	for i = s, e do
		local c = list[i]
		local num = c.number
		local sel = UI.ContactSel == num
		local rowH = sel and 164 or 100

		UI.Card(UI.Pad, y, w - UI.Pad * 2, rowH, function()
			UI.ContactSel = sel and nil or num
		end)
		UI.Text(UI.Pad + 26, y + 34, UI.Clip(c.name, "ZPhone_Body", w - 120), "ZPhone_Body", T.text)
		UI.Text(UI.Pad + 26, y + 72, ZPHONE.Config.FormatNumber(tonumber(num) or 0), "ZPhone_Small", T.dim)

		if sel then
			local by = y + 108
			local gap = 8
			local bw = (w - UI.Pad * 2 - 32 - gap * 3) / 4
			local bx = UI.Pad + 16
			UI.Pill(bx, by, bw, 46, "call", T.ok, T.bg, function()
				UI.Act("callstart", { to = num, kind = "voice" })
			end)
			UI.Pill(bx + (bw + gap), by, bw, 46, "text", T.accent, T.text, function()
				UI.Go("messages")
				UI.MsgTab = "inbox"
				UI.Thread = num
			end)
			UI.Pill(bx + (bw + gap) * 2, by, bw, 46, "rename", Color(42, 66, 108), T.text, function()
				UI.OpenKeyboard({
					text = c.name,
					max = 24,
					label = "name",
					onDone = function(txt)
						local name = string.Trim(txt)
						if name ~= "" then UI.Act("addcontact", { number = num, name = name }) end
					end,
				})
			end)
			UI.Pill(bx + (bw + gap) * 3, by, bw, 46, "remove", Color(74, 38, 40), T.danger, function()
				UI.Act("delcontact", { number = num })
				UI.ContactSel = nil
			end)
		end
		y = y + rowH + 10
	end

	bottomButton(w, h, "+ add contact", Color(42, 66, 108), T.text, function()
		UI.ContactNew = { number = "", name = "" }
		UI.Keyboard = nil
	end)
end

--phone

local PAD = { { "1", "2", "3" }, { "4", "5", "6" }, { "7", "8", "9" }, { "*", "0", "del" } }

ZPHONE.AppDraw.phone = function(w, h)
	local armed = UI.Emergency911Armed and CurTime() < UI.Emergency911Armed
	UI.Title(w, "Phone", {
		label = armed and "tap again" or "911",
		col = armed and T.danger or Color(122, 40, 40),
		fn = function()
			if armed then
				UI.Emergency911Armed = nil
				UI.Act("emergency", {})
				UI.Say("calling 911...", 2)
			else
				UI.Emergency911Armed = CurTime() + 3
			end
		end,
	})

	-- the number being dialled
	local d = UI.Dial
	if d == "" then
		UI.Text(w / 2, 210, "enter number", "ZPhone_Small", T.faint, TEXT_ALIGN_CENTER)
	else
		draw.SimpleText(shapeDigits(d), "ZPhone_Big", w / 2, 210, T.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	local kw, kh, gap = 132, 84, 16
	local startX = (w - (3 * kw + 2 * gap)) / 2
	local startY = 262
	for r, row in ipairs(PAD) do
		for c, k in ipairs(row) do
			local x = startX + (c - 1) * (kw + gap)
			local y = startY + (r - 1) * (kh + gap)
			draw.RoundedBox(kh / 2, x, y, kw, kh, T.card)
			local label = (k == "del") and "del" or k
			draw.SimpleText(label, (k == "del") and "ZPhone_Body" or "ZPhone_Title", x + kw / 2, y + kh / 2, T.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			local key = k
			UI.Btn(x, y, kw, kh, function()
				if key == "del" then
					UI.Dial = string.sub(UI.Dial, 1, math.max(0, #UI.Dial - 1))
				elseif string.match(key, "%d") and #UI.Dial < NUM_DIGITS then
					UI.Dial = UI.Dial .. key
				end
			end)
		end
	end

	-- call buttons
	local by = 680
	local bw = (w - UI.Pad * 2 - 16) / 2
	UI.Pill(UI.Pad, by, bw, 96, "call", T.ok, T.bg, function()
		if UI.Dial == "911" then
			UI.Dial = ""
			UI.Act("emergency", {})
			return
		end
		if #UI.Dial ~= NUM_DIGITS then UI.Say("needs 10 digits", 2) return end
		UI.Act("callstart", { to = UI.Dial, kind = "voice" })
	end, "ZPhone_Body")
	UI.Pill(UI.Pad + bw + 16, by, bw, 96, "text call", T.accent, T.text, function()
		if #UI.Dial ~= NUM_DIGITS then UI.Say("needs 10 digits", 2) return end
		UI.Act("callstart", { to = UI.Dial, kind = "text" })
	end, "ZPhone_Body")
end

--taxi

UI.Taxi = UI.Taxi or { pickup = "", dest = "", sentAt = nil }

local function taxiField(w, y, label, value, hint, onTap)
	UI.Text(UI.Pad + 6, y, label, "ZPhone_Small", T.dim)
	UI.Card(UI.Pad, y + 22, w - UI.Pad * 2, 84, onTap, T.field)
	if value ~= "" then
		UI.Text(UI.Pad + 28, y + 64, UI.ClipTail(value, "ZPhone_Body", w - UI.Pad * 2 - 56), "ZPhone_Body", T.text)
	else
		UI.Text(UI.Pad + 28, y + 64, hint, "ZPhone_Body", T.faint)
	end
end

ZPHONE.AppDraw.taxi = function(w, h)
	UI.Title(w, "Taxi")
	local t = UI.Taxi

	taxiField(w, 170, "where from", t.pickup, "tap to set", function()
		UI.OpenKeyboard({
			text = t.pickup,
			max = 60,
			label = "pickup",
			onDone = function(txt) t.pickup = txt end,
		})
	end)

	taxiField(w, 300, "where to", t.dest, "tap to set", function()
		UI.OpenKeyboard({
			text = t.dest,
			max = 60,
			label = "destination",
			onDone = function(txt) t.dest = txt end,
		})
	end)

	local ready = t.pickup ~= "" and t.dest ~= ""
	UI.Pill(UI.Pad, 440, w - UI.Pad * 2, 96, "request a cab",
		ready and T.warn or T.cardHi,
		ready and T.bg or T.faint,
		function()
			if not ready then
				UI.Say("fill in both places first", 2)
				return
			end
			UI.Act("taxi", { pickup = t.pickup, dest = t.dest })
			t.sentAt = CurTime()
		end,
		"ZPhone_Body")

	local status = "the admins get a ping. they'll come find you."
	if t.sentAt and CurTime() - t.sentAt < 8 then status = "request sent. hang tight." end
	local lines = UI.Wrap(status, "ZPhone_Small", w - UI.Pad * 2)
	for i, ln in ipairs(lines) do
		UI.Text(w / 2, 580 + (i - 1) * 32, ln, "ZPhone_Small", T.dim, TEXT_ALIGN_CENTER)
	end
end

ZPHONE.AppDraw.delivery = function(w, h)
	local menu = ZPHONE.Config.DeliveryMenu
	local cat = UI.DeliveryCat and menu[UI.DeliveryCat]

	if not cat then
		UI.Title(w, "Delivery")
		local y = UI.ContentY + 8
		for i, item in ipairs(menu) do
			local idx = i
			local sub = item.options and (#item.options .. " options") or string.format("%.1f kg", item.kg)
			UI.Card(UI.Pad, y, w - UI.Pad * 2, 96, function()
				if item.options then
					UI.DeliveryCat = idx
				else
					UI.Act("order", { index = idx })
				end
			end)
			UI.Text(UI.Pad + 26, y + 34, item.name, "ZPhone_Body", T.text)
			UI.Text(UI.Pad + 26, y + 70, sub .. (item.options and "  -  choose" or "  -  order"), "ZPhone_Small", T.dim)
			y = y + 108
		end
	else
		UI.Title(w, cat.name, { label = "menu", fn = function() UI.DeliveryCat = nil end })
		local y = UI.ContentY + 8
		for j, opt in ipairs(cat.options) do
			local optIdx = j
			local catIdx = UI.DeliveryCat
			UI.Card(UI.Pad, y, w - UI.Pad * 2, 96, function()
				UI.Act("order", { index = catIdx, option = optIdx })
			end)
			UI.Text(UI.Pad + 26, y + 34, opt.name, "ZPhone_Body", T.text)
			UI.Text(UI.Pad + 26, y + 70, string.format("%.2f kg  -  order", opt.kg), "ZPhone_Small", T.dim)
			y = y + 108
		end
	end
end

-- note

ZPHONE.AppDraw.notes = function(w, h)
	UI.Title(w, "Notes")
	local my = UI.ContentY
	local mh = UI.BottomEdge(h) - my - 16

	draw.RoundedBox(UI.Radius, UI.Pad, my, w - UI.Pad * 2, mh, T.card)

	local text = ZPHONE.State.notes or ""
	if text == "" then
		UI.Text(UI.Pad + 26, my + 34, "tap to write something down", "ZPhone_Small", T.faint)
	else
		local lines = UI.Wrap(text, "ZPhone_Body", w - UI.Pad * 2 - 52)
		for i = 1, math.min(#lines, 20) do
			draw.SimpleText(lines[i], "ZPhone_Body", UI.Pad + 26, my + 24 + (i - 1) * 40, T.text)
		end
	end

	UI.Btn(UI.Pad, my, w - UI.Pad * 2, mh, function()
		UI.OpenKeyboard({
			text = ZPHONE.State.notes or "",
			max = ZPHONE.Config.MaxNotesLength,
			label = "notes",
			onDone = function(t) UI.Act("savenote", { text = t }) end,
		})
	end)
end
