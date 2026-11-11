ZPHONE = ZPHONE or {}

if SERVER then
	AddCSLuaFile("zphone/sh_config.lua")
	AddCSLuaFile("zphone/cl_zphone_anim.lua")
	AddCSLuaFile("zphone/cl_zphone_keyboard.lua")
	AddCSLuaFile("zphone/cl_zphone_prefs.lua")
	AddCSLuaFile("zphone/cl_zphone_wallpaper.lua")
	AddCSLuaFile("zphone/cl_zphone_ui.lua")
	AddCSLuaFile("zphone/cl_zphone_apps.lua")
	AddCSLuaFile("zphone/cl_zphone_settings.lua")
	AddCSLuaFile("zphone/cl_zphone_camera.lua")
	AddCSLuaFile("zphone/cl_zphone_feed.lua")
	AddCSLuaFile("zphone/cl_zphone_typing.lua")
	AddCSLuaFile("zphone/cl_zphone_tuner.lua")
	AddCSLuaFile("zphone/cl_zphone_acc.lua")
	AddCSLuaFile("zphone/cl_zphone_map.lua")

	include("zphone/sh_config.lua")
	include("zphone/sv_zphone.lua")
else
	include("zphone/sh_config.lua")
	include("zphone/cl_zphone_ui.lua") 
	include("zphone/cl_zphone_tuner.lua")
	include("zphone/cl_zphone_acc.lua")
end
