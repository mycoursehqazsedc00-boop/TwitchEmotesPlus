-- TwitchEmotes+ : Data/Kaomoji.lua
-- Kaomoji (Japanese emoticons) as a service. Each item is { text, label }.
-- `ascii` is computed below: items using only 7-bit characters render in any
-- font and survive any chat path; the rest need a font with the glyphs
-- (see README "Kaomoji and fonts"). No item contains a pipe character, which
-- WoW treats as an escape prefix in chat.
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
	} },
	{ name = "Love", items = {
		{ "<3", "heart" }, { "(^3^)", "kiss" }, { "(*^3^)/~<3", "kiss heart" },
		{ "(♥‿♥)", "heart eyes" }, { "(｡♥‿♥｡)", "in love" }, { "(´,,•ω•,,)♡", "cute love" },
		{ "(´∀`)♡", "affection" }, { "(づ￣ ³￣)づ", "kiss hug" }, { "(˘³˘)♥", "smooch" },
		{ "(◍•ᴗ•◍)❤", "sweet love" },
	} },
	{ name = "Sad", items = {
		{ "(T_T)", "cry" }, { "(;_;)", "tears" }, { "(ToT)", "sob" }, { "(T.T)", "crying" },
		{ "(;-;)", "sad" }, { "orz", "despair" }, { "(´;ω;`)", "weeping" }, { "(╥_╥)", "teary" },
		{ "(ಥ_ಥ)", "tearful" }, { "｡･ﾟ･(ﾉД`)･ﾟ･｡", "bawling" }, { "(つ﹏⊂)", "sobbing" },
	} },
	{ name = "Angry", items = {
		{ "(>_<)", "frustrated" }, { ">:(", "angry" }, { "(-_-#)", "annoyed" }, { "(>.<)", "pain" },
		{ "(`Д´)", "furious" }, { "ヽ(`Д´)ﾉ", "rage" }, { "(╬ Ò﹏Ó)", "seething" },
		{ "(¬_¬)", "side eye" }, { "(ಠ_ಠ)", "disapproval" }, { "(｀へ´)", "grumpy" },
	} },
	{ name = "Surprised", items = {
		{ "(O_O)", "shock" }, { "(o_o)", "wide eyed" }, { "(O.O)", "stunned" }, { "(@_@)", "dizzy" },
		{ "(o.O)", "confused" }, { "(°o°)", "gasp" }, { "(⊙_⊙)", "staring" }, { "(°ロ°)", "startled" },
		{ "w(°o°)w", "omg" }, { "(゜o゜)", "amazed" },
	} },
	{ name = "Shy", items = {
		{ "(^_^;)", "nervous" }, { "(^^;)", "sweat drop" }, { "(//_//)", "blush" }, { "(-_-;)", "awkward" },
		{ "(/ω＼)", "embarrassed" }, { "(*/ω＼*)", "bashful" }, { "(//▽//)", "flustered" },
	} },
	{ name = "Shrug and meh", items = {
		{ "¯\\_(ツ)_/¯", "shrug" }, { "┐(´д`)┌", "whatever" }, { "(・_・)", "blank" }, { "(-_-)", "unimpressed" },
		{ "(-.-)", "bored" }, { "(~_~)", "tired" }, { "(=_=)", "exhausted" }, { "(¬‿¬)", "smug" },
		{ "(._.)", "awkward silence" }, { "(-_-)zzz", "sleeping" },
	} },
	{ name = "Animals", items = {
		{ "(=^.^=)", "cat" }, { "=^..^=", "cat" }, { "(^._.^)~", "cat" }, { "(=^･ω･^=)", "cute cat" },
		{ "ʕ•ᴥ•ʔ", "bear" }, { "ʕ·ᴥ·ʔ", "bear" }, { "(◕ᴥ◕ʋ)", "dog" }, { "U･ᴥ･U", "puppy" },
		{ "V●ᴥ●V", "dog" },
	} },
	{ name = "Actions", items = {
		{ "(づ｡◕‿‿◕｡)づ", "hug" }, { "(つ≧▽≦)つ", "big hug" }, { "(っ˘ω˘ς )", "cuddle" },
		{ "(⌐■_■)", "cool" }, { "(ง •̀_•́)ง", "fight" }, { "~(˘▾˘~)", "dance" }, { "(~˘▾˘)~", "dance" },
		{ "♪(´▽`)", "music" }, { "(•_•) ( •_•)>⌐■-■ (⌐■_■)", "deal with it" },
	} },
	{ name = "Table flip", items = {
		{ "(╯°□°）╯︵ ┻━┻", "flip" }, { "┬─┬ノ( º _ ºノ)", "unflip" },
		{ "┻━┻ ︵ヽ(`Д´)ﾉ︵ ┻━┻", "double flip" }, { "(ノಠ益ಠ)ノ彡┻━┻", "rage flip" },
		{ "(ノ°益°)ノ", "fury" },
	} },
	{ name = "Greetings", items = {
		{ "(^_^)/", "hello" }, { "(＾▽＾)ノ", "hi" }, { "m(_ _)m", "bow" }, { "<(_ _)>", "bow" },
		{ "(^^)/~~~", "bye" }, { "(*´▽`*)ノ", "hey" },
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
