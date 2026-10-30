-- TwitchEmotes+ : Main.lua
-- Composition root. The only file that decides which implementation backs
-- which service; everything else receives its collaborators by injection.

local TEP = TwitchEmotesPlus
local C = TEP.Container

local DEFAULTS = { asciiOnly = false, alwaysShow = false }

C:Register("db", function() return TwitchEmotesPlusDB end)

C:Register("picker", function(c)
	return TEP.NewPicker({
		catalog   = c:Resolve("emoteCatalog"),
		kaomoji   = c:Resolve("kaomojiSource"),
		resolver  = c:Resolve("textureResolver"),
		inserter  = c:Resolve("inserter"),
		clipboard = c:Resolve("clipboard"),
		db        = c:Resolve("db"),
		print     = TEP.Print,
	})
end)

C:Register("launcher", function(c)
	local up = c:Resolve("upstream")
	return TEP.NewLauncher({
		resolver  = c:Resolve("textureResolver"),
		db        = c:Resolve("db"),
		editBox   = up.editBox,
		getPicker = function() return c:Resolve("picker") end,
	})
end)

-- slash commands ------------------------------------------------------------
local function status()
	local up = C:Resolve("upstream")
	TEP.Print("v" .. TEP.version .. " status")
	local function line(ok, text)
		DEFAULT_CHAT_FRAME:AddMessage((ok and "|cff40ff40 ok  |r" or "|cffff4040 missing |r") .. text)
	end
	line(type(up.emoticons()) == "table", "upstream emoticons table")
	line(type(up.defaultpack()) == "table", "upstream defaultpack table")
	line(type(up.animation()) == "table", "upstream animation metadata (icons stay static without it)")
	line(up.editBox() ~= nil, "chat edit box")
	local cat = C:Resolve("emoteCatalog").Get()
	DEFAULT_CHAT_FRAME:AddMessage(" catalog: " .. cat.total .. " emotes in " .. #cat.packs .. " packs")
	for name in pairs(C.overridden) do
		DEFAULT_CHAT_FRAME:AddMessage(" |cffffd200overridden service:|r " .. name)
	end
	for _, m in ipairs(C:Resolve("clientMods")) do
		line(m.found, m.name .. " - " .. m.note)
	end
end

SLASH_TWITCHEMOTESPLUS1 = "/tep"
SLASH_TWITCHEMOTESPLUS2 = "/emotepicker"
SlashCmdList["TWITCHEMOTESPLUS"] = function(msg)
	local cmd = string.lower(string.match(msg or "", "^%s*(%S*)") or "")
	local db = TwitchEmotesPlusDB
	if cmd == "" or cmd == "toggle" then
		C:Resolve("picker").Toggle()
	elseif cmd == "status" then
		status()
	elseif cmd == "ascii" then
		db.asciiOnly = not db.asciiOnly
		TEP.Print("ASCII-only kaomoji: " .. (db.asciiOnly and "on" or "off") .. " (applies next time the picker opens)")
	elseif cmd == "always" then
		db.alwaysShow = not db.alwaysShow
		TEP.Print("button always visible: " .. (db.alwaysShow and "on" or "off"))
	else
		TEP.Print("/tep  toggle the picker")
		TEP.Print("/tep status  show what was detected and used")
		TEP.Print("/tep ascii  toggle ASCII-only kaomoji")
		TEP.Print("/tep always  keep the button visible outside typing")
	end
end

-- lifecycle ------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(a, b, c)
	local ev = b or event
	local name = c or arg1
	if ev ~= "ADDON_LOADED" or name ~= "TwitchEmotesPlus" then return end
	f:UnregisterEvent("ADDON_LOADED")

	TwitchEmotesPlusDB = TwitchEmotesPlusDB or {}
	for k, v in pairs(DEFAULTS) do
		if TwitchEmotesPlusDB[k] == nil then TwitchEmotesPlusDB[k] = v end
	end

	-- the launcher button needs the edit box and (optionally) upstream data;
	-- a failure here must never take the rest of the UI down with it
	local ok, err = pcall(function() C:Resolve("launcher") end)
	if not ok then TEP.Print("could not create the picker button: " .. tostring(err)) end

	if not C:Resolve("upstream").ready() then
		TEP.Print("TwitchEmotes data not found. Kaomoji still work; emote packs need TwitchEmotes loaded.")
	end
end)
