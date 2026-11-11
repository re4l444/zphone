local UI = ZPHONE.UI
local T = UI.Theme
local CFG = ZPHONE.Config.Camera
ZPHONE.AppDraw = ZPHONE.AppDraw or {}

UI.PhotoCount = UI.PhotoCount or 0
UI.CamFront = UI.CamFront or false

ZPHONE.CamRT = ZPHONE.CamRT or GetRenderTarget("zphone_cam_rt", CFG.w, CFG.h)
if not ZPHONE.CamMat then
	ZPHONE.CamMat = CreateMaterial("zphone_cam_mat", "UnlitGeneric", {
		["$basetexture"] = ZPHONE.CamRT:GetName(),
		["$translucent"] = 0,
	})
end

local function cameraView(wep)
	local pos, ang = wep:GetPhoneTransform()
	if not pos then return end

	local s = ZPHONE.Tuning.screen
	local spos, sang = LocalToWorld(s.pos, s.ang, pos, ang)

	if UI.CamFront then
		return spos + sang:Forward() * CFG.offset, sang
	end

	local _, angles = LocalToWorld(vector_origin, Angle(0, 180, 0), vector_origin, sang)
	return spos - sang:Forward() * CFG.offset, angles
end

local rendering = false
local frame = 0
local warned = false

local function warnOnce(err)
	if warned then return end
	warned = true
	ErrorNoHalt("[zphone camera] " .. tostring(err) .. "\n")
end

local function cameraPass(wep)
	local origin, angles = cameraView(wep)
	if not origin then return end

	render.PushRenderTarget(ZPHONE.CamRT)
	local ok, err = pcall(function()
		render.Clear(0, 0, 0, 255, true, true)
		render.RenderView({
			x = 0, y = 0, w = CFG.w, h = CFG.h,
			origin = origin, angles = angles,
			fov = CFG.fov, aspect = CFG.w / CFG.h,
			znear = 1, zfar = 8000,
			drawhud = false, drawviewmodel = false, drawmonitors = false, dopostprocess = false,
		})

		if UI.ShutterPending then
			UI.ShutterPending = false
			local data = render.Capture({ format = "jpeg", quality = CFG.quality, x = 0, y = 0, w = CFG.w, h = CFG.h })
			if data then
				file.CreateDir("zphone_photos")
				UI.PhotoCount = UI.PhotoCount + 1
				file.Write("zphone_photos/" .. os.time() .. "_" .. UI.PhotoCount .. ".jpg", data)
				UI.Say("saved to data/zphone_photos", 2)
			end
		end
	end)
	render.PopRenderTarget()

	if not ok then warnOnce(err) end
end

hook.Add("PostRender", "ZPhone_RearCamera", function()
	if rendering or UI.Screen ~= "camera" then return end

	frame = frame + 1
	if frame % 2 ~= 0 and not UI.ShutterPending then return end

	local ply = LocalPlayer()
	if not IsValid(ply) then return end
	local wep = ply:GetActiveWeapon()
	if not (IsValid(wep) and wep.isZPhone and wep.GetPhoneTransform) then return end

	rendering = true
	cameraPass(wep)
	rendering = false
end)

local function drawCamera(w, h)
	UI.Title(w, "Camera")

	local shutterY = UI.BottomEdge(h) - 190
	local vfH = shutterY - 16 - UI.ContentY
	draw.RoundedBox(UI.Radius, UI.Pad, UI.ContentY, w - UI.Pad * 2, vfH, Color(10, 10, 14))

	local fw, fh = w - UI.Pad * 2 - 24, vfH - 24
	local scale = math.min(fw / CFG.w, fh / CFG.h)
	local dw, dh = CFG.w * scale, CFG.h * scale
	surface.SetMaterial(ZPHONE.CamMat)
	surface.SetDrawColor(255, 255, 255, 255)
	surface.DrawTexturedRect(w / 2 - dw / 2, UI.ContentY + vfH / 2 - dh / 2, dw, dh)

	draw.SimpleText("saved: " .. UI.PhotoCount, "ZPhone_Small", UI.Pad + 20, UI.ContentY + 20, T.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local bw, bh = 96, 36
	local bx, by = w - UI.Pad - 20 - bw, UI.ContentY + 14
	draw.RoundedBox(12, bx, by, bw, bh, Color(0, 0, 0, 150))
	draw.SimpleText(UI.CamFront and "front" or "rear", "ZPhone_Small", bx + bw / 2, by + bh / 2, T.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	UI.Btn(bx, by, bw, bh, function()
		UI.CamFront = not UI.CamFront
		UI.PlaySound("tap")
	end)

	draw.RoundedBox(60, w / 2 - 60, shutterY, 120, 120, T.text)
	draw.RoundedBox(48, w / 2 - 48, shutterY + 12, 96, 96, Color(210, 210, 220))
	UI.Btn(w / 2 - 60, shutterY, 120, 120, function()
		UI.ShutterPending = true
		UI.PlaySound("shutter", 45, 100, 0.6)
	end)
end

ZPHONE.AppDraw.camera = function(w, h)
	local ok, err = pcall(drawCamera, w, h)
	if not ok then
		warnOnce(err)
		draw.SimpleText("camera had a problem", "ZPhone_Small", w / 2, h / 2, T.faint, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end
