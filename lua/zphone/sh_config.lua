-- zphone shared config. Anything tweakable lives here so you're not grepping through 2000 lines of UI code.
-- dev1: "just put it in the config" dev2: "which config" dev1: "this one" dev2: ok fine
-- shared on purpose: the server plays the phone-motion animations too, so the timing and easing have to exist on both sides

ZPHONE = ZPHONE or {}
ZPHONE.Config = ZPHONE.Config or {}
local C = ZPHONE.Config

C.Model = "models/sketchfab/3duae/iphone/skf_3duae_iphone_13_pro_2021.mdl"
C.ScreenSubMaterial = 7 -- the screen is submaterial 7. yes it's 7. no i don't know why. -- dev2
-- screen orientation (rotate / flip) is saved on its own, see cl_zphone_ui.lua (zphone_screen_orient.json)

-- render target for the screen. 9:19.5-ish ratio, the phone is tall, don't fight it
C.RTWidth = 512
C.RTHeight = 1024

-- deep copy that also copies Vectors and Angles. table.Copy shares those, so a slider edit would change the defaults too
function ZPHONE.Clone(v)
	if isvector(v) then return Vector(v.x, v.y, v.z) end
	if isangle(v) then return Angle(v.p, v.y, v.r) end
	if istable(v) then
		local t = {}
		for k, x in pairs(v) do t[k] = ZPHONE.Clone(x) end
		return t
	end
	return v
end

-- tuned defaults, baked from zphone_tune_print. the tuner saves over these in data/zphone_tuning.json,
-- and its reset button goes back to them. to re-bake after tuning again: run zphone_tune_print and replace this block.
-- hold poses are relative to the R hand/chest bone
C.DefaultHold = {
	pocket = { pos = Vector(-15.094553, 8.131868, -6.813187), ang = Angle(-180, -14, 0) },
	stomach = { pos = Vector(-9.007935, 10.795190, -5.404793), ang = Angle(-113.618813, -89.253868, 121.455475) },
	face = { pos = Vector(0.005037, 13.103325, -2.969471), ang = Angle(-128.117493, -159.902634, 167.011673) },
	-- the camera hold: the pose the phone eases to while the camera app is open. tuned in the tuner's camera tab
	camera = { pos = Vector(2.581138, 19.338837, -3.928310), ang = Angle(-128.197586, -176.075394, 160.012878) },
}
C.DefaultGrip = { pos = Vector(4.181792, -1.220199, -1.887101), ang = Angle(-10.669563, 92.588036, 140.352875) }
-- the screen's forward points out of the glass, toward you. the tuned position and size are baked. the angle is the 180 flip,
-- because the tuned dump was made before the flip and the old default pointed the screen into the phone
C.DefaultScreen = { pos = Vector(-0.010632, -0.004980, -0.219176), ang = Angle(0, 0, 0), w = 3.443339, h = 7.303903 }
-- status bar offsets, in screen pixels (the screen is 512 wide). the tuner's statusbar group moves these
C.DefaultStatusBar = { time = { x = 13.63, y = 0 }, battery = { x = 12.60, y = 0 } }

-- finger poses. base = the captured pose per joint (pos / ang relative to the joint's parent), off = the bend per joint
-- the stomach capture is the one baked here. pocket and face get copies of it below, so every hold uses the same fingers.
-- capture pocket or face in the tuner to give that hold its own fingers
C.DefaultFingers = {
	base = {
		stomach = {
			["ValveBiped.Bip01_R_Finger0"] = { pos = Vector(0.829, -0.325, -1.312), ang = Angle(15.163, -22.297, 80.982) },
			["ValveBiped.Bip01_R_Finger01"] = { pos = Vector(1.790, 0, 0), ang = Angle(0.511, 14.901, 0.013) },
			["ValveBiped.Bip01_R_Finger02"] = { pos = Vector(1.207, 0, 0), ang = Angle(0.744, 17.404, 0.018) },
			["ValveBiped.Bip01_R_Finger1"] = { pos = Vector(3.868, 0.042, -1.309), ang = Angle(-2.319, -15.155, -34.882) },
			["ValveBiped.Bip01_R_Finger11"] = { pos = Vector(1.719, 0, 0), ang = Angle(4.829, -16.930, -0.725) },
			["ValveBiped.Bip01_R_Finger12"] = { pos = Vector(1.100, 0, 0), ang = Angle(4.846, -16.930, -0.725) },
			["ValveBiped.Bip01_R_Finger2"] = { pos = Vector(3.882, 0.146, -0.409), ang = Angle(-1.999, -15.515, -8.399) },
			["ValveBiped.Bip01_R_Finger21"] = { pos = Vector(1.720, 0, 0), ang = Angle(1.291, -17.555, -0.197) },
			["ValveBiped.Bip01_R_Finger22"] = { pos = Vector(1.209, 0, 0), ang = Angle(1.283, -17.555, -0.196) },
			["ValveBiped.Bip01_R_Finger3"] = { pos = Vector(3.930, 0.253, 0.453), ang = Angle(3.390, -15.483, 5.818) },
			["ValveBiped.Bip01_R_Finger31"] = { pos = Vector(1.539, 0, 0), ang = Angle(-1.308, -17.549, 0.211) },
			["ValveBiped.Bip01_R_Finger32"] = { pos = Vector(1.196, 0, 0), ang = Angle(-1.268, -17.560, 0.212) },
			["ValveBiped.Bip01_R_Finger4"] = { pos = Vector(3.853, 0.069, 1.215), ang = Angle(0.123, -7.798, 36.208) },
			["ValveBiped.Bip01_R_Finger41"] = { pos = Vector(1.313, 0, 0), ang = Angle(-3.885, -17.134, 0.616) },
			["ValveBiped.Bip01_R_Finger42"] = { pos = Vector(0.729, 0, 0), ang = Angle(-3.987, -17.133, 0.616) },
		},
	},
	off = {
		stomach = {
			["ValveBiped.Bip01_R_Finger0"] = Angle(7.577, -44.288, 0),
			["ValveBiped.Bip01_R_Finger01"] = Angle(3.189, 0, 0),
			["ValveBiped.Bip01_R_Finger02"] = Angle(0.078, -11.506, 0),
			["ValveBiped.Bip01_R_Finger1"] = Angle(1.436, -0.695, 5.220),
			["ValveBiped.Bip01_R_Finger11"] = Angle(0, 0, 0),
			["ValveBiped.Bip01_R_Finger12"] = Angle(20.945, -88.362, 0),
			["ValveBiped.Bip01_R_Finger2"] = Angle(0.918, -5.656, 0),
			["ValveBiped.Bip01_R_Finger21"] = Angle(11.435, -20.476, 9.145),
			["ValveBiped.Bip01_R_Finger22"] = Angle(0, -80.907, 0),
			["ValveBiped.Bip01_R_Finger3"] = Angle(-9.899, -7.617, 0),
			["ValveBiped.Bip01_R_Finger31"] = Angle(12.857, -36.593, 0),
			["ValveBiped.Bip01_R_Finger32"] = Angle(0, -46.331, 0),
			["ValveBiped.Bip01_R_Finger4"] = Angle(-24.576, -27.073, -0.437),
			["ValveBiped.Bip01_R_Finger41"] = Angle(2.647, -26.109, 0),
			["ValveBiped.Bip01_R_Finger42"] = Angle(0, -31.860, 0),
		},
	},
}

-- every hold uses the stomach fingers unless a stage is captured on its own in the tuner
C.DefaultFingers.base.pocket = ZPHONE.Clone(C.DefaultFingers.base.stomach)
C.DefaultFingers.base.face = ZPHONE.Clone(C.DefaultFingers.base.stomach)
C.DefaultFingers.off.pocket = ZPHONE.Clone(C.DefaultFingers.off.stomach)
C.DefaultFingers.off.face = ZPHONE.Clone(C.DefaultFingers.off.stomach)

-- ========== easing + animation timing (shared: client UI and server phone motion both read these) ==========

-- the curves. t runs 0 -> 1, c is only used by outBack (overshoot)
ZPHONE.Ease = {
	linear = function(t) return t end,
	inCubic = function(t) return t * t * t end,
	outCubic = function(t)
		local u = 1 - t
		return 1 - u * u * u
	end,
	inOutCubic = function(t)
		if t < 0.5 then return 4 * t * t * t end
		local u = -2 * t + 2
		return 1 - (u * u * u) / 2
	end,
	outExpo = function(t)
		if t >= 1 then return 1 end
		return 1 - 2 ^ (-10 * t)
	end,
	outBack = function(t, c)
		c = c or 1.70158
		local u = t - 1
		return 1 + (c + 1) * u * u * u + c * u * u
	end,
}

-- dur: seconds at speed 1. c: outBack overshoot. arc: phone-motion only, how far the hand lifts between stages (chest-local units, negative flips it)
-- pull / raise / lower are the phone's own motion. everything else is UI
ZPHONE.AnimDefaults = {
	pull      = { dur = 0.60, ease = "inOutCubic", c = 4, arc = 12 },  -- pocket -> stomach
	raise     = { dur = 0.40, ease = "inOutCubic", c = 4, arc = 0.0089932986605382 },   -- stomach -> face
	lower     = { dur = 0.37416733378722, ease = "inOutCubic", c = 4, arc = 2 },   -- face -> stomach
	unlock    = { dur = 0.50, ease = "outCubic" },              -- lock slides up, home rises under it
	lock      = { dur = 0.40, ease = "inOutCubic" },            -- home drops away into the lock screen
	appOpen   = { dur = 0.34, ease = "outCubic" },              -- app grows out of its icon
	homeIn    = { dur = 0.26, ease = "outCubic" },              -- home fades/settles back in after an app
	notifyIn  = { dur = 0.45, ease = "outBack", c = 1.6 },      -- banner drops from the top
	notifyOut = { dur = 0.25, ease = "inCubic" },
	kb        = { dur = 0.26, ease = "outCubic" },              -- keyboard slides up
	call      = { dur = 0.35, ease = "outBack", c = 1.1 },      -- call overlay slides in
	toast     = { dur = 0.22, ease = "outCubic" },
	press     = { dur = 0.12, ease = "outCubic" },              -- tap flash on a button
}

-- the three that drive the phone's own motion (server and client both tween these)
ZPHONE.BlendOrder = { "pull", "raise", "lower" }

-- the effective settings for one animation: saved tuning over the defaults. cfg is a table with .anim and .animSpeed
-- (the client passes ZPHONE.Tuning, the server passes the cfg the owner's client sent). cfg may be nil
function ZPHONE.AnimSettings(name, cfg)
	local base = ZPHONE.AnimDefaults[name] or { dur = 0.3, ease = "outCubic" }
	local saved = cfg and istable(cfg.anim) and cfg.anim[name] or nil
	return {
		dur = (saved and tonumber(saved.dur)) or base.dur,
		ease = (saved and saved.ease) or base.ease,
		c = (saved and tonumber(saved.c)) or base.c,
		arc = (saved and tonumber(saved.arc)) or base.arc or 0,
	}
end

-- how long it actually plays for: the saved duration divided by the global speed
function ZPHONE.AnimPlayDur(name, cfg)
	local speed = math.max(cfg and tonumber(cfg.animSpeed) or 1, 0.05)
	return math.max(ZPHONE.AnimSettings(name, cfg).dur / speed, 0.02)
end

-- what the owner's client sends the server. the server clamps everything, never trusts the numbers as-is
function ZPHONE.SanitizeAnimCfg(t)
	if not istable(t) then return nil end
	local out = { anim = {}, animSpeed = math.Clamp(tonumber(t.animSpeed) or 1, 0.25, 3) }
	for _, name in ipairs(ZPHONE.BlendOrder) do
		local a = istable(t.anim) and t.anim[name] or nil
		if istable(a) then
			out.anim[name] = {
				dur = math.Clamp(tonumber(a.dur) or 0.3, 0.05, 3),
				ease = ZPHONE.Ease[a.ease] and a.ease or "inOutCubic",
				c = math.Clamp(tonumber(a.c) or 1.70158, 0, 4),
				arc = math.Clamp(tonumber(a.arc) or 0, -12, 12),
			}
		end
	end
	return out
end

C.Sounds = {
	pull = "zphone/pull.wav",
	unlock = "zphone/unlock.wav",
	tap = "zphone/tap.wav",
	buzz = "zphone/buzz.wav",       -- notification, no popup, just a buzz
	ring = "zphone/ring.wav",       -- incoming call
	pickup = "zphone/pickup.wav",
	hangup = "zphone/hangup.wav",
	send = "zphone/send.wav",
	shutter = "zphone/shutter.wav", -- camera
}

-- apps on the home screen. id is what the UI switches on, don't rename without grepping
-- accounts used to be an app here. numbers are managed by the zphone_acc console command now (cl_zphone_acc.lua)
C.Apps = {
	{ id = "messages", name = "Messages" },
	{ id = "feed", name = "Feed" },
	{ id = "contacts", name = "Contacts" },
	{ id = "phone", name = "Phone" },
	{ id = "taxi", name = "Taxi" },
	{ id = "delivery", name = "Delivery" },
	{ id = "map", name = "Map" },
	{ id = "notes", name = "Notes" },
	{ id = "camera", name = "Camera" },
	{ id = "settings", name = "Settings" },
}

-- delivery menu, two levels. a category with options opens a sub-list, the price/weight is per option.
-- RP only: nothing spawns, responders just get a ping that someone ordered pizza
C.DeliveryMenu = {
	{ name = "Pizza", kg = 1.2, options = {
		{ name = "Margherita", kg = 1.2 },
		{ name = "Pepperoni", kg = 1.3 },
		{ name = "Hawaiian", kg = 1.3 },
		{ name = "Four cheese", kg = 1.4 },
		{ name = "Meat feast", kg = 1.6 },
	} },
	{ name = "Burger", kg = 0.4, options = {
		{ name = "Classic", kg = 0.4 },
		{ name = "Cheeseburger", kg = 0.45 },
		{ name = "Double", kg = 0.6 },
		{ name = "Chicken", kg = 0.4 },
		{ name = "Veggie", kg = 0.35 },
	} },
	{ name = "Coffee", kg = 0.3, options = {
		{ name = "Espresso", kg = 0.1 },
		{ name = "Cappuccino", kg = 0.3 },
		{ name = "Latte", kg = 0.35 },
		{ name = "Black filter", kg = 0.3 },
	} },
	{ name = "Sushi", kg = 0.5, options = {
		{ name = "California roll", kg = 0.4 },
		{ name = "Salmon nigiri", kg = 0.3 },
		{ name = "Party platter", kg = 1.5 },
	} },
	{ name = "Groceries", kg = 3.0, options = {
		{ name = "Bread and milk", kg = 1.5 },
		{ name = "Fruit basket", kg = 2.0 },
		{ name = "Full weekly shop", kg = 6.0 },
	} },
	{ name = "Mystery box (don't)", kg = 0.5 }, -- no options, orders straight away
}
C.DeliveryCooldown = 120 -- seconds per player, the admins will thank us

-- spam. every rollEvery seconds, each account of each online player has a `chance` of getting one spam text.
-- the senders are fake numbers that belong to no account, so there's nobody to reply to. they buzz, then sit in the spam tab.
-- blocking a sender stops them for good. account numbers are 10 digits (see NYCAreaCodes), so these 7-digit senders can't clash with them.
-- city alerts: the GM's zphone_alert command. a fixed sender that every online player gets, in their inbox.
-- it can't be blocked, and it can't be replied to. the number must not overlap accounts or spam senders.
C.Alerts = {
	number = "9000000",
	name = "CITY ALERTS",
}

C.Spam = {
	enabled = true,
	rollEvery = 20,       -- seconds
	chance = 0.06,        -- roughly one spam text every 5 or 6 minutes per account
	senders = {
		["9000101"] = "PIZZA DEALS",
		["9000102"] = "WINNER NOTICE",
		["9000103"] = "CAR WARRANTY",
		["9000104"] = "PREMIUM SMS",
		["9000105"] = "GYM 4 U",
		["9000106"] = "BANK ALERT",
	},
	texts = {
		"Congratulations! You've been selected for a FREE cruise. Reply YES.",
		"50% off your next order. Reply STOP to not stop.",
		"Your vehicle warranty is about to expire. Call now.",
		"Your account is locked. Verify your details to unlock it.",
		"Hot singles near you are waiting. Reply to chat.",
		"Last chance: claim your prize before midnight!!!",
		"Free membership trial, you only pay the delivery fee.",
	},
}

-- the social feed. player posts and generated posts share one list. generated posts come from made-up people
C.Feed = {
	maxPosts = 150,     -- the feed keeps this many, oldest drop off
	maxLen = 200,       -- characters per post
	cooldown = 30,      -- seconds between posts per player
	seed = 24,          -- posts generated on first run, so the feed isn't empty
	people = 40,        -- made-up people who post
	genEvery = 180,     -- seconds between generated post rolls
	genChance = 0.6,    -- chance of a generated post per roll. a second one is rolled at half this chance
}

-- emergency + taxi. responders get the 911 calls and the cab requests.
-- anyone who is an admin counts as a responder. add SteamID64s below to let non-admins take 911 calls too
C.Emergency = {
	ringTime = 60,    -- seconds a 911 call rings before it gives up
	cooldown = 30,    -- seconds between 911 calls per player, so nobody spams the line
	responders = {
		-- "7656119..." -- your SteamID64 goes here. steamid.io turns the profile URL into it
	},
}
C.TaxiCooldown = 60 -- seconds between cab requests per player

-- map app: bounds of the playable area in world units. placeholder, set per map
C.MapBounds = {
	mins = Vector(-16000, -16000, -1000),
	maxs = Vector(16000, 16000, 1000),
}

-- ========== map app ==========
-- MapBounds (above) is the playable area. the overview covers a square over its bigger side.
-- to set it: stand at the min corner and run zphone_mappos, then the max corner, and paste into MapBounds.
C.MapOverview = {
	size = 512,      -- render target size in px
	refresh = 1.5,   -- seconds between top-down renders while the map is open
	flipX = false,   -- if the map comes out mirrored, flip these
	flipY = false,
	meters = 52.5,   -- hammer units per metre, for the distance readout. tune it if the numbers feel off
	boundsSource = "config",  -- "auto" reads the map's own bounds, "config" uses MapBounds below
}

C.MapKinds = {
	-- shops
	{ id = "store",       name = "Store",            abbr = "S", icon = "icon16/cart.png",      col = Color(56, 178, 96) },
	{ id = "supermarket", name = "Supermarket",      abbr = "M", icon = "icon16/basket.png",    col = Color(56, 150, 96) },
	{ id = "department",  name = "Department store", abbr = "D", icon = "icon16/building.png",  col = Color(88, 140, 220) },
	{ id = "clothing",    name = "Clothes shop",     abbr = "K", icon = "icon16/shirt.png",     col = Color(180, 110, 210) },
	{ id = "hardware",    name = "Hardware store",   abbr = "W", icon = "icon16/wrench.png",    col = Color(226, 130, 52) },
	{ id = "gun",         name = "Gun store",        abbr = "G", icon = "icon16/gun.png",       col = Color(150, 60, 60) },
	{ id = "commercial",  name = "Commercial",       abbr = "C", icon = "icon16/briefcase.png", col = Color(226, 178, 52) },

	-- food and services
	{ id = "food",        name = "Restaurant",       abbr = "F", icon = "icon16/cake.png",      col = Color(236, 110, 90) },
	{ id = "bank",        name = "Bank",             abbr = "B", icon = "icon16/money.png",     col = Color(90, 170, 120) },
	{ id = "garage",      name = "Garage",           abbr = "U", icon = "icon16/cog.png",       col = Color(120, 120, 140) },
	{ id = "hotel",       name = "Hotel",            abbr = "O", icon = "icon16/bed.png",       col = Color(120, 150, 210) },
	{ id = "school",      name = "School",           abbr = "E", icon = "icon16/book.png",      col = Color(200, 170, 80) },

	-- health and emergency
	{ id = "hospital",    name = "Hospital",         abbr = "H", icon = "icon16/heart.png",     col = Color(230, 80, 90) },
	{ id = "pharmacy",    name = "Pharmacy",         abbr = "P", icon = "icon16/pill.png",      col = Color(200, 90, 150) },
	{ id = "police",      name = "Police",           abbr = "P", icon = "icon16/shield.png",    col = Color(70, 110, 230) },
	{ id = "fire",        name = "Fire station",     abbr = "F", icon = "icon16/fire.png",      col = Color(240, 100, 40) },

	-- transport and places
	{ id = "taxi",        name = "Cars",        abbr = "T", icon = "icon16/car.png",       col = Color(242, 186, 62) },
	{ id = "metro",       name = "Metro station",    abbr = "M", icon = "icon16/bus.png",       col = Color(60, 130, 200) },
	{ id = "park",        name = "Park",             abbr = "G", icon = "icon16/tree.png",      col = Color(90, 180, 110) },
	{ id = "residential", name = "Residential",      abbr = "R", icon = "icon16/house.png",     col = Color(150, 120, 200) },
	{ id = "landmark",    name = "Government",         abbr = "L", icon = "icon16/flag.png",      col = Color(236, 84, 124) },
	{ id = "tunnel",      name = "Tunnel",           abbr = "N", icon = "icon16/arrow_inout.png", col = Color(120, 96, 70) },
}

function C.MapKindOf(id)
	for _, k in ipairs(C.MapKinds) do
		if k.id == id then return k end
	end
end

-- messages / contacts limits. server enforces, client just trusts itself less
C.MaxMessageLength = 240
C.MaxMessagesPerAccount = 300
C.MaxNotesLength = 2000

-- group chats. maxMembers counts you too. every member gets a copy of each message
C.Groups = {
	maxMembers = 6,
	maxName = 24,
}

-- distance-based text message delivery is off, texts go anywhere. it's 2026, nobody walks to deliver a text
C.TextRequiresSignal = false

-- battery. it drains while you carry the phone: slowly in the pocket, faster when it's out. zphone_charge "name" fills it up
C.Battery = {
	start = 100,          -- percent a full charge is
	idlePerMin = 0.15,    -- in the pocket
	activePerMin = 0.9,   -- out and up. roughly 110 minutes of use from full
	tick = 5,             -- seconds between drain steps
}
-- a fall at least this hard, with the phone on you, cracks the screen. zphone_repair "name" fixes it
C.Crack = { fallDamage = 40 }

-- the rear camera. the viewfinder and the photos are the same render, so the photos are small too.
-- w / h are the render target size, fixed when the game starts (a change needs a restart). quality is JPEG 0-100.
-- offset is how far behind the phone the lens sits, in hammer units
-- holdDur is how long the phone takes to ease into the camera hold, in seconds. everyone sees the same timing
C.Camera = { w = 128, h = 256, fov = 60, quality = 15, offset = 1.5, holdDur = 0.35 }

-- admin ping for delivery orders, cab requests and 911
function C.IsAdminForPings(ply)
	return IsValid(ply) and (ply:IsAdmin() or ply:IsSuperAdmin())
end

-- who takes 911 calls: admins, plus anyone whose SteamID64 is in C.Emergency.responders
function C.IsResponder(ply)
	if not IsValid(ply) then return false end
	if C.IsAdminForPings(ply) then return true end
	local sid = ply:SteamID64()
	for _, s in ipairs(C.Emergency.responders) do
		if s == sid then return true end
	end
	return false
end

-- phone numbers. a new account gets a random real NYC number: one of these area codes, then a random exchange and line
-- (see newNumber in sv_zphone.lua). change or add area codes here
C.NYCAreaCodes = { "212", "646", "917", "718", "347", "929", "332" }

-- shows a number the way it reads. a 10-digit one is an account: (212) 834-7092
-- the 7-digit numbers (spam senders, city alerts) keep the old 000-0000 look
function C.FormatNumber(n)
	n = tostring(n or 0)
	if #n == 10 then
		return "(" .. string.sub(n, 1, 3) .. ") " .. string.sub(n, 4, 6) .. "-" .. string.sub(n, 7, 10)
	end
	while #n < 7 do n = "0" .. n end
	return string.sub(n, 1, 3) .. "-" .. string.sub(n, 4, 7)
end
