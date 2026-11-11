local UI = ZPHONE.UI
local T = UI.Theme
local C = ZPHONE.Config
local CFG = C.MapOverview
ZPHONE.AppDraw = ZPHONE.AppDraw or {}

UI.Map = UI.Map or { u = 0.5, v = 0.5, zoom = 1, filter = nil, sel = nil }
UI.MapLast = nil

ZPHONE.MapRT = ZPHONE.MapRT or GetRenderTarget("zphone_map_rt", CFG.size, CFG.size)
if not ZPHONE.MapMat then
	ZPHONE.MapMat = CreateMaterial("zphone_map_mat", "UnlitGeneric", {
		["$basetexture"] = ZPHONE.MapRT:GetName(),
	})
end

local UNKNOWN = { name = "Place", abbr = "?", col = Color(120, 120, 130) }
local function kindOf(id) return C.MapKindOf(id) or UNKNOWN end
local BOX
local function box()
	if BOX then return BOX end
	local mins, maxs = C.MapBounds.mins, C.MapBounds.maxs
	BOX = {
		mins = mins, maxs = maxs, src = "config",
		cx = (mins.x + maxs.x) / 2,
		cy = (mins.y + maxs.y) / 2,
		half = math.max(maxs.x - mins.x, maxs.y - mins.y) / 2,
		zmin = mins.z, zmax = maxs.z,
	}
	return BOX
end

local function worldToUV(x, y)
	local b = box()
	local u = (x - b.cx) / (b.half * 2) + 0.5
	local v = 0.5 - (y - b.cy) / (b.half * 2)
	if CFG.flipX then u = 1 - u end
	if CFG.flipY then v = 1 - v end
	return u, v
end

local function cameraFor(b)
	local S = b.half
	local z = b.zmax + math.max(512, S * 2)
	local D = z - b.zmin
	local fov = math.deg(2 * math.atan(S / D)) * 1.05
	return z, D, fov
end

local warned = false

local function renderOverview(dumpName)
	local b = box()
	local z, D, fov = cameraFor(b)

	render.PushRenderTarget(ZPHONE.MapRT)
	local ok, err = pcall(function()
		render.Clear(20, 24, 30, 255, true, true)
		render.RenderView({
			x = 0, y = 0, w = CFG.size, h = CFG.size,
			origin = Vector(b.cx, b.cy, z),
			angles = Angle(90, 90, 0),
			fov = fov,
			aspect = 1,
			znear = 16,
			zfar = D * 1.5 + 2048,
			drawhud = false, drawviewmodel = false, drawmonitors = false, dopostprocess = false,
		})
		if dumpName then
			local png = render.Capture({ format = "png", x = 0, y = 0, w = CFG.size, h = CFG.size })
			if png then file.Write(dumpName, png) end
		end
	end)
	render.PopRenderTarget()
	return ok, err
end

local lastRender, rendering = -math.huge, false
hook.Add("PostRender", "ZPhone_MapOverview", function()
	if rendering then return end
	if ZPHONE.MapDumpNext then
		local name = ZPHONE.MapDumpNext
		ZPHONE.MapDumpNext = nil
		rendering = true
		local ok, err = renderOverview(name)
		rendering = false
		print(ok and ("[zphone map] debug render saved to data/" .. name)
			or ("[zphone map] debug render FAILED: " .. tostring(err)))
		return
	end

	if UI.Screen ~= "map" then return end
	local ply = LocalPlayer()
	if not IsValid(ply) then return end
	local wep = ply:GetActiveWeapon()
	if not (IsValid(wep) and wep.isZPhone) or (wep.Blend or 0) < 0.2 then return end
	if CurTime() - lastRender < CFG.refresh then return end
	lastRender = CurTime()

	rendering = true
	local ok, err = renderOverview()
	rendering = false
	if not ok and not warned then
		warned = true
		ErrorNoHalt("[zphone map] " .. tostring(err) .. "\n")
	end
end)

concommand.Add("zphone_mapdebug", function()
	local b = box()
	local z = cameraFor(b)
	print(string.format("[zphone map] bounds from %s: mins %s, maxs %s", b.src, tostring(b.mins), tostring(b.maxs)))
	print(string.format("[zphone map] camera z %.0f, half-size %.0f", z, b.half))
	ZPHONE.MapDumpNext = "zphone_mapdebug.png"
end)

local function nextFilter(cur)
	local list = C.MapKinds
	if cur == nil then return list[1].id end
	for i, k in ipairs(list) do
		if k.id == cur then return list[i + 1] and list[i + 1].id or nil end
	end
	return nil
end

local iconCache = {}
local function iconFor(path)
	local m = iconCache[path]
	if m == nil then
		m = Material(path, "smooth")
		if m:IsError() then m = false end
		iconCache[path] = m
	end
	return m
end

local function drawMarker(x, y, kind, selected)
	local r = selected and 22 or 17
	draw.RoundedBox(r, x - r, y - r, r * 2, r * 2, selected and T.text or Color(10, 10, 14, 200))
	local ir = r - 3
	draw.RoundedBox(ir, x - ir, y - ir, ir * 2, ir * 2, kind.col)

	local mat = kind.icon and iconFor(kind.icon)
	if mat then
		local s = ir * 1.1
		surface.SetMaterial(mat)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawTexturedRect(x - s / 2, y - s / 2, s, s)
	else
		draw.SimpleText(kind.abbr, "ZPhone_Tiny", x, y, T.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

ZPHONE.AppDraw.map = function(w, h)
	local M = UI.Map
	local ply = LocalPlayer()
	local P = IsValid(ply) and ply:GetPos() or nil

	UI.Title(w, "Map", { label = "me", fn = function()
		local here = IsValid(ply) and ply:GetPos() or nil
		if here then M.u, M.v = worldToUV(here.x, here.y) end
	end })

	local mx, my = UI.Pad, UI.ContentY
	local mw = w - UI.Pad * 2
	local ctrlY = UI.BottomEdge(h) - 84
	local mh = ctrlY - 16 - my

	draw.RoundedBox(UI.Radius, mx, my, mw, mh, Color(20, 24, 30))

	if M.zoom <= 1 then M.u, M.v = 0.5, 0.5 end
	local side = math.min(mw, mh) * M.zoom
	local c = UI.Cursor
	if c and input.IsMouseDown(MOUSE_LEFT) and c.x >= mx and c.x <= mx + mw and c.y >= my and c.y <= my + mh then
		if UI.MapLast then
			M.u = M.u - (c.x - UI.MapLast.x) / side
			M.v = M.v - (c.y - UI.MapLast.y) / side
		end
		UI.MapLast = { x = c.x, y = c.y }
	else
		UI.MapLast = nil
	end
	M.u = math.Clamp(M.u, 0, 1)
	M.v = math.Clamp(M.v, 0, 1)
	local ix = mx + mw / 2 - M.u * side
	local iy = my + mh / 2 - M.v * side
	local function toScreen(u, v) return ix + u * side, iy + v * side end
	local x0, y0 = math.max(mx, ix), math.max(my, iy)
	local x1, y1 = math.min(mx + mw, ix + side), math.min(my + mh, iy + side)
	if x1 > x0 and y1 > y0 then
		surface.SetMaterial(ZPHONE.MapMat)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawTexturedRectUV(x0, y0, x1 - x0, y1 - y0,
			(x0 - ix) / side, (y0 - iy) / side, (x1 - ix) / side, (y1 - iy) / side)
	end

	UI.Btn(mx, my, mw, mh, function() M.sel = nil end)

	if P then
		local px, py = toScreen(worldToUV(P.x, P.y))
		if px >= mx and px <= mx + mw and py >= my and py <= my + mh then
			local yaw = math.rad(ply:EyeAngles().y)
			local fx, fy = toScreen(worldToUV(P.x + math.cos(yaw) * 160, P.y + math.sin(yaw) * 160))
			surface.SetDrawColor(T.accent)
			surface.DrawLine(px, py, fx, fy)
			draw.RoundedBox(12, px - 12, py - 12, 24, 24, T.accent)
		end
	end

	local pts = ZPHONE.State.mapPoints or {}
	for _, p in ipairs(pts) do
		if not M.filter or p.kind == M.filter then
			local sx, sy = toScreen(worldToUV(p.x, p.y))
			if sx > mx + 16 and sx < mx + mw - 16 and sy > my + 16 and sy < my + mh - 16 then
				local id = p.id
				drawMarker(sx, sy, kindOf(p.kind), M.sel == id)
				UI.Btn(sx - 22, sy - 22, 44, 44, function() M.sel = id end)
			end
		end
	end

	local sel
	for _, p in ipairs(pts) do
		if p.id == M.sel then sel = p break end
	end
	if sel then
		local kind = kindOf(sel.kind)
		local cx, cy, cw, ch = mx + 12, my + mh - 116, mw - 24, 104
		draw.RoundedBox(20, cx, cy, cw, ch, Color(10, 10, 16, 235))
		UI.Btn(cx, cy, cw, ch, function() end)
		UI.Text(cx + 22, cy + 34, UI.Clip(sel.name or kind.name, "ZPhone_Body", cw - 200), "ZPhone_Body", T.text)
		UI.Text(cx + 22, cy + 74, kind.name, "ZPhone_Small", kind.col)
		if P then
			local d = math.Round(math.sqrt((P.x - sel.x) ^ 2 + (P.y - sel.y) ^ 2) / CFG.meters)
			UI.Text(cx + cw - 22, cy + 52, d .. " m", "ZPhone_Body", T.dim, TEXT_ALIGN_RIGHT)
		end
	end

	local bw = (mw - 24) / 3
	UI.Pill(mx, ctrlY, bw, 64, "zoom in", T.card, T.text, function()
		M.zoom = math.min(6, M.zoom * 1.5)
	end)
	UI.Pill(mx + bw + 12, ctrlY, bw, 64, "zoom out", T.card, T.text, function()
		M.zoom = math.max(1, M.zoom / 1.5)
	end)
	local fname = M.filter and kindOf(M.filter).name or "all places"
	UI.Pill(mx + (bw + 12) * 2, ctrlY, bw, 64, UI.Clip(fname, "ZPhone_Small", bw - 20), T.card, T.text, function()
		M.filter = nextFilter(M.filter)
		M.sel = nil
	end)
end

concommand.Add("zphone_mappos", function()
	local ply = LocalPlayer()
	if not IsValid(ply) then return end
	local p = ply:GetPos()
	local line = string.format("Vector(%.0f, %.0f, %.0f)", p.x, p.y, p.z)
	SetClipboardText(line)
	print("[zphone] " .. line .. " (copied to clipboard)")
end)