ZPHONE.Tuner = ZPHONE.Tuner or {}
local Tuner = ZPHONE.Tuner
local FILE = "zphone_tuning.json"
local STAGES = { "pocket", "stomach", "face" }

local HOLD_STAGES = { "pocket", "stomach", "face", "camera" }
local EASES = { "outCubic", "inOutCubic", "inCubic", "outExpo", "outBack", "linear" }

ZPHONE.Tuning = ZPHONE.Tuning or {}
ZPHONE.Tuning.hold = ZPHONE.Tuning.hold or ZPHONE.Clone(ZPHONE.Config.DefaultHold)
ZPHONE.Tuning.grip = ZPHONE.Tuning.grip or ZPHONE.Clone(ZPHONE.Config.DefaultGrip)
ZPHONE.Tuning.screen = ZPHONE.Tuning.screen or ZPHONE.Clone(ZPHONE.Config.DefaultScreen)
ZPHONE.Tuning.anim = ZPHONE.Tuning.anim or {}
ZPHONE.Tuning.statusbar = ZPHONE.Tuning.statusbar or ZPHONE.Clone(ZPHONE.Config.DefaultStatusBar)
ZPHONE.Tuning.animSpeed = ZPHONE.Tuning.animSpeed or 1
ZPHONE.Tuning.fingerBase = ZPHONE.Tuning.fingerBase or ZPHONE.Clone(ZPHONE.Config.DefaultFingers.base) 
ZPHONE.Tuning.fingerOff = ZPHONE.Tuning.fingerOff or ZPHONE.Clone(ZPHONE.Config.DefaultFingers.off) 

ZPHONE.Fingers = ZPHONE.Fingers or {
	{ "ValveBiped.Bip01_R_Finger0", "ValveBiped.Bip01_R_Finger01", "ValveBiped.Bip01_R_Finger02" }, -- thumb
	{ "ValveBiped.Bip01_R_Finger1", "ValveBiped.Bip01_R_Finger11", "ValveBiped.Bip01_R_Finger12" }, -- index
	{ "ValveBiped.Bip01_R_Finger2", "ValveBiped.Bip01_R_Finger21", "ValveBiped.Bip01_R_Finger22" }, -- middle
	{ "ValveBiped.Bip01_R_Finger3", "ValveBiped.Bip01_R_Finger31", "ValveBiped.Bip01_R_Finger32" }, -- ring
	{ "ValveBiped.Bip01_R_Finger4", "ValveBiped.Bip01_R_Finger41", "ValveBiped.Bip01_R_Finger42" }, -- pinky
}

local function vecToTbl(v) return { x = v.x, y = v.y, z = v.z } end
local function angToTbl(a) return { p = a.p, y = a.y, r = a.r } end
local function tblToVec(t) return Vector(t and t.x or 0, t and t.y or 0, t and t.z or 0) end
local function tblToAng(t) return Angle(t and t.p or 0, t and t.y or 0, t and t.r or 0) end

local function serialize()
	local out = { hold = {}, grip = {}, screen = {}, anim = {} }
	for _, name in ipairs(HOLD_STAGES) do
		local pose = ZPHONE.Tuning.hold[name]
		out.hold[name] = { pos = vecToTbl(pose.pos), ang = angToTbl(pose.ang) }
	end
	out.grip = { pos = vecToTbl(ZPHONE.Tuning.grip.pos), ang = angToTbl(ZPHONE.Tuning.grip.ang) }
	local s = ZPHONE.Tuning.screen
	out.screen = { pos = vecToTbl(s.pos), ang = angToTbl(s.ang), w = s.w, h = s.h }
	out.animSpeed = ZPHONE.Tuning.animSpeed
	out.statusbar = ZPHONE.Clone(ZPHONE.Tuning.statusbar)
	for name, a in pairs(ZPHONE.Tuning.anim) do
		out.anim[name] = { dur = a.dur, ease = a.ease, c = a.c, arc = a.arc }
	end

	out.fingers = { base = {}, off = {} }
	for stage, bones in pairs(ZPHONE.Tuning.fingerBase) do
		out.fingers.base[stage] = {}
		for name, b in pairs(bones) do
			out.fingers.base[stage][name] = { pos = vecToTbl(b.pos), ang = angToTbl(b.ang) }
		end
	end
	for stage, offs in pairs(ZPHONE.Tuning.fingerOff) do
		out.fingers.off[stage] = {}
		for name, a in pairs(offs) do
			out.fingers.off[stage][name] = angToTbl(a)
		end
	end
	return out
end

function Tuner.Save()
	file.Write(FILE, util.TableToJSON(serialize(), true))
	chat.AddText(Color(120, 200, 255), "[zphone] tuning saved to data/" .. FILE)
	Tuner.SendCfg()
end

function Tuner.SendCfg()
	local anim = {}
	for _, name in ipairs(ZPHONE.BlendOrder) do
		local s = ZPHONE.AnimSettings(name, ZPHONE.Tuning)
		anim[name] = { dur = s.dur, ease = s.ease, c = s.c, arc = s.arc }
	end
	net.Start("ZPhoneAnimCfg")
		net.WriteTable({ anim = anim, animSpeed = ZPHONE.Tuning.animSpeed })
	net.SendToServer()
end

hook.Add("InitPostEntity", "ZPhone_SendAnimCfg", function()
	timer.Simple(2, Tuner.SendCfg)
end)

function Tuner.Load()
	local raw = file.Read(FILE, "DATA")
	if not raw then return end
	local t = util.JSONToTable(raw)
	if not t then
		MsgC(Color(255, 100, 100), "[zphone] tuning file is busted, using defaults\n")
		return
	end

	for _, name in ipairs(HOLD_STAGES) do
		local saved = t.hold and t.hold[name]
		if saved then
			ZPHONE.Tuning.hold[name] = { pos = tblToVec(saved.pos), ang = tblToAng(saved.ang) }
		end
	end
	if t.grip then
		ZPHONE.Tuning.grip = { pos = tblToVec(t.grip.pos), ang = tblToAng(t.grip.ang) }
	end
	if t.screen then
		ZPHONE.Tuning.screen = {
			pos = tblToVec(t.screen.pos),
			ang = tblToAng(t.screen.ang),
			w = t.screen.w or 3.8,
			h = t.screen.h or 7.8,
		}
	end
	if t.anim then
		for name, a in pairs(t.anim) do
			ZPHONE.Tuning.anim[name] = { dur = tonumber(a.dur), ease = a.ease, c = tonumber(a.c), arc = tonumber(a.arc) }
		end
	end
	if t.animSpeed then
		ZPHONE.Tuning.animSpeed = tonumber(t.animSpeed) or 1
	end
	if t.statusbar then
		local s = t.statusbar
		ZPHONE.Tuning.statusbar = {
			time = { x = tonumber((s.time or {}).x) or 0, y = tonumber((s.time or {}).y) or 0 },
			battery = { x = tonumber((s.battery or {}).x) or 0, y = tonumber((s.battery or {}).y) or 0 },
		}
	end
	if t.fingers then
		ZPHONE.Tuning.fingerBase = {}
		for stage, bones in pairs(t.fingers.base or {}) do
			ZPHONE.Tuning.fingerBase[stage] = {}
			for name, b in pairs(bones) do
				ZPHONE.Tuning.fingerBase[stage][name] = { pos = tblToVec(b.pos), ang = tblToAng(b.ang) }
			end
		end
		ZPHONE.Tuning.fingerOff = {}
		for stage, offs in pairs(t.fingers.off or {}) do
			ZPHONE.Tuning.fingerOff[stage] = {}
			for name, a in pairs(offs) do
				ZPHONE.Tuning.fingerOff[stage][name] = tblToAng(a)
			end
		end
	end
end

function Tuner.Reset()
	ZPHONE.Tuning.hold = ZPHONE.Clone(ZPHONE.Config.DefaultHold)
	ZPHONE.Tuning.grip = ZPHONE.Clone(ZPHONE.Config.DefaultGrip)
	ZPHONE.Tuning.screen = ZPHONE.Clone(ZPHONE.Config.DefaultScreen)
	ZPHONE.Tuning.anim = {}
	ZPHONE.Tuning.animSpeed = 1
	ZPHONE.Tuning.fingerBase = ZPHONE.Clone(ZPHONE.Config.DefaultFingers.base)
	ZPHONE.Tuning.fingerOff = ZPHONE.Clone(ZPHONE.Config.DefaultFingers.off)
	ZPHONE.Tuning.statusbar = ZPHONE.Clone(ZPHONE.Config.DefaultStatusBar)
	ZPHONE.SetOrient(ZPHONE.DefaultOrient)
end

Tuner.Load()

local function clearCanvas(scroll)
	for _, c in ipairs(scroll:GetCanvas():GetChildren()) do
		c:Remove()
	end
end

local function addVecSliders(scroll, title, vec, range)
	local axes = { "x", "y", "z" }
	for i = 1, 3 do
		local s = vgui.Create("DNumSlider", scroll)
		s:Dock(TOP)
		s:DockMargin(0, 2, 0, 2)
		s:SetText(title .. " " .. axes[i])
		s:SetMin(-range)
		s:SetMax(range)
		s:SetDecimals(2)
		s:SetValue(vec[i])
		local idx = i
		function s:OnValueChanged(v)
			vec[idx] = v
		end
	end
end

local function addAngSliders(scroll, title, ang)
	local axes = { "pitch", "yaw", "roll" }
	for i = 1, 3 do
		local s = vgui.Create("DNumSlider", scroll)
		s:Dock(TOP)
		s:DockMargin(0, 2, 0, 2)
		s:SetText(title .. " " .. axes[i])
		s:SetMin(-180)
		s:SetMax(180)
		s:SetDecimals(1)
		s:SetValue(ang[i])
		local idx = i
		function s:OnValueChanged(v)
			ang[idx] = v
		end
	end
end

local function addScalarSlider(scroll, label, tbl, key, min, max)
	local s = vgui.Create("DNumSlider", scroll)
	s:Dock(TOP)
	s:DockMargin(0, 2, 0, 2)
	s:SetText(label)
	s:SetMin(min)
	s:SetMax(max)
	s:SetDecimals(2)
	s:SetValue(tbl[key])
	function s:OnValueChanged(v)
		tbl[key] = v
	end
end

local function entryFor(name)
	local T = ZPHONE.Tuning.anim
	if not T[name] then
		local s = ZPHONE.Anim.Settings(name)
		T[name] = { dur = s.dur, ease = s.ease, c = s.c, arc = s.arc }
	end
	return T[name]
end

local function buildAnim(scroll)
	local current = ZPHONE.Anim.Order[1]
	local sp = vgui.Create("DNumSlider", scroll)
	sp:Dock(TOP)
	sp:DockMargin(0, 2, 0, 8)
	sp:SetText("global speed (x)")
	sp:SetMin(0.25)
	sp:SetMax(3)
	sp:SetDecimals(2)
	sp:SetValue(ZPHONE.Tuning.animSpeed)
	function sp:OnValueChanged(v)
		ZPHONE.Tuning.animSpeed = v
	end

	local pick = vgui.Create("DComboBox", scroll)
	pick:Dock(TOP)
	pick:DockMargin(0, 2, 0, 6)
	pick:SetValue("animation")
	for _, name in ipairs(ZPHONE.Anim.Order) do pick:AddChoice(name) end
	local graph = vgui.Create("DPanel", scroll)
	graph:Dock(TOP)
	graph:SetTall(150)
	graph:DockMargin(0, 2, 0, 8)
	graph.Paint = function(self, pw, ph)
		draw.RoundedBox(6, 0, 0, pw, ph, Color(20, 20, 26))
		local pad = 12
		local function yOf(v) return ph - pad - v * (ph - pad * 2) end

		surface.SetDrawColor(60, 60, 70, 255)
		surface.DrawLine(pad, yOf(0), pw - pad, yOf(0))
		surface.DrawLine(pad, yOf(1), pw - pad, yOf(1))

		surface.SetDrawColor(120, 200, 255, 255)
		local px, py
		for i = 0, 80 do
			local t = i / 80
			local v = ZPHONE.Anim.Curve(current, t)
			local x = pad + t * (pw - pad * 2)
			local y = yOf(v)
			if px then surface.DrawLine(px, py, x, y) end
			px, py = x, y
		end
	end

	local ease = vgui.Create("DComboBox", scroll)
	ease:Dock(TOP)
	ease:DockMargin(0, 2, 0, 2)
	ease:SetValue("easing")
	for _, e in ipairs(EASES) do ease:AddChoice(e) end

	local dur = vgui.Create("DNumSlider", scroll)
	dur:Dock(TOP)
	dur:DockMargin(0, 2, 0, 2)
	dur:SetText("duration (s)")
	dur:SetMin(0.05)
	dur:SetMax(2)
	dur:SetDecimals(2)

	local over = vgui.Create("DNumSlider", scroll)
	over:Dock(TOP)
	over:DockMargin(0, 2, 0, 2)
	over:SetText("overshoot (outBack only)")
	over:SetMin(0)
	over:SetMax(4)
	over:SetDecimals(2)

	local arc = vgui.Create("DNumSlider", scroll)
	arc:Dock(TOP)
	arc:DockMargin(0, 2, 0, 2)
	arc:SetText("lift (phone motion only)")
	arc:SetMin(-12)
	arc:SetMax(12)
	arc:SetDecimals(2)

	local function loadControls()
		local s = ZPHONE.Anim.Settings(current)
		for i, e in ipairs(EASES) do
			if e == s.ease then ease:ChooseOptionID(i) end
		end
		dur:SetValue(s.dur)
		over:SetValue(s.c or ZPHONE.Anim.Defaults[current].c or 1.70158)
		arc:SetValue(s.arc or 0)
	end

	function pick:OnSelect(idx, value)
		current = value
		loadControls()
	end

	function ease:OnSelect(idx, value)
		entryFor(current).ease = value
	end

	function dur:OnValueChanged(v)
		entryFor(current).dur = v
	end

	function over:OnValueChanged(v)
		entryFor(current).c = v
	end

	function arc:OnValueChanged(v)
		entryFor(current).arc = v
	end

	local play = vgui.Create("DButton", scroll)
	play:Dock(TOP)
	play:DockMargin(0, 6, 0, 2)
	play:SetTall(36)
	play:SetText("play on phone")
	function play:DoClick()
		if current == "pull" or current == "raise" or current == "lower" then
			chat.AddText(Color(120, 200, 255), "[zphone] to see " .. current .. ": take the phone out (hold RMB to raise, let go to lower)")
			return
		end
		ZPHONE.Anim.Play(current)
	end

	local reset = vgui.Create("DButton", scroll)
	reset:Dock(TOP)
	reset:DockMargin(0, 2, 0, 2)
	reset:SetTall(30)
	reset:SetText("reset this animation")
	function reset:DoClick()
		ZPHONE.Tuning.anim[current] = nil
		loadControls()
	end

	local tip = vgui.Create("DLabel", scroll)
	tip:Dock(TOP)
	tip:DockMargin(4, 8, 4, 4)
	tip:SetWrap(true)
	tip:SetAutoStretchVertical(true)
	tip:SetTextColor(Color(160, 160, 170))
	tip:SetText("smoother: longer duration with outCubic or inOutCubic. bouncy: outBack with overshoot around 1.2 to 2. lift bows the hand up while the phone comes out, so it doesn't cut through the body. pull / raise / lower are the phone's own motion. global speed scales all of them.")

	pick:ChooseOptionID(1)
	loadControls()
end

local FINGER_NAMES = { "thumb", "index", "middle", "ring", "pinky" }
local JOINT_NAMES = { "knuckle", "middle joint", "tip" }
local fingerStage = "stomach"
local fingerNow = 1

local function buildFingers(scroll, rebuild)
	ZPHONE.Tuning.fingerPreview = fingerStage

	local stageBox = vgui.Create("DComboBox", scroll)
	stageBox:Dock(TOP)
	stageBox:DockMargin(0, 2, 0, 6)
	stageBox:SetValue("stage")
	local stageIdx = 2
	for i, s in ipairs(STAGES) do
		stageBox:AddChoice(s)
		if s == fingerStage then stageIdx = i end
	end
	stageBox:ChooseOptionID(stageIdx)
	function stageBox:OnSelect(idx, value)
		fingerStage = value
		rebuild()
	end

	local status = vgui.Create("DLabel", scroll)
	status:Dock(TOP)
	status:DockMargin(4, 2, 4, 6)
	status:SetWrap(true)
	status:SetAutoStretchVertical(true)
	local function refreshStatus()
		if not IsValid(status) then return end
		if ZPHONE.Tuning.fingerBase[fingerStage] then
			status:SetText("captured. the bend sliders move the fingers from that pose")
			status:SetTextColor(Color(120, 220, 150))
		else
			status:SetText("not captured yet. stand still, phone out, then press capture")
			status:SetTextColor(Color(255, 180, 120))
		end
	end
	refreshStatus()

	local cap = vgui.Create("DButton", scroll)
	cap:Dock(TOP)
	cap:DockMargin(0, 2, 0, 6)
	cap:SetTall(36)
	cap:SetText("capture fingers for " .. fingerStage)
	function cap:DoClick()
		ZPHONE.Tuning.fingerCapture = fingerStage
		timer.Simple(0.3, refreshStatus)
	end

	local fingerBox = vgui.Create("DComboBox", scroll)
	fingerBox:Dock(TOP)
	fingerBox:DockMargin(0, 2, 0, 6)
	fingerBox:SetValue("finger")
	for i, n in ipairs(FINGER_NAMES) do fingerBox:AddChoice(n) end
	fingerBox:ChooseOptionID(fingerNow)
	function fingerBox:OnSelect(idx)
		fingerNow = idx
		rebuild()
	end

	local offs = ZPHONE.Tuning.fingerOff
	offs[fingerStage] = offs[fingerStage] or {}
	local chain = ZPHONE.Fingers[fingerNow]
	for j, name in ipairs(chain) do
		local ang = offs[fingerStage][name] or Angle(0, 0, 0)
		offs[fingerStage][name] = ang
		addAngSliders(scroll, FINGER_NAMES[fingerNow] .. " " .. JOINT_NAMES[j], ang)
	end
end

local function buildGroup(scroll, group)
	clearCanvas(scroll)
	if group == "pocket" or group == "stomach" or group == "face" then
		ZPHONE.Tuning.fingerPreview = group
	end

	ZPHONE.Tuning.camPreview = group == "camera" or nil
	if group == "camera" then ZPHONE.Tuning.fingerPreview = "face" end

	if group == "grip" then
		addVecSliders(scroll, "grip pos", ZPHONE.Tuning.grip.pos, 30)
		addAngSliders(scroll, "grip ang", ZPHONE.Tuning.grip.ang)
	elseif group == "screen" then
		local sc = ZPHONE.Tuning.screen

		local dc = vgui.Create("DComboBox", scroll)
		dc:Dock(TOP)
		dc:DockMargin(0, 2, 0, 6)
		dc:SetValue("orientation")
		local cur = ZPHONE.Tuning.orient
		local selected = 1
		for i, opt in ipairs(ZPHONE.OrientOptions) do
			dc:AddChoice(opt.label)
			if opt.rot == cur.rot and opt.fx == cur.fx and opt.fy == cur.fy then selected = i end
		end
		dc:ChooseOptionID(selected)
		function dc:OnSelect(idx)
			local opt = ZPHONE.OrientOptions[idx]
			if not opt then return end
			local c = ZPHONE.Tuning.orient
			if opt.rot == c.rot and opt.fx == c.fx and opt.fy == c.fy then return end
			ZPHONE.SetOrient(opt)
		end

		local flip = vgui.Create("DButton", scroll)
		flip:Dock(TOP)
		flip:DockMargin(0, 2, 0, 6)
		flip:SetTall(32)
		flip:SetText("flip screen 180 degrees")
		function flip:DoClick()
			sc.ang.y = sc.ang.y + 180
			sc.ang:Normalize()
			buildGroup(scroll, "screen")
		end

		addVecSliders(scroll, "screen pos", sc.pos, 15)
		addAngSliders(scroll, "screen ang", sc.ang)
		addScalarSlider(scroll, "screen width", sc, "w", 0.5, 20)
		addScalarSlider(scroll, "screen height", sc, "h", 0.5, 30)
	elseif group == "camera" then
		local lbl = vgui.Create("DLabel", scroll)
		lbl:Dock(TOP)
		lbl:DockMargin(4, 2, 4, 6)
		lbl:SetWrap(true)
		lbl:SetAutoStretchVertical(true)
		lbl:SetText("the pose the phone eases to while the camera app is open. raise it (hold RMB) to see it here")
		local pose = ZPHONE.Tuning.hold.camera
		addVecSliders(scroll, "camera pos", pose.pos, 40)
		addAngSliders(scroll, "camera ang", pose.ang)
	elseif group == "statusbar" then
		local sb = ZPHONE.Tuning.statusbar
		addScalarSlider(scroll, "time x", sb.time, "x", -80, 80)
		addScalarSlider(scroll, "time y", sb.time, "y", -60, 60)
		addScalarSlider(scroll, "battery x", sb.battery, "x", -80, 80)
		addScalarSlider(scroll, "battery y", sb.battery, "y", -60, 60)
	elseif group == "fingers" then
		buildFingers(scroll, function() buildGroup(scroll, "fingers") end)
	elseif group == "anim" then
		buildAnim(scroll)
	else
		local pose = ZPHONE.Tuning.hold[group]
		addVecSliders(scroll, group .. " pos", pose.pos, 40)
		addAngSliders(scroll, group .. " ang", pose.ang)
	end
end

function Tuner.Open()
	if IsValid(Tuner.Frame) then Tuner.Frame:Remove() end

	local fr = vgui.Create("DFrame")
	fr:SetTitle("zphone tuner — the phone is a little bit cursed")
	fr:SetSize(440, 780)
	fr:Center()
	fr:MakePopup()
	Tuner.Frame = fr
	function fr:OnClose()
		ZPHONE.Tuning.fingerPreview = nil
		ZPHONE.Tuning.camPreview = nil
	end

	local current = "stomach"

	local combo = vgui.Create("DComboBox", fr)
	combo:Dock(TOP)
	combo:DockMargin(8, 6, 8, 0)
	local groups = { "pocket", "stomach", "face", "camera", "grip", "fingers", "screen", "statusbar", "anim" }
	for _, g in ipairs(groups) do combo:AddChoice(g) end

	local scroll = vgui.Create("DScrollPanel", fr)
	scroll:Dock(FILL)
	scroll:DockMargin(8, 6, 8, 6)

	local bottom = vgui.Create("DPanel", fr)
	bottom:Dock(BOTTOM)
	bottom:SetTall(44)
	bottom:DockMargin(8, 0, 8, 8)
	bottom.Paint = function() end

	local function btn(text, x, fn, col)
		local b = vgui.Create("DButton", bottom)
		b:SetPos(x, 0)
		b:SetSize(120, 40)
		b:SetText(text)
		b.DoClick = fn
		if col then b:SetColor(col) end
		return b
	end

	btn("save", 0, function() Tuner.Save() end, Color(120, 220, 150))
	btn("reset", 130, function()
		Tuner.Reset()
		buildGroup(scroll, current)
	end)
	btn("print", 260, function()
		PrintTable(serialize())
	end)

	function combo:OnSelect(idx, value)
		current = value
		buildGroup(scroll, value)
	end
	combo:ChooseOptionID(2)
	buildGroup(scroll, current)
end

hook.Add("PostDrawTranslucentRenderables", "ZPhone_TunerScreenBox", function()
	if not IsValid(Tuner.Frame) then return end

	local ply = LocalPlayer()
	if not IsValid(ply) then return end
	local wep = ply:GetActiveWeapon()
	if not (IsValid(wep) and wep.isZPhone and wep.GetPhoneTransform) then return end

	local pos, ang = wep:GetPhoneTransform()
	if not pos then return end

	local s = ZPHONE.Tuning.screen
	local origin, sang = LocalToWorld(s.pos, s.ang, pos, ang)

	render.DrawWireframeBox(origin, sang, Vector(-0.2, -s.w / 2, -s.h / 2), Vector(0.2, s.w / 2, s.h / 2), Color(60, 255, 120), true)
	-- red stick pointing out of the screen, so you can tell which way the screen faces
	render.DrawLine(origin, origin + sang:Forward() * 8, Color(255, 80, 80), true)
end)

concommand.Add("zphone_tune", function()
	Tuner.Open()
end)

concommand.Add("zphone_tune_print", function()
	PrintTable(serialize())
end)
