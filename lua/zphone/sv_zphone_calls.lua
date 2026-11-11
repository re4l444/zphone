-- zphone server: calls (voice + text), 911, taxi, delivery orders, and the voice hook into z-city.
-- included from sv_zphone.lua, so ZPHONE.Store / ZPHONE.ActiveOf / ZPHONE.Sync etc. are already here. don't cargo-cult the locals from the other file, they aren't visible.
-- dev1: "voice calls are just proximity chat with extra steps" dev2: "that's what i said" dev1: "you said it louder"

ZPHONE.Calls = ZPHONE.Calls or {}   -- callId -> call
ZPHONE.CallOf = ZPHONE.CallOf or {} -- phone number -> callId (one call per line, we are not a call center)
ZPHONE.Emergencies = ZPHONE.Emergencies or {} -- emId -> 911 line. kept apart from normal calls: the caller might not have a number at all
local nextCallId = 0
local nextEmId = 0

-- ========== normal calls ==========

-- end a call and tell everybody still connected. `exclude` is for the disconnect case, don't sync a guy who's leaving
local function endCall(id, reason, exclude)
	local call = ZPHONE.Calls[id]
	if not call then return end

	ZPHONE.Calls[id] = nil
	ZPHONE.CallOf[call.from] = nil
	ZPHONE.CallOf[call.to] = nil
	timer.Remove("ZPhoneRing" .. id)

	for _, num in ipairs({ call.from, call.to }) do
		local p = ZPHONE.PlayerForNumber(num)
		if IsValid(p) and p ~= exclude then
			ZPHONE.Event(p, "callend", { reason = reason })
			ZPHONE.Sync(p)
		end
	end
end

-- push the current call state to both sides after something changed (accepted, text sent, etc)
local function syncCall(call, eventKind)
	for _, num in ipairs({ call.from, call.to }) do
		local p = ZPHONE.PlayerForNumber(num)
		if IsValid(p) then
			if eventKind then ZPHONE.Event(p, eventKind, { id = call.id }) end
			ZPHONE.Sync(p)
		end
	end
end

-- find a call this player is a party to. returns call, and the player's own number on it
local function myCall(ply, id)
	local me = ZPHONE.ActiveOf(ply)
	if not me then return end
	local call = ZPHONE.Calls[tostring(id or "")]
	if not call then return end
	if call.from ~= me.number and call.to ~= me.number then return end
	return call, me.number
end

-- what the client should draw for a normal call. nil if you're not on one
local function normalCallState(ply)
	local me = ZPHONE.ActiveOf(ply)
	if not me then return nil end
	local id = ZPHONE.CallOf[me.number]
	local call = id and ZPHONE.Calls[id]
	if not call then return nil end

	local peer = (call.from == me.number) and call.to or call.from
	local peerAcc = ZPHONE.Store.accounts[peer]

	return {
		id = call.id,
		state = call.state,           -- "ringing" | "active"
		kind = call.kind,             -- "voice" | "text"
		incoming = call.state == "ringing" and call.to == me.number,
		peer = peer,
		peerName = peerAcc and peerAcc.name or peer,
		log = (call.kind == "text") and call.log or nil,
	}
end

-- is `a` currently on an active voice call with `b`. used by the voice hook below. 911 lines count too
function ZPHONE.InVoiceCall(a, b)
	for _, em in pairs(ZPHONE.Emergencies) do
		if em.state == "active" and ((em.caller == a and em.responder == b) or (em.caller == b and em.responder == a)) then
			return true
		end
	end

	local na, nb = ZPHONE.ActiveOf(a), ZPHONE.ActiveOf(b)
	if not na or not nb then return false end
	local id = ZPHONE.CallOf[na.number]
	local call = id and ZPHONE.Calls[id]
	if not call or call.state ~= "active" or call.kind ~= "voice" then return false end
	return (call.from == na.number and call.to == nb.number)
		or (call.to == na.number and call.from == nb.number)
end

-- ========== 911 ==========
-- a 911 line is a voice call between the caller and whichever responder accepts it. it rings every responder online,
-- and the call overlay on their phone is the way they pick it up (they don't need an account to take it)

local function emIdOf(id)
	return string.match(tostring(id or ""), "^em(%d+)$")
end

-- the 911 line this player is on as the caller, or as the responder who picked it up
local function emergencyFor(ply)
	for _, em in pairs(ZPHONE.Emergencies) do
		if em.caller == ply then return em, "caller" end
		if em.responder == ply then return em, "responder" end
	end
end

-- a ringing line a responder can still pick up. declining hides it for that responder only, the others keep getting it
local function ringingLineFor(ply)
	if not ZPHONE.Config.IsResponder(ply) then return nil end
	for _, em in pairs(ZPHONE.Emergencies) do
		if em.state == "ringing" and ply.ZPhoneEMDeclined ~= em.id then return em end
	end
end

local function emergencyState(ply)
	local em, role = emergencyFor(ply)
	if not em then
		em = ringingLineFor(ply)
		if not em then return nil end
		role = "responder"
	end

	if role == "caller" then
		return {
			id = "em" .. em.id,
			state = "active",
			kind = "voice",
			incoming = false,
			peer = "911",
			peerName = em.responder and ("911 · " .. em.responder:Nick()) or "911 · ringing",
			emergency = true,
		}
	end

	-- responder: the ring comes in as an incoming call, once accepted it's just a call with the caller
	return {
		id = "em" .. em.id,
		state = em.state == "ringing" and "ringing" or "active",
		kind = "voice",
		incoming = em.state == "ringing",
		peer = "911",
		peerName = "911 · " .. em.callerName,
		emergency = true,
	}
end

-- every responder online gets the chat line and the buzz. buzz text is what the banner on their phone says
local function notifyResponders(msg, buzzText)
	for _, p in ipairs(player.GetAll()) do
		if ZPHONE.Config.IsResponder(p) then
			p:ChatPrint(msg)
			ZPHONE.Event(p, "buzz", { text = buzzText })
			ZPHONE.Sync(p)
		end
	end
end

local function notifyAdmins(msg, buzzText)
	for _, admin in ipairs(player.GetAll()) do
		if ZPHONE.Config.IsAdminForPings(admin) then
			admin:ChatPrint(msg)
			ZPHONE.Event(admin, "buzz", { text = buzzText })
		end
	end
end

local function endEmergency(id, reason, exclude)
	local em = ZPHONE.Emergencies[id]
	if not em then return end

	ZPHONE.Emergencies[id] = nil
	timer.Remove("ZPhoneEM" .. id)

	for _, p in ipairs({ em.caller, em.responder }) do
		if IsValid(p) and p ~= exclude then
			ZPHONE.Event(p, "callend", { reason = reason })
			ZPHONE.Sync(p)
		end
	end
end

-- the rest of the 911 route. returns an error string for the player if something's off
local function emergencyAccept(ply, id)
	local em = ZPHONE.Emergencies[id]
	if not em or em.state ~= "ringing" then return "someone already picked up" end
	if em.caller == ply or not ZPHONE.Config.IsResponder(ply) then return "that's not your line" end

	em.state = "active"
	em.responder = ply
	timer.Remove("ZPhoneEM" .. id)

	ZPHONE.Event(em.caller, "accepted")
	ZPHONE.Sync(em.caller)
	ZPHONE.Sync(ply)
	-- the other responders stop seeing the ring
	for _, p in ipairs(player.GetAll()) do
		if p ~= ply and ZPHONE.Config.IsResponder(p) then ZPHONE.Sync(p) end
	end
end

-- ========== handlers ==========

ZPHONE.Handlers.callstart = function(ply, d)
	local me = ZPHONE.ActiveOf(ply)
	if not me then return "no active account" end
	if ZPHONE.CallOf[me.number] then return "you're already on a call" end

	local to = tostring(d.to or "")
	local target = ZPHONE.Store.accounts[to]
	if not target then return "dead number" end
	if target.number == me.number then return "you can't call yourself, we tried this already" end
	if ZPHONE.CallOf[to] then return "line's busy" end

	-- blocked numbers just get "unreachable", same as a phone that's off. they can't tell they've been blocked
	if target.blocked[me.number] then return "unreachable. try again later." end

	local recv = ZPHONE.PlayerForNumber(to)
	if not IsValid(recv) then return "unreachable. try again later." end
	-- a phone with a dead battery can't be reached, same as one that's off
	if ZPHONE.Dead(recv) then return "unreachable. try again later." end

	nextCallId = nextCallId + 1
	local id = tostring(nextCallId)
	local kind = (d.kind == "text") and "text" or "voice"

	ZPHONE.Calls[id] = {
		id = id,
		from = me.number,
		to = to,
		state = "ringing",
		kind = kind,
		log = {},
		started = CurTime(),
	}
	ZPHONE.CallOf[me.number] = id
	ZPHONE.CallOf[to] = id

	-- ring for 30s, then the call gives up on its own. nobody wants to hold forever
	timer.Create("ZPhoneRing" .. id, 30, 1, function()
		local c = ZPHONE.Calls[id]
		if c and c.state == "ringing" then endCall(id, "missed") end
	end)

	ZPHONE.Event(recv, "ring", { id = id, from = me.name, number = me.number })
	ZPHONE.Sync(recv)
end

ZPHONE.Handlers.callaccept = function(ply, d)
	local eid = emIdOf(d.id)
	if eid then return emergencyAccept(ply, tonumber(eid)) end

	local call, mine = myCall(ply, d.id)
	if not call or call.to ~= mine then return end
	if call.state ~= "ringing" then return end

	call.state = "active"
	call.started = CurTime()
	timer.Remove("ZPhoneRing" .. call.id)
	syncCall(call, "accepted")
end

ZPHONE.Handlers.calldecline = function(ply, d)
	local eid = emIdOf(d.id)
	if eid then
		-- declining only hides it for this responder, the line keeps ringing for the others
		local em = ZPHONE.Emergencies[tonumber(eid)]
		if em then
			ply.ZPhoneEMDeclined = em.id
			ZPHONE.Sync(ply)
		end
		return
	end

	local call, mine = myCall(ply, d.id)
	if not call or call.to ~= mine then return end
	if call.state ~= "ringing" then return end
	endCall(call.id, "declined")
end

ZPHONE.Handlers.callhangup = function(ply, d)
	local eid = emIdOf(d.id)
	if eid then
		local em = ZPHONE.Emergencies[tonumber(eid)]
		if em and (em.caller == ply or em.responder == ply) then endEmergency(em.id, "hungup") end
		return
	end

	local call = myCall(ply, d.id)
	if not call then return end
	endCall(call.id, "hungup")
end

-- text calls are live text back and forth. they're not stored in the message history, they vanish when the call ends
ZPHONE.Handlers.calltext = function(ply, d)
	local call, mine = myCall(ply, d.id)
	if not call or call.kind ~= "text" or call.state ~= "active" then return end

	local text = ZPHONE.CleanText(d.text, ZPHONE.Config.MaxMessageLength)
	if text == "" then return end

	call.log[#call.log + 1] = { from = mine, text = text, t = os.time() }
	while #call.log > 200 do table.remove(call.log, 1) end
	syncCall(call)
end

-- 911. one live line per caller, and a cooldown so the line can't be spammed
ZPHONE.Handlers.emergency = function(ply, d)
	if (ply.ZPhoneEmergencyCD or 0) > CurTime() then
		return "wait " .. math.ceil(ply.ZPhoneEmergencyCD - CurTime()) .. "s before calling again"
	end
	if emergencyFor(ply) then return "you're already on the line with 911" end

	ply.ZPhoneEmergencyCD = CurTime() + ZPHONE.Config.Emergency.cooldown

	nextEmId = nextEmId + 1
	local acc = ZPHONE.ActiveOf(ply)
	local em = {
		id = nextEmId,
		caller = ply,
		callerName = acc and (acc.name .. " (" .. ZPHONE.Config.FormatNumber(acc.number) .. ")") or ply:Nick(),
		state = "ringing",
		responder = nil,
		reason = ZPHONE.CleanText(d.reason, 120),
	}
	ZPHONE.Emergencies[em.id] = em

	local pos = ply:GetPos()
	local line = string.format("[911] %s is calling from %.0f, %.0f, %.0f", em.callerName, pos.x, pos.y, pos.z)
	if em.reason ~= "" then line = line .. " — " .. em.reason end
	notifyResponders(line .. ". pick it up on your phone.", "911 call")

	timer.Create("ZPhoneEM" .. em.id, ZPHONE.Config.Emergency.ringTime, 1, function()
		local cur = ZPHONE.Emergencies[em.id]
		if cur and cur.state == "ringing" then endEmergency(em.id, "no answer") end
	end)

	-- the caller sees the line straight away, saying it's still ringing
	ZPHONE.Sync(ply)
end

-- cab requests. goes to the admins, the same way delivery orders do
ZPHONE.Handlers.taxi = function(ply, d)
	if (ply.ZPhoneTaxiCD or 0) > CurTime() then
		return "a cab's already on the way, wait " .. math.ceil(ply.ZPhoneTaxiCD - CurTime()) .. "s"
	end

	local pickup = ZPHONE.CleanText(d.pickup, 60)
	local dest = ZPHONE.CleanText(d.dest, 60)
	if pickup == "" or dest == "" then return "fill in where from and where to" end

	ply.ZPhoneTaxiCD = CurTime() + ZPHONE.Config.TaxiCooldown

	local acc = ZPHONE.ActiveOf(ply)
	local who = acc and (acc.name .. " (" .. ZPHONE.Config.FormatNumber(acc.number) .. ")") or ply:Nick()
	local pos = ply:GetPos()
	notifyAdmins(string.format(
		"[TAXI] %s needs a cab. from: %s — to: %s — at %.0f, %.0f, %.0f",
		who, pickup, dest, pos.x, pos.y, pos.z
	), "cab request")

	ZPHONE.Event(ply, "ordered", { item = "cab requested" })
end

-- delivery. two levels: a category, then optionally an option. nothing spawns, nobody gets money, admins just get told
ZPHONE.Handlers.order = function(ply, d)
	local cat = ZPHONE.Config.DeliveryMenu[tonumber(d.index) or 0]
	if not cat then return "that's not on the menu" end

	local item, label = cat, cat.name
	if cat.options then
		local opt = cat.options[tonumber(d.option) or 0]
		if not opt then return "pick one of the options first" end
		item = opt
		label = cat.name .. ": " .. opt.name
	end

	if (ply.ZPhoneOrderCD or 0) > CurTime() then
		return "wait " .. math.ceil(ply.ZPhoneOrderCD - CurTime()) .. "s, the driver's still in traffic"
	end
	ply.ZPhoneOrderCD = CurTime() + ZPHONE.Config.DeliveryCooldown

	local acc = ZPHONE.ActiveOf(ply)
	local who = acc and (acc.name .. " (" .. ZPHONE.Config.FormatNumber(acc.number) .. ")") or ply:Nick()
	local pos = ply:GetPos()

	notifyAdmins(string.format(
		"[DELIVERY] %s ordered: %s (%.1f kg) — they're at %.0f, %.0f, %.0f",
		who, label, item.kg, pos.x, pos.y, pos.z
	), "delivery order")

	ZPHONE.Event(ply, "ordered", { item = label })
end

-- ========== state for the client ==========

-- the 911 line wins over a normal call, so the overlay is always there while it's live
function ZPHONE.CallStateFor(ply)
	return emergencyState(ply) or normalCallState(ply)
end

-- ========== cleanup + voice ==========

-- if somebody drops mid-call the other side shouldn't be stuck on a ringing phone forever
hook.Add("PlayerDisconnected", "ZPhone_CallCleanup", function(ply)
	local sid = ply:SteamID64()
	for id, call in pairs(ZPHONE.Calls) do
		for _, num in ipairs({ call.from, call.to }) do
			local acc = ZPHONE.Store.accounts[num]
			if acc and acc.owner == sid then
				endCall(id, "dropped", ply)
				break
			end
		end
	end

	for id, em in pairs(ZPHONE.Emergencies) do
		if em.caller == ply or em.responder == ply then
			endEmergency(id, "dropped", ply)
		end
	end
end)

-- z-city's ChatLogic asks this hook before doing its proximity check. active voice call = hear each other anywhere, non-spatial
-- (returns nothing otherwise, so z-city's normal distance/PVS/oxygen logic still runs for everyone else)
hook.Add("CanListenOthers", "ZPhone_CallVoice", function(output, input, isChat, teamonly, text)
	if isChat then return end
	if not ZPHONE.InVoiceCall(output, input) then return end
	return true, false
end)
