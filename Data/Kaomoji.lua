-- TwitchEmotes+ : Data/Kaomoji.lua
-- Kaomoji (Japanese emoticons) and classic text smileys as a service.
-- Each item is { text, label }. `ascii` is computed below: items using only
-- 7-bit characters render in any font and survive any chat path; the rest
-- need a font with the glyphs (see README "Kaomoji and fonts"). The default
-- 1.12 fonts lack most kana and symbols, so the bulk of this list is ASCII.
--
-- Rules for entries: no pipe or percent character (WoW treats them specially
-- in chat), and no codes upstream TwitchEmotes already owns as emotes ("D:",
-- "o_O", "O_o"), which it would turn into images in chat. Yahoo Messenger's
-- text codes live in Data/Yahoo.lua, with their own dropdown.
--
-- Third parties can replace or extend this with
--   TwitchEmotesPlus.Container:Override("kaomojiSource", function() ... end)
-- returning { Get = function() return { {name=, items={ {text=,label=}, ... }}, ... } end }

local TEP = TwitchEmotesPlus
local C = TEP.Container

local CATEGORIES = {
	{ name = "Happy", items = {
		{ "(^_^)", "smile" }, { "(^o^)", "grin" }, { "\\(^o^)/", "cheer" }, { "(^-^)/", "wave" },
		{ "(*^_^*)", "happy" }, { "(=^_^=)", "content" }, { "(^_^)v", "peace" }, { "d(^_^)b", "thumbs up" },
		{ "(^_~)", "wink" }, { "ヽ(´▽`)/", "joyful" }, { "(≧▽≦)", "delighted" }, { "o(≧▽≦)o", "excited" },
		{ "ヽ(^‿^)ノ", "beaming" }, { "(＾▽＾)", "cheerful" },
		{ "(^.^)", "smile" }, { "(^-^)", "calm smile" }, { "(*^o^*)", "thrilled" }, { "(~^_^)~", "happy sway" },
		{ "(^_-)", "wink" }, { "(^o^)/", "hooray" }, { "(^^)v", "victory" }, { "(-^_^-)", "serene" },
		{ "(^_^)b", "thumbs up" },
	} },
	{ name = "Excited", items = {
		{ "\\(>o<)/", "yay" }, { "\\(^^)/", "hooray" }, { "\\(^_^)/", "cheering" }, { "o(^o^)o", "pumped" },
		{ "<(^_^)>", "joyful" }, { "(>^_^)>", "dance right" }, { "<(^_^<)", "dance left" },
		{ "((o(^_^)o))", "bouncing" }, { "(*^o^)/", "waving excitedly" }, { "(>^_^)> <(^_^<)", "dance party" },
	} },
	{ name = "Love", items = {
		{ "<3", "heart" }, { "(^3^)", "kiss" }, { "(*^3^)/~<3", "kiss heart" },
		{ "(♥‿♥)", "heart eyes" }, { "(｡♥‿♥｡)", "in love" }, { "(´,,•ω•,,)♡", "cute love" },
		{ "(´∀`)♡", "affection" }, { "(づ￣ ³￣)づ", "kiss hug" }, { "(˘³˘)♥", "smooch" },
		{ "(◍•ᴗ•◍)❤", "sweet love" },
		{ "</3", "broken heart" }, { "(^o^)<3", "loving" }, { "<3(^_^)", "heart smile" },
		{ "(*^_^*)<3", "blushing love" }, { "(^_^)/~<3", "throwing love" }, { "<3 (^.^) <3", "surrounded by love" },
		{ "(*^3^)", "kissy face" }, { "(^.^)<3", "sweet" },
	} },
	{ name = "Sad", items = {
		{ "(T_T)", "cry" }, { "(;_;)", "tears" }, { "(ToT)", "sob" }, { "(T.T)", "crying" },
		{ "(;-;)", "sad" }, { "orz", "despair" }, { "(´;ω;`)", "weeping" }, { "(╥_╥)", "teary" },
		{ "(ಥ_ಥ)", "tearful" }, { "｡･ﾟ･(ﾉД`)･ﾟ･｡", "bawling" }, { "(つ﹏⊂)", "sobbing" },
		{ "(T^T)", "bitter tears" }, { "(T-T)", "sniffle" }, { "(u_u)", "down" }, { "(v_v)", "gloomy" },
		{ "(;_;)/~~~", "sad wave" }, { "(ToT)/~~~", "crying goodbye" }, { "(>_<;)", "upset" },
		{ "(~_~;)", "dejected" }, { "(;O;)", "wailing" }, { "(;;)", "tears streaming" }, { "(TT)", "crying" },
		{ "OTL", "kneeling in defeat" }, { "Orz", "defeated" },
	} },
	{ name = "Angry", items = {
		{ "(>_<)", "frustrated" }, { ">:(", "angry" }, { "(-_-#)", "annoyed" }, { "(>.<)", "pain" },
		{ "(`Д´)", "furious" }, { "ヽ(`Д´)ﾉ", "rage" }, { "(╬ Ò﹏Ó)", "seething" },
		{ "(¬_¬)", "side eye" }, { "(ಠ_ಠ)", "disapproval" }, { "(｀へ´)", "grumpy" },
		{ ">:[", "grumpy" }, { "(`_')", "scowl" }, { "(`-')", "glare" }, { "(#`_')", "mad" },
		{ "(-_-)#", "irritated" }, { "(>_<)#", "fuming" }, { "(>:<)", "snarl" }, { ">:O", "shouting" },
		{ "grr!", "growl" }, { "(;`_')", "angry tears" },
	} },
	{ name = "Surprised", items = {
		{ "(O_O)", "shock" }, { "(o_o)", "wide eyed" }, { "(O.O)", "stunned" }, { "(@_@)", "dizzy" },
		{ "(o.O)", "confused" }, { "(°o°)", "gasp" }, { "(⊙_⊙)", "staring" }, { "(°ロ°)", "startled" },
		{ "w(°o°)w", "omg" }, { "(゜o゜)", "amazed" },
		{ "(O_O;)", "nervous shock" }, { "(O_o)", "double take" }, { "(0_0)", "bug eyed" }, { "(0.0)", "speechless" },
		{ "(o.o)", "peering" }, { "(@_@;)", "dazed" }, { "(*_*)", "starstruck" }, { "(+_+)", "spiral eyes" },
		{ "(!_!)", "alarmed" }, { "(O.o)", "suspicious" }, { "(o_0)", "uneasy" },
	} },
	{ name = "Confused", items = {
		{ "(?_?)", "confused" }, { "(o_O)?", "what" }, { "(._.?)", "puzzled" }, { "(-_-?)", "doubtful" },
		{ "(@_@?)", "lost" }, { "(?.?)", "huh" }, { "(^_^?)", "unsure smile" }, { "(-.-?)", "skeptical" },
		{ "(>_>?)", "suspicious look" },
	} },
	{ name = "Shy", items = {
		{ "(^_^;)", "nervous" }, { "(^^;)", "sweat drop" }, { "(//_//)", "blush" }, { "(-_-;)", "awkward" },
		{ "(/ω＼)", "embarrassed" }, { "(*/ω＼*)", "bashful" }, { "(//▽//)", "flustered" },
		{ ">///<", "blushing" }, { "(>///<)", "very shy" }, { "(*///*)", "bashful" }, { "(^///^)", "smiling blush" },
		{ "(//>_<//)", "overwhelmed" }, { "(^_^;;)", "sweating" }, { "(*_*;)", "flustered" }, { "(//^_^//)", "happy blush" },
	} },
	{ name = "Shrug and meh", items = {
		{ "¯\\_(ツ)_/¯", "shrug" }, { "┐(´д`)┌", "whatever" }, { "(・_・)", "blank" }, { "(-_-)", "unimpressed" },
		{ "(-.-)", "bored" }, { "(~_~)", "tired" }, { "(=_=)", "exhausted" }, { "(¬‿¬)", "smug" },
		{ "(._.)", "awkward silence" }, { "(-_-)zzz", "sleeping" },
		{ "(-__-)", "deadpan" }, { "(= =)", "flat" }, { "(=_=;)", "weary" }, { "(-_-;;)", "uncomfortable" },
	} },
	{ name = "Cool and sleepy", items = {
		{ "B-)", "cool" }, { "8-)", "shades" }, { "(B-)", "sunglasses" },
		{ "(-.-)Zzz...", "snoozing" }, { "(-_-)zzZ", "dozing" }, { "(u_u)zzz", "napping" }, { "(-o-)zzz", "deep sleep" },
		{ "(x_x)", "knocked out" }, { "(X_X)", "dead" },
	} },
	{ name = "Animals", items = {
		{ "(=^.^=)", "cat" }, { "=^..^=", "cat" }, { "(^._.^)~", "cat" }, { "(=^･ω･^=)", "cute cat" },
		{ "ʕ•ᴥ•ʔ", "bear" }, { "ʕ·ᴥ·ʔ", "bear" }, { "(◕ᴥ◕ʋ)", "dog" }, { "U･ᴥ･U", "puppy" },
		{ "V●ᴥ●V", "dog" },
		{ "(=^-^=)", "calm cat" }, { "(^..^)", "cat face" }, { "(^.^)~", "cat tail" }, { "(=^o^=)", "happy cat" },
		{ "~(=^..^)", "walking cat" }, { "=^.^=", "cat" }, { "><>", "fish" }, { "<><", "fish" },
		{ "><(((('>", "big fish" }, { "(V)(;,,;)(V)", "crab" },
	} },
	{ name = "Actions", items = {
		{ "(づ｡◕‿‿◕｡)づ", "hug" }, { "(つ≧▽≦)つ", "big hug" }, { "(っ˘ω˘ς )", "cuddle" },
		{ "(⌐■_■)", "cool" }, { "(ง •̀_•́)ง", "fight" }, { "~(˘▾˘~)", "dance" }, { "(~˘▾˘)~", "dance" },
		{ "♪(´▽`)", "music" }, { "(•_•) ( •_•)>⌐■-■ (⌐■_■)", "deal with it" },
		{ "(>^_^)><(^_^<)", "hug" }, { "o/\\o", "high five" }, { "\\o/", "praise" }, { "\\m/", "rock on" },
		{ "o7", "salute" }, { "_o/", "lunge" }, { "\\o_", "fall" },
	} },
	{ name = "Table flip", items = {
		{ "(╯°□°）╯︵ ┻━┻", "flip" }, { "┬─┬ノ( º _ ºノ)", "unflip" },
		{ "┻━┻ ︵ヽ(`Д´)ﾉ︵ ┻━┻", "double flip" }, { "(ノಠ益ಠ)ノ彡┻━┻", "rage flip" },
		{ "(ノ°益°)ノ", "fury" },
	} },
	{ name = "Greetings", items = {
		{ "(^_^)/", "hello" }, { "(＾▽＾)ノ", "hi" }, { "m(_ _)m", "bow" }, { "<(_ _)>", "bow" },
		{ "(^^)/~~~", "bye" }, { "(*´▽`*)ノ", "hey" },
		{ "o/", "wave" }, { "\\o", "waving" }, { "( ^_^)/", "hey there" }, { "(^_^)/~~~", "see you" },
		{ "(^.^)/", "hello" }, { "(_ _)", "small bow" },
	} },
	{ name = "Classic smileys", items = {
		{ ":)", "smile" }, { ":D", "big grin" }, { ":P", "tongue out" }, { ":(", "sad" }, { ":O", "surprised" },
		{ ":/", "unsure" }, { ":3", "cute" }, { ":>", "smirk" }, { ":]", "grin" }, { ":[", "frown" },
		{ ":S", "worried" }, { ":*", "kiss" }, { "=)", "smile" }, { "=D", "grin" }, { "XD", "laughing" },
		{ "xD", "laughing hard" }, { "B)", "cool" }, { "8)", "cool" }, { ";)", "wink" }, { ";P", "playful wink" },
		{ ">:)", "evil grin" }, { ">:D", "evil laugh" }, { "O:)", "innocent angel" }, { "^^", "happy" },
		{ "^_^", "happy" }, { "-_-", "unimpressed" }, { ">_>", "side glance right" }, { "<_<", "side glance left" },
		{ "0_0", "wide eyes" },
	} },
	{ name = "Objects", items = {
		{ "@}->--", "rose" }, { "@};-", "rose" }, { "c[_]", "coffee" }, { "d[-_-]b", "headphones" },
	} },
	{ name = "Extended (needs glyphs)", items = {
		{ "(≧ω≦)", "happy" }, { "(╥ω╥)", "teary" }, { "(≧Д≦)", "overjoyed" }, { "(╥Д╥)", "sobbing" },
		{ "(;Д;)", "tears" }, { "(≧﹏≦)", "squinting" }, { "(≧▽≦)/", "cheerful wave" }, { "(*≧▽≦)", "delighted" },
	} },
}

C:Register("kaomojiSource", function()
	local built
	local function build()
		local out = {}
		for _, cat in ipairs(CATEGORIES) do
			local items = {}
			for _, pair in ipairs(cat.items) do
				local text = pair[1]
				items[#items + 1] = {
					text = text,
					label = pair[2],
					ascii = not string.find(text, "[\128-\255]"),
					hay = string.lower(pair[2] .. " " .. cat.name),
				}
			end
			out[#out + 1] = { name = cat.name, items = items }
		end
		return out
	end
	return {
		Get = function()
			if not built then built = build() end
			return built
		end,
	}
end)
