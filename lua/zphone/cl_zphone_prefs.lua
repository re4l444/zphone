ZPHONE.Prefs = ZPHONE.Prefs or {}
local P = ZPHONE.Prefs
local FILE = "zphone_settings.json"

P.Defaults = {
	wallpaper = "dusk",
	brightness = 1,   
	silent = false,    
	vibrate = true,    
	keyClicks = true,  
}

P.Values = P.Values or table.Copy(P.Defaults)

function P.Load()
	local raw = file.Read(FILE, "DATA")
	local t = raw and util.JSONToTable(raw)
	if not istable(t) then return end
	for k, default in pairs(P.Defaults) do
		if t[k] ~= nil and type(t[k]) == type(default) then P.Values[k] = t[k] end
	end
end

function P.Save()
	file.Write(FILE, util.TableToJSON(P.Values, true))
end

function P.Get(key)
	return P.Values[key]
end

function P.Set(key, value)
	P.Values[key] = value
	P.Save()
end

function ZPHONE.Vibrate()
	ZPHONE.VibrateUntil = CurTime() + 0.01
end

P.Load()
