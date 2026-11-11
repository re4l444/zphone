include("shared.lua")

SWEP.PrintName = "Phone"
SWEP.BounceWeaponIcon = false

function SWEP:DrawWorldModel()
end

local function getPhoneModel(wep)
	if not IsValid(wep.PhoneCSM) then
		wep.PhoneCSM = ClientsideModel(ZPHONE.Config.Model, RENDERGROUP_OPAQUE)
		wep.PhoneCSM:SetNoDraw(true)
	end
	return wep.PhoneCSM
end

function SWEP:OnRemove()
	if IsValid(self.PhoneCSM) then self.PhoneCSM:Remove() end
end

function SWEP:GetHandWorld(ent, blend)
	local chestIdx = ent:LookupBone(self.ChestBone)
	if not chestIdx then return end
	local cm = ent:GetBoneMatrix(chestIdx)
	if not cm then return end
	local pos, ang = self:GetPoseAt(blend)
	return LocalToWorld(pos, ang, cm:GetTranslation(), cm:GetAngles())
end

function SWEP:SetHandPos(fromHook)
	local ply = self:GetOwner()
	if not IsValid(ply) or not ply:IsPlayer() then return end

	local ent = hg.GetCurrentCharacter(ply)
	if not IsValid(ent) then return end

	local rhIdx = ent:LookupBone(self.RightHandBone)
	if not rhIdx then return end
	local hm = ent:GetBoneMatrix(rhIdx)
	if not hm then return end

	local wpos, wang = self:GetHandWorld(ent, self.Blend or 0)
	if not wpos then return end

	hm:SetTranslation(wpos)
	hm:SetAngles(wang)
	hg.bone_apply_matrix(ent, rhIdx, hm)

	if not fromHook and ply == LocalPlayer() then
		self:FingerStep(ent, rhIdx, hm)
	end

	self.rhandik = true
	self.lhandik = false
	return hm
end

local FINGER_STAGES = { "pocket", "stomach", "face" }

local function stageFingers(stage)
	local base = ZPHONE.Tuning.fingerBase and ZPHONE.Tuning.fingerBase[stage]
	if not base then return end
	local off = ZPHONE.Tuning.fingerOff and ZPHONE.Tuning.fingerOff[stage] or {}

	local out = {}
	for _, chain in ipairs(ZPHONE.Fingers or {}) do
		local parent = Matrix()
		for _, name in ipairs(chain) do
			local b = base[name]
			if not b then return end
			local loc = Matrix()
			loc:SetTranslation(b.pos)
			loc:SetAngles(b.ang)
			local bend = Matrix()
			bend:SetAngles(off[name] or Angle(0, 0, 0))
			local m = parent * loc * bend
			out[name] = m
			parent = m
		end
	end
	return out
end

local function captureFingers(ent, rhIdx, stage)
	local handM = ent:GetBoneMatrix(rhIdx)
	local invHand = handM and handM:GetInverse()
	if not invHand then return false end

	local base = {}
	for _, chain in ipairs(ZPHONE.Fingers or {}) do
		local prevInv = Matrix()
		for _, name in ipairs(chain) do
			local idx = ent:LookupBone(name)
			local m = idx and idx >= 0 and ent:GetBoneMatrix(idx)
			if not m then return false end
			local rel = invHand * m
			local loc = prevInv * rel
			base[name] = { pos = loc:GetTranslation(), ang = loc:GetAngles() }
			prevInv = rel:GetInverse()
			if not prevInv then return false end
		end
	end

	ZPHONE.Tuning.fingerBase = ZPHONE.Tuning.fingerBase or {}
	ZPHONE.Tuning.fingerBase[stage] = base
	return true
end

function SWEP:SetFingerPos(ent, hm, blend)
	if not hm then return end
	local pinned = ZPHONE.Tuning.fingerPreview
	if pinned then
		local M = stageFingers(pinned)
		if not M then return end
		for name, m in pairs(M) do
			local idx = ent:LookupBone(name)
			if idx and idx >= 0 then ent:SetBoneMatrix(idx, hm * m) end
		end
		return
	end

	local b = math.Clamp(blend, 0, 2)
	local a, c, t
	if b <= 1 then a, c, t = 1, 2, b else a, c, t = 2, 3, b - 1 end

	local A = stageFingers(FINGER_STAGES[a]) or stageFingers(FINGER_STAGES[c])
	if not A then return end
	local B = stageFingers(FINGER_STAGES[c]) or A

	for name, ma in pairs(A) do
		local mb = B[name]
		if not mb then continue end
		local m = Matrix()
		m:SetTranslation(LerpVector(t, ma:GetTranslation(), mb:GetTranslation()))
		m:SetAngles(LerpAngle(t, ma:GetAngles(), mb:GetAngles()))
		local idx = ent:LookupBone(name)
		if idx and idx >= 0 then ent:SetBoneMatrix(idx, hm * m) end
	end
end

function SWEP:FingerStep(ent, rhIdx, hm)
	local stage = ZPHONE.Tuning.fingerCapture
	if stage then
		ZPHONE.Tuning.fingerCapture = nil
		if captureFingers(ent, rhIdx, stage) then
			chat.AddText(Color(120, 200, 255), "[zphone] fingers captured for " .. stage)
		else
			chat.AddText(Color(255, 120, 120), "[zphone] couldn't read the fingers, try again")
		end
	end

	self:SetFingerPos(ent, hm, self.Blend or 0)
end

local function getPhoneTransform(wep)
	local ply = wep:GetOwner()
	if not IsValid(ply) then return end
	local ent = hg.GetCurrentCharacter(ply)
	if not IsValid(ent) then return end

	local blend
	if ply == LocalPlayer() then
		blend = wep.Blend or 0
	else
		blend = wep:GetNWFloat("zphone_blend", 0)
	end

	if blend < 0.2 then return end

	local hpos, hang = wep:GetHandWorld(ent, blend)
	if not hpos then return end

	local g = ZPHONE.Tuning.grip
	return LocalToWorld(g.pos, g.ang, hpos, hang)
end

function SWEP:GetPhoneTransform()
	return getPhoneTransform(self)
end

function SWEP:ZPhoneDraw()
	local ply = self:GetOwner()
	if not IsValid(ply) then return end

	if ply == LocalPlayer() then
		self:SetHandPos(true)
	end

	local pos, ang = getPhoneTransform(self)
	if not pos then return end

	if ply == LocalPlayer() and (ZPHONE.VibrateUntil or 0) > CurTime() then
		pos = pos + VectorRand() * 0.2
	end

	local csm = getPhoneModel(self)
	csm:SetPos(pos)
	csm:SetAngles(ang)
	local screenMat = (ply == LocalPlayer()) and ZPHONE.ScreenMatLocal or ZPHONE.ScreenMatIdle
	if screenMat then
		csm:SetSubMaterial(ZPHONE.Config.ScreenSubMaterial, "!" .. screenMat:GetName())
	end

	csm:DrawModel()
end

hook.Add("PostDrawTranslucentRenderables", "ZPhone_DrawPhones", function()
	for _, ply in ipairs(player.GetAll()) do
		if not IsValid(ply) then continue end
		local wep = ply:GetActiveWeapon()
		if IsValid(wep) and wep.isZPhone and wep.ZPhoneDraw then
			wep:ZPhoneDraw()
		end
	end
end)
