-- zphone map points, server side. the places the toolgun puts on the phone map: stores, departments, commercial buildings and so on.
-- one list per map, saved to data/zphone_mappoints/<map>.json. every phone gets it in its sync (data.mapPoints).
-- included from sv_zphone.lua. the toolgun (stool/zphone_mappoint.lua) calls the functions at the bottom.

local C = ZPHONE.Config
local DIR = "zphone_mappoints"
local FILE = DIR .. "/" .. game.GetMap() .. ".json"

ZPHONE.MapPoints = ZPHONE.MapPoints or {}
local nextPointId = 1

local function save()
	file.CreateDir(DIR)
	file.Write(FILE, util.TableToJSON(ZPHONE.MapPoints, true))
end

local function pushAll()
	for _, p in ipairs(player.GetAll()) do ZPHONE.Sync(p) end
end

-- a copy of the list for the phones, so nothing a client does can reach the real one
function ZPHONE.MapPointsForSync()
	local out = {}
	for _, p in ipairs(ZPHONE.MapPoints) do
		out[#out + 1] = { id = p.id, kind = p.kind, name = p.name, x = p.x, y = p.y, z = p.z }
	end
	return out
end

local function load()
	local raw = file.Read(FILE, "DATA")
	local t = raw and util.JSONToTable(raw)
	if not istable(t) then return end
	ZPHONE.MapPoints = {}
	for _, p in ipairs(t) do
		if C.MapKindOf(p.kind) and isnumber(p.x) and isnumber(p.y) then
			p.z = tonumber(p.z) or 0
			p.id = tonumber(p.id) or nextPointId
			nextPointId = math.max(nextPointId, p.id + 1)
			ZPHONE.MapPoints[#ZPHONE.MapPoints + 1] = p
		end
	end
end
load()

-- index of the point closest to pos (flat distance), if it's within radius
local function nearest(pos, radius)
	local best, bestD
	for i, p in ipairs(ZPHONE.MapPoints) do
		local d = math.sqrt((p.x - pos.x) ^ 2 + (p.y - pos.y) ^ 2)
		if d <= radius and (not bestD or d < bestD) then best, bestD = i, d end
	end
	return best
end

function ZPHONE.AddMapPoint(kind, name, pos)
	local id = nextPointId
	nextPointId = nextPointId + 1
	ZPHONE.MapPoints[#ZPHONE.MapPoints + 1] = { id = id, kind = kind, name = name, x = pos.x, y = pos.y, z = pos.z }
	save()
	pushAll()
	return id
end

function ZPHONE.RemoveNearestMapPoint(pos, radius)
	local i = nearest(pos, radius)
	if not i then return nil end
	local p = table.remove(ZPHONE.MapPoints, i)
	save()
	pushAll()
	return p
end

function ZPHONE.UpdateNearestMapPoint(pos, radius, kind, name)
	local i = nearest(pos, radius)
	if not i then return nil end
	local p = ZPHONE.MapPoints[i]
	p.kind, p.name = kind, name
	save()
	pushAll()
	return p
end

-- console placement, admins only, run from the in-game console (it needs an aim).
--   zpoint_<kind> "Name"  places a point of that kind where you're looking. the name is optional.
--   zpoint_remove         removes the nearest point within 300 units of where you're looking.
--   zpoint_list           prints every point on this map to your console.

local RADIUS = 300

local function say(ply, msg)
	ply:ChatPrint("[zphone] " .. msg)
end

local function adminCheck(ply)
	if not IsValid(ply) then
		print("[zphone] run this in-game, it needs an aim")
		return false
	end
	if C.IsAdminForPings(ply) then return true end
	say(ply, "admins only.")
	return false
end

local function aimPos(ply)
	local tr = ply:GetEyeTrace()
	if not tr.Hit then return nil end
	return tr.HitPos
end

for _, k in ipairs(C.MapKinds) do
	concommand.Add("zpoint_" .. k.id, function(ply, _, args)
		if not adminCheck(ply) then return end
		local pos = aimPos(ply)
		if not pos then
			say(ply, "look at a surface first.")
			return
		end
		local name = ZPHONE.CleanText(table.concat(args, " "), 32)
		if name == "" then name = k.name end
		ZPHONE.AddMapPoint(k.id, name, pos)
		say(ply, "placed " .. k.name .. ": " .. name)
	end)
end

concommand.Add("zpoint_remove", function(ply)
	if not adminCheck(ply) then return end
	local pos = aimPos(ply)
	if not pos then
		say(ply, "look at a surface first.")
		return
	end
	local p = ZPHONE.RemoveNearestMapPoint(pos, RADIUS)
	if p then
		say(ply, "removed " .. p.name)
	else
		say(ply, "no point within " .. RADIUS .. " units of where you're looking.")
	end
end)

concommand.Add("zpoint_list", function(ply)
	if not adminCheck(ply) then return end
	if #ZPHONE.MapPoints == 0 then
		ply:PrintMessage(HUD_PRINTCONSOLE, "[zphone] no map points on this map yet.\n")
		return
	end
	for _, p in ipairs(ZPHONE.MapPoints) do
		ply:PrintMessage(HUD_PRINTCONSOLE, string.format("[%d] %s - %s (%.0f, %.0f, %.0f)\n",
			p.id, p.kind, p.name, p.x, p.y, p.z))
	end
end)