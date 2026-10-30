-- TwitchEmotes+ : Data/Yahoo.lua
-- Yahoo Messenger's classic text smiley codes as their own service and their
-- own dropdown. They are inserted as TEXT; Yahoo's yellow face images are not
-- included. Codes containing a pipe or percent character are left out because
-- WoW chat treats those specially.
--
-- Twitch emotes take priority: the picker checks every Twitch emote code (exact
-- match first, then ignoring case) and, when a Yahoo code matches one, shows
-- and inserts that Twitch emote instead. See UI/Picker.lua (findTwitch).
--
-- Some codes start with ":" followed by two or more characters, which
-- TwitchEmotes' own ":" autocomplete may react to.
--
-- Replace or extend with
--   TwitchEmotesPlus.Container:Override("yahooSource", function() ... end)
-- returning { Get = function() return { {name=, items={ {text=,label=}, ... }}, ... } end }

local TEP = TwitchEmotesPlus
local C = TEP.Container

local CATEGORIES = {
	{ name = "Smiles and laughs", items = {
		{ ":)", "happy" }, { ";)", "winking" }, { ":D", "big grin" }, { ";;)", "batting eyelashes" },
		{ ":>", "smug" }, { "B-)", "cool" }, { ":))", "laughing" }, { "=))", "rolling on the floor" },
		{ ";))", "hee hee" }, { "O:-)", "angel" }, { ">:)", "devil" }, { "<:-P", "party" },
		{ ":P", "tongue out" }, { ">:P", "raspberry" }, { "8-}", "silly" }, { ":O)", "clown" },
		{ "=D>", "applause" }, { "^:)^", "not worthy" }, { ":-bd", "thumbs up" },
	} },
	{ name = "Love", items = {
		{ ":x", "love struck" }, { ":-*", "kiss" }, { "=((", "broken heart" }, { ":\">", "blushing" },
		{ ">:D<", "big hug" }, { ":o3", "puppy dog eyes" }, { "$-)", "money eyes" },
	} },
	{ name = "Sad and angry", items = {
		{ ":(", "sad" }, { ":((", "crying" }, { "X(", "angry" }, { ":-S", "worried" },
		{ "#:-S", "whew" }, { ":-<", "sigh" }, { "L-)", "loser" }, { ":-&", "sick" },
		{ "~X(", "at wits end" }, { "b-(", "beat up" }, { "[-(", "not talking" }, { ":-@", "chatterbox" },
		{ ">:/", "bring it on" }, { ":-L", "frustrated" }, { ":-q", "thumbs down" },
	} },
	{ name = "Thinking and reactions", items = {
		{ ":-/", "confused" }, { ":-O", "surprise" }, { ":-?", "thinking" }, { ":-??", "i dont know" },
		{ "#-o", "d'oh" }, { ":-SS", "nail biting" }, { "I-)", "sleepy" }, { "@-)", "hypnotized" },
		{ ":^o", "liar" }, { ":-w", "waiting" }, { "=;", "talk to the hand" }, { ":-j", "oh go on" },
		{ "/:)", "raised eyebrow" }, { "x_x", "cant look" }, { ":-B", "nerd" }, { ":!!", "hurry up" },
		{ "^#(^", "it wasnt me" }, { ":-$", "keep it secret" }, { "=P~", "drooling" }, { "8->", "daydreaming" },
	} },
	{ name = "Characters and animals", items = {
		{ "<):)", "cowboy" }, { ":@)", "pig" }, { "3:-O", "cow" }, { "~:>", "chicken" },
		{ ">-)", "alien" }, { "=:)", "bug" }, { ":bz", "bee" }, { "8-X", "skull" },
	} },
	{ name = "Objects and gestures", items = {
		{ "@};-", "rose" }, { "**==", "flag" }, { "~O)", "coffee" }, { "*-:)", "idea" },
		{ "(*)", "star" }, { "[-O<", "praying" }, { ":-c", "call me" }, { ":)]", "on the phone" },
		{ ":-h", "wave" }, { ":-t", "time out" }, { "\\m/", "rock on" }, { ":-\"", "whistling" },
	} },
}

C:Register("yahooSource", function()
	local built
	local function build()
		local out = {}
		for _, cat in ipairs(CATEGORIES) do
			local items = {}
			for _, pair in ipairs(cat.items) do
				items[#items + 1] = {
					text = pair[1],
					label = pair[2],
					ascii = true,
					hay = string.lower(pair[1] .. " " .. pair[2] .. " " .. cat.name),
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
