-- zphone battery and the cracked screen. included from sv_zphone.lua.
-- the battery drains while you carry the phone: slowly in the pocket, faster while it's out.
-- admins charge it with zphone_charge "name". a hard fall with the phone on you cracks the screen, zphone_repair "name" fixes it.
-- state lives in ZPHONE.Store.power, keyed by SteamID64, so it survives restarts with the rest of the store.

local C = ZPHONE.Config
local Store = ZPHONE.Store
Store.power = Store.power or {}

-- the battery and crack state for one player. made on first use, so anyone who never had one starts on a full battery
function ZPHONE.PowerOf(ply)
	local key = ply:SteamID64()
	local p = Store.power[key]
	if not p then
		p = { batt = C.Battery.start, cracked = false }
		Store.power[key] = p
	end
	return p
end

function ZPHONE.Dead(ply)
	return IsValid(ply) and ZPHONE.PowerOf(ply).batt <= 0
end

-- what the client gets. a copy, so nothing the client does can touch the real table
function ZPHONE.PowerData(ply)
	local p = ZPHONE.PowerOf(ply)
	return { batt = math.floor(p.batt), cracked = p.cracked }
end

-- ========== drain ==========
-- one step every few seconds. only players with the phone on them drain. the sync only goes out when the shown percentage changes

timer.Create("ZPhoneBattery", C.Battery.tick, 0, function()
	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply) and ply:HasWeapon("weapon_zphone") then
			local p = ZPHONE.PowerOf(ply)
			if p.batt > 0 then
				local out = ply:GetNWFloat("zphone_blend", 0) > 0.2
				local perMin = out and C.Battery.activePerMin or C.Battery.idlePerMin
				local before = math.floor(p.batt)
				p.batt = math.max(0, p.batt - perMin * C.Battery.tick / 60)
				if math.floor(p.batt) ~= before then
					ZPHONE.Sync(ply)
					ZPHONE.Save()
				end
			end
		end
	end
end)

-- ========== the crack ==========
-- a hard fall with the phone on you. once cracked it stays cracked until someone repairs it

hook.Add("EntityTakeDamage", "ZPhone_CrackOnFall", function(victim, dmg)
	if not (IsValid(victim) and victim:IsPlayer()) then return end
	if not dmg:IsFallDamage() or dmg:GetDamage() < C.Crack.fallDamage then return end
	if not victim:HasWeapon("weapon_zphone") then return end

	local p = ZPHONE.PowerOf(victim)
	if p.cracked then return end
	p.cracked = true
	ZPHONE.Save()

	-- next tick, not inside the damage hook
	timer.Simple(0, function()
		if IsValid(victim) then ZPHONE.Sync(victim) end
	end)
end)

-- ========== admin commands ==========

local function say(ply, msg)
	if IsValid(ply) then ply:ChatPrint("[zphone] " .. msg) else print("[zphone] " .. msg) end
end

-- the player whose name matches. an exact match wins, otherwise any name containing the text.
-- more than one match is refused, so nobody gets charged by accident
local function findPlayer(ply, query)
	local q = string.lower(string.Trim(query or ""))
	if q == "" then
		say(ply, "give me a name")
		return
	end

	local exact, partial = {}, {}
	for _, p in ipairs(player.GetAll()) do
		local n = string.lower(p:Nick())
		if n == q then
			exact[#exact + 1] = p
		elseif string.find(n, q, 1, true) then
			partial[#partial + 1] = p
		end
	end

	local list = #exact > 0 and exact or partial
	if #list == 0 then
		say(ply, "no player called '" .. tostring(query) .. "'")
		return
	end
	if #list > 1 then
		local names = {}
		for _, p in ipairs(list) do names[#names + 1] = p:Nick() end
		say(ply, "more than one match: " .. table.concat(names, ", ") .. ". be more specific")
		return
	end
	return list[1]
end

local function adminOnly(ply)
	return not IsValid(ply) or C.IsAdminForPings(ply)
end

concommand.Add("zphone_charge", function(ply, _, args)
	if not adminOnly(ply) then say(ply, "admins only.") return end
	local target = findPlayer(ply, args[1])
	if not target then return end

	ZPHONE.PowerOf(target).batt = C.Battery.start
	ZPHONE.Save()
	ZPHONE.Sync(target)
	say(ply, target:Nick() .. "'s phone is charged.")
end)

concommand.Add("zphone_crack", function(ply, _, args)
	if not adminOnly(ply) then say(ply, "admins only.") return end
	local target = findPlayer(ply, args[1])
	if not target then return end

	local p = ZPHONE.PowerOf(target)
	if p.cracked then say(ply, target:Nick() .. "'s screen is already cracked.") return end
	p.cracked = true
	ZPHONE.Save()
	ZPHONE.Sync(target)
	say(ply, target:Nick() .. "'s screen is cracked.")
end)

concommand.Add("zphone_repair", function(ply, _, args)
	if not adminOnly(ply) then say(ply, "admins only.") return end
	local target = findPlayer(ply, args[1])
	if not target then return end

	ZPHONE.PowerOf(target).cracked = false
	ZPHONE.Save()
	ZPHONE.Sync(target)
	say(ply, target:Nick() .. "'s screen is fixed.")
end)
