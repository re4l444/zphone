-- zphone admin account window, server side. opened by zphone_acc (cl_zphone_acc.lua).
-- admins only, and every request is checked here: a character has to be one of yours, a number has to be on that character.
-- included from sv_zphone.lua, so it only uses ZPHONE.* exports (sv_zphone.lua's locals aren't visible here).

util.AddNetworkString("ZPhoneAccOpen")
util.AddNetworkString("ZPhoneAccAct")
util.AddNetworkString("ZPhoneAccSync")

-- everything the window shows: your characters, and the numbers on the one being looked at
local function stateFor(ply, char, note)
	local seen, chars = {}, {}
	for _, acc in pairs(ZPHONE.Store.accounts) do
		if acc.owner == ply:SteamID64() then
			local c = acc.char or ""
			if not seen[c] then
				seen[c] = true
				chars[#chars + 1] = c
			end
		end
	end
	table.sort(chars, function(a, b) return string.lower(a) < string.lower(b) end)

	local accounts = {}
	for _, acc in ipairs(ZPHONE.AccountsOfChar(ply, char)) do
		accounts[#accounts + 1] = { number = acc.number, name = acc.name, inUse = acc.inUse == true }
	end

	return { char = char, bound = ZPHONE.CharOf(ply), chars = chars, accounts = accounts, note = note }
end

-- sends the window its state, and sends the phone a fresh sync too, in case the number in use changed
local function push(ply, char, note)
	net.Start("ZPhoneAccSync")
		net.WriteTable(stateFor(ply, char, note))
	net.Send(ply)
	ZPHONE.Sync(ply)
end

-- opens a character. a new one gets a first number. accName picks a number on it (or makes one) and puts it in use
local function open(ply, char, accName)
	if #ZPHONE.AccountsOfChar(ply, char) == 0 then
		local first = (accName ~= "") and accName or ((char ~= "") and char or ply:Nick())
		local acc, err = ZPHONE.CreateAccount(ply, char, first)
		if not acc then return push(ply, char, err) end
		ZPHONE.SetInUse(ply, char, acc.number)
		return push(ply, char)
	end

	if accName ~= "" then
		local found
		for _, a in ipairs(ZPHONE.AccountsOfChar(ply, char)) do
			if string.lower(a.name) == string.lower(accName) then
				found = a
				break
			end
		end
		if not found then
			local acc, err = ZPHONE.CreateAccount(ply, char, accName)
			if not acc then return push(ply, char, err) end
			found = acc
		end
		ZPHONE.SetInUse(ply, char, found.number)
	end

	push(ply, char)
end

net.Receive("ZPhoneAccOpen", function(len, ply)
	if not ZPHONE.Config.IsAdminForPings(ply) then
		ply:ChatPrint("[zphone] admins only.")
		return
	end
	local explicit = net.ReadBool()
	local char = ZPHONE.CleanText(net.ReadString(), 24)
	local accName = ZPHONE.CleanText(net.ReadString(), 24)
	if not explicit then char = ZPHONE.CharOf(ply) end
	open(ply, char, accName)
end)

net.Receive("ZPhoneAccAct", function(len, ply)
	if not ZPHONE.Config.IsAdminForPings(ply) then return end

	local action = net.ReadString()
	local char = ZPHONE.CleanText(net.ReadString(), 24)
	local number = ZPHONE.CleanText(net.ReadString(), 24)
	local name = ZPHONE.CleanText(net.ReadString(), 24)
	local note

	if action == "bind" then
		ZPHONE.BindChar(ply, char)
	elseif action == "use" then
		local acc = ZPHONE.OwnedAccount(ply, number)
		if acc and (acc.char or "") == char then
			ZPHONE.SetInUse(ply, char, number)
		else
			note = "that number isn't on this character"
		end
	elseif action == "new" then
		local acc, err = ZPHONE.CreateAccount(ply, char, name)
		if acc then ZPHONE.SetInUse(ply, char, acc.number) else note = err end
	elseif action == "del" then
		note = ZPHONE.DeleteAccount(ply, char, number)
	else
		return
	end

	push(ply, char, note)
end)
