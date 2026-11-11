local UI = ZPHONE.UI
local T = UI.Theme
ZPHONE.AppDraw = ZPHONE.AppDraw or {}

UI.FeedDraft = UI.FeedDraft or ""
UI.FeedStart = UI.FeedStart or 1

local CARD_PAD = 22
local LINE_H = 30

local function postHeight(lines)
	return 86 + #lines * LINE_H + 56
end

local function drawPost(w, y, p, lines)
	local cw = w - UI.Pad * 2
	local ch = postHeight(lines)
	local official = p.kind == "official"

	UI.Card(UI.Pad, y, cw, ch, nil, official and Color(46, 38, 58) or T.card)

	UI.Text(UI.Pad + CARD_PAD, y + 30, UI.Clip(p.author or "?", "ZPhone_Body", cw - 200), "ZPhone_Body", T.text)
	UI.Text(UI.Pad + CARD_PAD, y + 64, "@" .. (p.handle or "unknown"), "ZPhone_Tiny", T.faint)
	UI.Text(w - UI.Pad - CARD_PAD, y + 30, UI.Ago(p.t), "ZPhone_Tiny", T.faint, TEXT_ALIGN_RIGHT)
	if official then
		UI.Text(w - UI.Pad - CARD_PAD, y + 64, "official", "ZPhone_Tiny", T.warn, TEXT_ALIGN_RIGHT)
	end

	for i, ln in ipairs(lines) do
		UI.Text(UI.Pad + CARD_PAD, y + 100 + (i - 1) * LINE_H, ln, "ZPhone_Small", T.text)
	end

	local fy = y + 86 + #lines * LINE_H + 28
	local likeLabel = (p.liked and "liked  " or "like  ") .. (p.likes or 0)
	UI.Pill(UI.Pad + CARD_PAD, fy - 22, 160, 44, likeLabel,
		p.liked and Color(74, 40, 62) or T.cardHi,
		p.liked and T.danger or T.text,
		function() UI.Act("like", { id = p.id }) end)

	if p.mine then
		UI.Pill(w - UI.Pad - CARD_PAD - 120, fy - 22, 120, 44, "delete", Color(74, 38, 40), T.danger, function()
			UI.Act("delpost", { id = p.id })
		end)
	end
end

ZPHONE.AppDraw.feed = function(w, h)
	UI.Title(w, "Feed")
	local cw = w - UI.Pad * 2

	local cy = UI.ContentY
	local postW = 110
	local fieldW = cw - postW - 12

	draw.RoundedBox(32, UI.Pad, cy, fieldW, 64, T.field)
	if UI.FeedDraft == "" then
		UI.Text(UI.Pad + 26, cy + 32, "what's happening?", "ZPhone_Small", T.faint)
	else
		UI.Text(UI.Pad + 26, cy + 32, UI.ClipTail(UI.FeedDraft, "ZPhone_Small", fieldW - 52), "ZPhone_Small", T.text)
	end
	UI.Btn(UI.Pad, cy, fieldW, 64, function()
		UI.OpenKeyboard({
			text = UI.FeedDraft,
			max = ZPHONE.Config.Feed.maxLen,
			label = "post",
			onChange = function(t) UI.FeedDraft = t end,
			onDone = function()
				if UI.FeedDraft == "" then return end
				UI.Act("post", { text = UI.FeedDraft })
				UI.FeedDraft = ""
				UI.FeedStart = 1
			end,
		})
	end)
	UI.Pill(w - UI.Pad - postW, cy, postW, 64, "post", UI.FeedDraft ~= "" and T.ok or T.cardHi, T.text, function()
		if UI.FeedDraft == "" then return end
		UI.Act("post", { text = UI.FeedDraft })
		UI.FeedDraft = ""
		UI.FeedStart = 1
		UI.Keyboard = nil
	end)

	local top = cy + 84
	local bottom = UI.BottomEdge(h) - 80
	local posts = ZPHONE.State.feed or {}
	local count = #posts

	if count == 0 then
		UI.Text(w / 2, (top + bottom) / 2, "nothing here yet. be the first.", "ZPhone_Small", T.faint, TEXT_ALIGN_CENTER)
		return
	end

	local start = math.Clamp(UI.FeedStart, 1, count)
	UI.FeedStart = start

	local y = top
	local lastShown = start - 1
	for i = start, count do
		local p = posts[i]
		local lines = UI.Wrap(p.text, "ZPhone_Small", cw - CARD_PAD * 2)
		local ch = postHeight(lines)
		if y + ch > bottom then break end
		drawPost(w, y, p, lines)
		y = y + ch + 12
		lastShown = i
	end

	local py = bottom + 10
	local bw = (cw - 12) / 2
	if start > 1 then
		UI.Pill(UI.Pad, py, bw, 52, "newer", T.card, T.dim, function()
			UI.FeedStart = math.max(1, start - 3)
		end)
	end
	if lastShown < count then
		UI.Pill(UI.Pad + bw + 12, py, bw, 52, "older", T.card, T.dim, function()
			UI.FeedStart = lastShown + 1
		end)
	end
end
