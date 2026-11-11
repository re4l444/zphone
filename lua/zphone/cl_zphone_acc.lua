local Win = {}

local function requestOpen(explicit, char, accName)
	net.Start("ZPhoneAccOpen")
		net.WriteBool(explicit and true or false)
		net.WriteString(char or "")
		net.WriteString(accName or "")
	net.SendToServer()
end

local function sendAct(action, char, number, name)
	net.Start("ZPhoneAccAct")
		net.WriteString(action)
		net.WriteString(char or "")
		net.WriteString(number or "")
		net.WriteString(name or "")
	net.SendToServer()
end

local function charLabel(c)
	return (c == "") and "(default)" or c
end

local function clearBody()
	for _, c in ipairs(Win.body:GetCanvas():GetChildren()) do c:Remove() end
end

local function dockButton(parent, text, w, fn)
	local b = vgui.Create("DButton", parent)
	b:Dock(RIGHT)
	b:SetWide(w)
	b:DockMargin(6, 6, 6, 6)
	b:SetText(text)
	b.DoClick = fn
	return b
end

local function build(st)
	if not IsValid(Win.frame) then
		Win.frame = vgui.Create("DFrame")
		Win.frame:SetSize(540, 660)
		Win.frame:Center()
		Win.frame:MakePopup()
		Win.body = vgui.Create("DScrollPanel", Win.frame)
		Win.body:Dock(FILL)
		Win.body:DockMargin(8, 6, 8, 8)
	end
	Win.frame:SetTitle("zphone accounts  -  " .. charLabel(st.char))
	clearBody()
	local body = Win.body

	-- character picker
	local pick = vgui.Create("DComboBox", body)
	pick:Dock(TOP)
	pick:DockMargin(0, 0, 0, 10)
	pick:SetValue(charLabel(st.char))
	for _, c in ipairs(st.chars or {}) do
		pick:AddChoice(charLabel(c), c)
	end
	function pick:OnSelect(_, _, c)
		requestOpen(true, c, "")
	end

	local head = vgui.Create("DLabel", body)
	head:Dock(TOP)
	head:SetTall(24)
	head:DockMargin(4, 0, 0, 6)
	head:SetText("numbers on this character")
	head:SetTextColor(Color(160, 160, 170))

	-- the numbers
	for _, a in ipairs(st.accounts or {}) do
		local num, name, inUse = a.number, a.name, a.inUse
		local row = vgui.Create("DPanel", body)
		row:Dock(TOP)
		row:SetTall(54)
		row:DockMargin(0, 0, 0, 6)
		row.Paint = function(_, w, h)
			draw.RoundedBox(8, 0, 0, w, h, inUse and Color(44, 70, 56) or Color(40, 40, 52))
		end

		dockButton(row, "delete", 92, function()
			Derma_Query(
				"delete " .. name .. " (" .. ZPHONE.Config.FormatNumber(tonumber(num) or 0) .. ")?\nits own texts go with it.",
				"zphone", "delete", function() sendAct("del", st.char, num) end,
				"cancel"
			)
		end)
		if not inUse then
			dockButton(row, "use", 72, function() sendAct("use", st.char, num) end)
		end

		local lbl = vgui.Create("DLabel", row)
		lbl:Dock(FILL)
		lbl:DockMargin(14, 0, 8, 0)
		lbl:SetText(name .. "   " .. ZPHONE.Config.FormatNumber(tonumber(num) or 0) .. (inUse and "   in use" or ""))
		lbl:SetTextColor(Color(235, 235, 240))
	end

	if #(st.accounts or {}) == 0 then
		local none = vgui.Create("DLabel", body)
		none:Dock(TOP)
		none:SetTall(30)
		none:SetText("no numbers on this character yet")
		none:SetTextColor(Color(120, 120, 130))
	end

	-- add a number
	local addRow = vgui.Create("DPanel", body)
	addRow:Dock(TOP)
	addRow:SetTall(54)
	addRow:DockMargin(0, 6, 0, 0)
	addRow.Paint = function() end

	local te = vgui.Create("DTextEntry", addRow)
	te:Dock(FILL)
	te:DockMargin(0, 6, 6, 6)
	te:SetPlaceholderText("name for a new number")
	local function addNew()
		local n = string.Trim(te:GetValue())
		if n == "" then return end
		sendAct("new", st.char, "", n)
		te:SetValue("")
	end
	te.OnEnter = addNew
	dockButton(addRow, "add", 80, addNew)

	-- which character the phone plays as
	local bind = vgui.Create("DButton", body)
	bind:Dock(TOP)
	bind:SetTall(42)
	bind:DockMargin(0, 16, 0, 0)
	if st.bound == st.char then
		bind:SetText("this character is on your phone now")
		bind:SetEnabled(false)
	else
		bind:SetText("put this character on my phone")
		bind.DoClick = function() sendAct("bind", st.char) end
	end

	if st.note and st.note ~= "" then
		local note = vgui.Create("DLabel", body)
		note:Dock(TOP)
		note:SetTall(36)
		note:DockMargin(4, 10, 0, 0)
		note:SetText(st.note)
		note:SetTextColor(Color(242, 186, 62))
	end
end

concommand.Add("zphone_acc", function(_, _, args)
	if args[1] == nil then
		requestOpen(false)
	else
		requestOpen(true, args[1], args[2] or "")
	end
end)

net.Receive("ZPhoneAccSync", function()
	build(net.ReadTable() or {})
end)
