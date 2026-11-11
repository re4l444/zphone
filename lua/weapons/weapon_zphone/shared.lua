if SERVER then AddCSLuaFile() end

SWEP.PrintName = "Phone"
SWEP.Author = "you, probably at 3am"
SWEP.Instructions = "LMB: tap screen (when raised). RMB: raise to face. Pocket it by switching weapons."
SWEP.Category = "ZCity Other"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.Slot = 1
SWEP.SlotPos = 5

SWEP.Weight = 0
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Ammo = "none"
SWEP.Primary.Automatic = false

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Ammo = "none"
SWEP.Secondary.Automatic = false
SWEP.HoldType = "normal"
SWEP.ViewModel = ""
SWEP.WorldModel = ZPHONE.Config.Model
SWEP.UseHands = false
SWEP.supportTPIK = true
SWEP.isZPhone = true

SWEP.ChestBone = "ValveBiped.Bip01_Spine4"
SWEP.RightHandBone = "ValveBiped.Bip01_R_Hand"

ZPHONE.Tuning = ZPHONE.Tuning or {}
ZPHONE.Tuning.hold = ZPHONE.Tuning.hold or ZPHONE.Clone(ZPHONE.Config.DefaultHold)
ZPHONE.Tuning.grip = ZPHONE.Tuning.grip or ZPHONE.Clone(ZPHONE.Config.DefaultGrip)
ZPHONE.Tuning.anim = ZPHONE.Tuning.anim or {}
ZPHONE.Tuning.animSpeed = ZPHONE.Tuning.animSpeed or 1

local function clampBlend(b)
	return math.Clamp(b, 0, 2)
end

local function segmentFor(from, to)
	if to > from then
		return (from < 1) and "pull" or "raise"
	end
	return "lower"
end

local function cfgFor(ply)
	if SERVER then
		return IsValid(ply) and ply.ZPhoneAnimCfg or nil
	end
	return ZPHONE.Tuning
end

function SWEP:Initialize()
	self:SetHoldType(self.HoldType)
	self.Blend = 0
	self.BlendTo = nil
	self.DeployTime = CurTime()
	self.Unlocked = self.Unlocked or false
end

function SWEP:Deploy()
	self:SetHoldType(self.HoldType)
	self.Blend = 0
	self.BlendTo = nil
	self.Latched = false
	self.Suppressed = false
	self.RMBWasDown = false
	self.SentTarget = nil 
	self.NetTarget = nil
	self.SentCam = nil
	self.NetCam = nil
	self.CamBlend = 0
	self.CamTo = nil
	self.DeployTime = CurTime()
	return true
end

function SWEP:Holster()
	self.Latched = false
	return true
end

function SWEP:RMBDown()
	local ply = self:GetOwner()
	if not IsValid(ply) then return false end
	if CLIENT and ply == LocalPlayer() and input.IsMouseDown(MOUSE_RIGHT) then return true end
	return ply:KeyDown(IN_ATTACK2)
end

function SWEP:UpdateLatch()
	local rmb = self:RMBDown()
	local lowered = false
	if rmb and not self.RMBWasDown and self.Latched then
		self.Latched = false
		self.Suppressed = true
		lowered = true
	end
	if not rmb then self.Suppressed = false end
	self.RMBWasDown = rmb
	if not lowered and not self.Suppressed and (self.Blend or 0) > 1.9 then
		self.Latched = true
	end
end

function SWEP:GetTargetBlend()
	local ply = self:GetOwner()
	if not IsValid(ply) then return 0 end
	if self.Latched then return 2 end
	if self:RMBDown() and not self.Suppressed then return 2 end
	return 1
end

function SWEP:Think()
	local ply = self:GetOwner()
	if not IsValid(ply) then return end

	local now = CurTime()
	local target, camWant
	if SERVER and self.NetTarget then
		target = self.NetTarget
		camWant = self.NetCam
	else
		self:UpdateLatch()
		target = self:GetTargetBlend()
		camWant = CLIENT and ply == LocalPlayer() and ((ZPHONE.UI and ZPHONE.UI.Screen == "camera") or ZPHONE.Tuning.camPreview) and true or false
		if CLIENT and ply == LocalPlayer() and (target ~= self.SentTarget or camWant ~= self.SentCam) then
			self.SentTarget = target
			self.SentCam = camWant
			net.Start("ZPhoneTarget")
			net.WriteUInt(target, 2)
			net.WriteBool(camWant)
			net.SendToServer()
		end
	end
	local cfg = cfgFor(ply)

	if self.BlendTo ~= target then
		local from = self.Blend or 0
		local name = segmentFor(from, target)
		local s = ZPHONE.AnimSettings(name, cfg)
		self.BlendFrom = from
		self.BlendTo = target
		self.BlendT0 = now
		self.BlendDur = ZPHONE.AnimPlayDur(name, cfg)
		self.BlendEase = s.ease
		self.BlendC = s.c
	end

	local t = math.Clamp((now - (self.BlendT0 or now)) / math.max(self.BlendDur or 0.001, 0.001), 0, 1)
	local f = ZPHONE.Ease[self.BlendEase] or ZPHONE.Ease.inOutCubic
	local k = f(t, self.BlendC)
	self.Blend = clampBlend(Lerp(k, self.BlendFrom or 0, self.BlendTo or target))

	local camTo = (camWant and target == 2) and 1 or 0
	if self.CamTo ~= camTo then
		self.CamFrom = self.CamBlend or 0
		self.CamTo = camTo
		self.CamT0 = now
	end
	local ct = math.Clamp((now - (self.CamT0 or now)) / ZPHONE.Config.Camera.holdDur, 0, 1)
	self.CamBlend = Lerp(ZPHONE.Ease.inOutCubic(ct), self.CamFrom or 0, self.CamTo or 0)

	if SERVER then
		self:SetNWFloat("zphone_blend", self.Blend)
		self:SetNWFloat("zphone_cam", self.CamBlend)
		self:SetNWFloat("zphone_arc", ZPHONE.AnimSettings("raise", cfg).arc or 0)
	end
end

function SWEP:GetArc()
	local ply = self:GetOwner()
	if CLIENT and IsValid(ply) and ply == LocalPlayer() then
		return ZPHONE.AnimSettings("raise", ZPHONE.Tuning).arc or 0
	end
	return self:GetNWFloat("zphone_arc", 0)
end

function SWEP:GetCamBlend()
	local ply = self:GetOwner()
	if SERVER or (CLIENT and IsValid(ply) and ply == LocalPlayer()) then return self.CamBlend or 0 end
	return self:GetNWFloat("zphone_cam", 0)
end

function SWEP:GetPoseAt(b)
	local H = ZPHONE.Tuning.hold
	local pos, ang, frac
	if b <= 1 then
		frac = math.Clamp(b, 0, 1)
		pos = LerpVector(b, H.pocket.pos, H.stomach.pos)
		ang = LerpAngle(b, H.pocket.ang, H.stomach.ang)
	else
		frac = math.Clamp(b - 1, 0, 1)
		pos = LerpVector(b - 1, H.stomach.pos, H.face.pos)
		ang = LerpAngle(b - 1, H.stomach.ang, H.face.ang)
	end

	local cb = self:GetCamBlend()
	if cb > 0 then
		pos = LerpVector(cb, pos, H.camera.pos)
		ang = LerpAngle(cb, ang, H.camera.ang)
	end

	local arc = self:GetArc()
	if arc ~= 0 then
		pos = pos + Vector(0, 0, arc * math.sin(math.pi * frac))
	end
	return pos, ang
end

function SWEP:IsRaised()
	return (self.Blend or 0) > 1.9
end

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + 0.12)
end

function SWEP:SecondaryAttack()
end

function SWEP:Reload()
	if CLIENT and ZPHONE.UI and ZPHONE.UI.Home then
		ZPHONE.UI.Home()
	end
end

if SERVER then
	util.AddNetworkString("ZPhoneAnimCfg")
	net.Receive("ZPhoneAnimCfg", function(len, ply)
		ply.ZPhoneAnimCfg = ZPHONE.SanitizeAnimCfg(net.ReadTable())
	end)
	
	util.AddNetworkString("ZPhoneTarget")
	net.Receive("ZPhoneTarget", function(len, ply)
		local wep = ply:GetActiveWeapon()
		if not (IsValid(wep) and wep.isZPhone) then return end
		local t = net.ReadUInt(2)
		local cam = net.ReadBool()
		if t == 1 or t == 2 then
			wep.NetTarget = t
			wep.NetCam = cam
		end
	end)
end
