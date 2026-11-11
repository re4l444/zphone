-- zphone social feed, server side. player posts, generated posts from made-up people, and CITY ALERTS posts, all in one list.
-- generated text is built at random: a prefix, a template with slots filled from pools, and a suffix.
-- no single pool is big. the combinations are what make it big, so the feed doesn't start repeating itself for a long time.
-- included from sv_zphone.lua, after the store has loaded. the feed lives in the store, so it survives restarts.

local C = ZPHONE.Config.Feed
local Store = ZPHONE.Store

-- ========== pools ==========

local FIRST = {
	"Mara", "Jonah", "Kiko", "Dez", "Lena", "Otis", "Rin", "Vance", "Tessa", "Milo",
	"Sol", "Nadia", "Felix", "Ada", "Ruben", "Juno", "Corin", "Pia", "Hugo", "Ines",
	"Rafi", "Wren", "Tobi", "Ezra", "Yara", "Cass", "Dario", "Lottie", "Marlo", "Sable",
	"Bodhi", "Nova", "Kit", "Ivo", "Remy", "Talia", "Arlo", "Opal", "Dani", "Quinn",
	"Silas", "Luz", "Noor", "Bram", "Esme", "Kofi", "Lio", "Mina", "Orla", "Pablo",
	"Reese", "Sasha", "Teo", "Vera", "Wade", "Yusuf", "Zara", "Gus", "Hana", "Ike",
	"Jett", "Kalani", "Lou", "Mateo", "Nell", "Ozzie", "Pilar", "Rudy", "Sami", "Thea",
	"Ulric", "Val", "Wes", "Xan", "Yves", "Zed",
}

local LAST = {
	"Okafor", "Lindqvist", "Reyes", "Moretti", "Nakamura", "Haddad", "Volkov", "Brennan", "Castillo", "Dubois",
	"Eriksen", "Fontaine", "Goldberg", "Hale", "Ivanova", "Jansen", "Kowalski", "Lund", "Mendes", "Novak",
	"Ortiz", "Park", "Quill", "Rossi", "Silva", "Tanaka", "Underwood", "Varga", "Walsh", "Xu",
	"Yilmaz", "Zielinski", "Ashby", "Boateng", "Calder", "Dunmore", "Ferreira", "Greaves", "Holt", "Kemp",
}

local HANDLE_TAIL = { "", "", "", "_", "_", "99", "xo", "_irl", "404", "_real", "0", "x", "_tv", "__" }

-- the things templates can ask for. {name} in a template picks one at random
local SLOTS = {
	district = {
		"Old Town", "the docks", "Eastside", "the metro", "Northgate", "Chapel Hill", "the market", "Riverside",
		"the rail yard", "Harbour Row", "the back alleys", "Maple Court", "the bridge", "Sunken Quarter", "the station",
		"Factory Row", "Hillcrest", "the bus loop", "Lantern Street", "the square", "the park", "the car park by the mall",
		"the 24h laundromat", "Millbank", "Cinder Bay", "the flats on 4th",
	},
	food = {
		"pizza", "kebabs", "dumplings", "ramen", "a bagel", "burgers", "sushi", "tacos", "pho", "chips",
		"a cold coffee", "falafel", "a meat feast", "pancakes", "noodles", "a sad sandwich", "soup", "cinnamon buns",
		"leftover lasagne", "a doner", "fries", "hot chocolate", "a protein shake", "pastries",
	},
	mood = {
		"tired", "hyped", "fine i guess", "on edge", "wired", "kind of melancholy", "buzzing", "half asleep",
		"soaked", "weirdly calm", "done with everything", "grateful", "lowkey happy", "running on coffee", "dramatic today",
	},
	weather = {
		"rain", "fog", "a heatwave", "wind that knocks the bins over", "drizzle", "sleet", "sunshine out of nowhere",
		"a grey sky", "thunder", "ten minutes of snow",
	},
	time = {
		"3am", "midnight", "6am", "lunchtime", "rush hour", "noon", "2pm", "last call", "sunday morning",
		"friday night", "half past four", "the school run",
	},
	transit = {
		"the bus", "the train", "the tram", "the metro", "the night cab", "the ferry", "the bike share", "the last bus",
	},
	item = {
		"my keys", "a phone charger", "my wallet", "my umbrella", "a parking ticket", "the groceries", "my glasses",
		"a sandwich", "my skateboard", "a library book",
	},
	team = {
		"the local side", "the derby", "the home team", "the underdogs", "the cup game",
	},
	person = {
		"my landlord", "the guy at the counter", "my cousin", "the taxi driver", "some stranger", "my boss",
		"the lady with the dog", "the bouncer", "my neighbour", "a kid on a bike", "the barista", "my ex",
	},
}

-- went in front of the text. most of the time, nothing
local PREFIX = {
	"", "", "", "", "", "ngl ", "not gonna lie, ", "psa: ", "update: ", "reminder: ",
	"unpopular opinion: ", "hot take: ", "so apparently ", "just saying, ", "ok so ",
}

-- goes after the text
local SUFFIX = { "", "", "", "", "", " lol", " smh", " send help.", " anyway.", " ok bye.", " (no regrets)" }

-- the sentences. {number} is filled in by the generator, everything else comes from SLOTS
local TEMPLATES = {
	"just got {food} from {district} and honestly it was worth the wait",
	"anyone else hear that noise around {district} at {time}? not normal",
	"{person} just cut me off on {transit}. unbelievable",
	"{time} and i'm still awake. send help or send {food}",
	"third time this week {transit} has been late. i'm writing a letter",
	"feeling {mood} about the {team} game. nobody talk to me",
	"{weather} in {district} right now. stay in if you can",
	"lost {item} somewhere between {district} and the {transit} stop. if found, dm me",
	"{person} said they'd call back. it has been {number} hours",
	"does anyone know if {district} is still closed for works? asking for a friend",
	"whoever keeps leaving {item} on the {transit} seat, please stop",
	"{mood} in {district}. probably the coffee",
	"the {food} place in {district} changed their recipe and i'm not sure i'm ok",
	"someone in {district} is selling {item} for cheap. not sure it's legal",
	"{number} minutes waiting for {transit} at {district}. nothing is moving",
	"best thing that happened today: {person} gave me {food} for free",
	"if you see a {mood} person outside {district} at {time}, that's me",
	"who's up for {food} at {district}? i'm buying",
	"the view from {district} at {time} is actually unreal",
	"{person} is the reason i don't trust {transit} anymore",
	"i swear {district} has three different {weather} systems at once",
	"{item} is not a personality, but mine is {mood} so we're even",
	"finally got {item} back from {person}. they wanted {number} bucks for it",
	"they said the {transit} would be here in five. it's been {number} minutes",
	"{time} traffic in {district} is a crime. who approved this",
	"ran into {person} at {district} and they still owe me {food}",
	"anyone wanna split {food} at {district}? i'm starving and broke",
	"the lights in {district} went out for a bit at {time}. anyone else?",
	"my plants survived the {weather}. the neighbours did not",
	"pro tip: don't take {transit} at {time}. learned this the hard way",
	"{person} asked if i'd seen {item}. i have not. i have not seen anything",
	"i am {mood} and i have {food} and nothing else matters right now",
	"{district} smells like {food} again. someone please explain",
	"fourth {transit} in a row just drove straight past me. bye",
	"why is there a {weather} in {district} on a sunny day. genuinely asking",
	"survived {time} in {district}. would not recommend, would do again",
	"the {team} lost again. {person} is taking it personally",
	"{number} bucks for {food} in {district}. i'll just stay hungry",
	"{person} posted a photo of {item} and now everyone is asking where it is",
	"the bench outside {district} has been {mood} all week, so have i",
	"put {item} down for one second in {district} and it's gone. fair trade i guess",
	"new rule: no {food} on the {transit}. i don't make the rules but i do enforce them",
	"walked from {district} to the {transit} stop in the {weather}. i'm a different person now",
	"looking for someone who knows {district} well. the map is lying to me",
	"{mood} at {time}, watching the {transit} go by with my {food}",
	"nobody tell {person} i was at {district} today",
	"whoever's been playing music at {district} at {time}, you're a legend. keep going",
	"the {food} on {district} is either amazing or cursed. no in between",
}

-- ========== generation ==========

local function pick(t)
	return t[math.random(#t)]
end

-- fills {slot} tokens in a template. {number} is a random 2 to 99, anything else comes from SLOTS
local function fill(s)
	return (string.gsub(s, "{(%w+)}", function(key)
		if key == "number" then return tostring(math.random(2, 99)) end
		local list = SLOTS[key]
		return list and pick(list) or ("{" .. key .. "}")
	end))
end

-- one generated post's text: prefix + filled template + suffix, first letter capitalised
local function makeText()
	local s = pick(PREFIX) .. fill(pick(TEMPLATES)) .. pick(SUFFIX)
	return string.upper(string.sub(s, 1, 1)) .. string.sub(s, 2)
end

-- a made-up person. they stick around, so the same names come back and the feed feels populated
local function makePerson()
	local first = pick(FIRST)
	local handle = string.lower(first) .. pick(HANDLE_TAIL)
	if math.random() < 0.4 then handle = handle .. math.random(1, 999) end
	return { name = first .. " " .. pick(LAST), handle = handle }
end

local function ensurePeople()
	Store.feedPeople = Store.feedPeople or {}
	while #Store.feedPeople < C.people do
		Store.feedPeople[#Store.feedPeople + 1] = makePerson()
	end
end

-- a handle for a real player. lowercase, no spaces or punctuation
local function handleFor(name)
	local h = string.lower(name)
	h = string.gsub(h, "%s+", "_")
	h = string.gsub(h, "[^%w_]", "")
	if h == "" then h = "player" end
	return h
end

-- ========== the list ==========

Store.feed = Store.feed or {}
Store.feedNext = Store.feedNext or 1

local function nextId()
	local id = Store.feedNext
	Store.feedNext = id + 1
	return id
end

-- adds a post to the list without saving or syncing. used for seeding, where we want one pass
local function addRaw(p)
	p.id = nextId()
	p.t = p.t or os.time()
	p.likers = p.likers or {}
	p.base = p.base or 0
	Store.feed[#Store.feed + 1] = p
	while #Store.feed > C.maxPosts do
		table.remove(Store.feed, 1)
	end
end

local function syncEveryone()
	for _, p in ipairs(player.GetAll()) do
		ZPHONE.Sync(p)
	end
end

-- used by the alerts command too, so CITY ALERTS posts land on the feed
function ZPHONE.AddFeedPost(p)
	addRaw(p)
	ZPHONE.Save()
	syncEveryone()
end

local function findPost(id)
	id = tonumber(id)
	if not id then return end
	for _, p in ipairs(Store.feed) do
		if p.id == id then return p end
	end
end

-- what one phone gets: the newest 40 posts, newest first, with likes counted and "liked" for this account
function ZPHONE.FeedFor(acc)
	local out = {}
	local n = #Store.feed
	for i = n, math.max(1, n - 39), -1 do
		local p = Store.feed[i]
		local count = p.base or 0
		for _ in pairs(p.likers or {}) do count = count + 1 end
		out[#out + 1] = {
			id = p.id,
			author = p.author,
			handle = p.handle,
			text = p.text,
			t = p.t,
			kind = p.kind,
			likes = count,
			liked = acc ~= nil and (p.likers or {})[acc.number] ~= nil,
			mine = acc ~= nil and p.owner ~= nil and p.owner == acc.number,
		}
	end
	return out
end

local function generatedPost(age)
	local person = pick(Store.feedPeople)
	return {
		author = person.name,
		handle = person.handle,
		text = makeText(),
		kind = "gen",
		base = math.random(0, 40),
		t = os.time() - (age or 0),
	}
end

-- ========== first run ==========

ensurePeople()
if #Store.feed == 0 then
	for _ = 1, C.seed do
		addRaw(generatedPost(math.random(60, 2 * 86400)))
	end
	-- seeded posts were added with made-up times, so put them in time order
	table.sort(Store.feed, function(a, b) return a.t < b.t end)
	ZPHONE.Save()
end

-- ========== handlers ==========

ZPHONE.Handlers.post = function(ply, d)
	local me = ZPHONE.ActiveOf(ply)
	if not me then return "make an account first" end

	if (ply.ZPhoneFeedCD or 0) > CurTime() then
		return "you posted a moment ago. wait " .. math.ceil(ply.ZPhoneFeedCD - CurTime()) .. "s"
	end

	local text = ZPHONE.CleanText(d.text, C.maxLen)
	if text == "" then return "write something first" end

	ply.ZPhoneFeedCD = CurTime() + C.cooldown
	addRaw({ author = me.name, handle = handleFor(me.name), text = text, kind = "player", owner = me.number })
	ZPHONE.Save()
	syncEveryone()
end

-- like / unlike. one like per account, toggled
ZPHONE.Handlers.like = function(ply, d)
	local me = ZPHONE.ActiveOf(ply)
	if not me then return end
	local p = findPost(d.id)
	if not p then return "that post is gone" end
	p.likers = p.likers or {}
	p.likers[me.number] = (not p.likers[me.number]) and true or nil
	ZPHONE.Save()
	syncEveryone()
end

-- you can delete your own posts. generated posts and alerts don't belong to anyone, so they stay
ZPHONE.Handlers.delpost = function(ply, d)
	local me = ZPHONE.ActiveOf(ply)
	local p = findPost(d.id)
	if not me or not p then return end
	if p.owner ~= me.number then return "you can only delete your own posts" end
	for i, q in ipairs(Store.feed) do
		if q == p then
			table.remove(Store.feed, i)
			break
		end
	end
	ZPHONE.Save()
	syncEveryone()
end

-- ========== the generator's clock ==========
-- every genEvery seconds, one generated post with genChance. sometimes a second one at half that chance

timer.Create("ZPhoneFeedGen", C.genEvery, 0, function()
	if math.random() < C.genChance then
		addRaw(generatedPost())
	end
	if math.random() < C.genChance * 0.5 then
		addRaw(generatedPost())
	end
	ZPHONE.Save()
	syncEveryone()
end)
