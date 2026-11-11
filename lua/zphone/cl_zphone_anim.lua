ZPHONE = ZPHONE or {}
ZPHONE.Anim = ZPHONE.Anim or {}
local A = ZPHONE.Anim

A.Running = A.Running or {}

A.Defaults = ZPHONE.AnimDefaults
A.Ease = ZPHONE.Ease

A.Order = { "pull", "raise", "lower", "unlock", "lock", "appOpen", "homeIn", "notifyIn", "notifyOut", "kb", "call", "toast", "press" }

local function clamp01(x) return math.Clamp(x, 0, 1) end

function A.Settings(name)
	return ZPHONE.AnimSettings(name, ZPHONE.Tuning)
end

function A.Play(name)
	local s = ZPHONE.AnimSettings(name, ZPHONE.Tuning)
	A.Running[name] = {
		t0 = CurTime(),
		dur = ZPHONE.AnimPlayDur(name, ZPHONE.Tuning),
		ease = s.ease,
		c = s.c,
	}
end

function A.Get(name)
	local r = A.Running[name]
	if not r then return 1 end
	local t = clamp01((CurTime() - r.t0) / r.dur)
	if t >= 1 then
		A.Running[name] = nil
		return 1
	end
	local f = ZPHONE.Ease[r.ease] or ZPHONE.Ease.outCubic
	return f(t, r.c)
end

function A.IsRunning(name)
	return A.Running[name] ~= nil
end

function A.Curve(name, t)
	local s = A.Settings(name)
	local f = ZPHONE.Ease[s.ease] or ZPHONE.Ease.outCubic
	return f(clamp01(t), s.c)
end

function A.Layer(ox, oy, s, dx, dy, alpha, fn)
	local m = Matrix()
	m:Translate(Vector(ox + dx, oy + dy, 0))
	m:Scale(Vector(s, s, 1))
	m:Translate(Vector(-ox, -oy, 0))
	cam.PushModelMatrix(m)
	surface.SetAlphaMultiplier(clamp01(alpha))
	fn()
	surface.SetAlphaMultiplier(1)
	cam.PopModelMatrix()
end
