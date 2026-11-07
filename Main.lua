-- TwitchEmotes+ : Main.lua
-- Composition root. The only file that decides which implementation backs
-- which service; everything else receives its collaborators by injection.

local TEP = TwitchEmotesPlus
local C = TEP.Container

local DEFAULTS = { asciiOnly = false, alwaysShow = false, yahooChat = true, yahooAnim = true, yahooStyle = "advanced" }

C:Register("db", function() return TwitchEmotesPlusDB end)

C:Register("picker", function(c)
	return TEP.NewPicker({
		catalog   = c:Resolve("emoteCatalog"),
		kaomoji   = c:Resolve("kaomojiSource"),
		yahoo     = c:Resolve("yahooSource"),
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
	local ys = C:Resolve("yahooSource")
	DEFAULT_CHAT_FRAME:AddMessage(" Yahoo art style: " .. ((ys.GetStyle and ys.GetStyle()) or "n/a"))
	local y = C:Resolve("yahooChat")
	line(y.installed, "Yahoo chat images: " .. (y.installed and ((y.active and "on" or "off") .. ", animation " ..
	     (y.animActive and "on" or "off") .. ", " .. y.count .. " codes active") or "not installed (ChatFrame_OnEvent not found)"))
	if #y.deferred > 0 then
		DEFAULT_CHAT_FRAME:AddMessage(" Yahoo codes left to Twitch emotes: " .. table.concat(y.deferred, " "))
	end
	for name in pairs(C.overridden) do
		DEFAULT_CHAT_FRAME:AddMessage(" |cffffd200overridden service:|r " .. name)
	end
	for _, m in ipairs(C:Resolve("clientMods")) do
		line(m.found, m.name .. " - " .. m.note)
	end
end

-- overlap report ---------------------------------------------------------------
-- For every text-code set registered as a "<name>Source" service (kaomoji,
-- yahoo, and any set added later), lists which codes are also Twitch emote
-- codes (exact, then ignoring case) and which codes appear in more than one set.
local function printChunks(prefix, list)
	if #list == 0 then
		DEFAULT_CHAT_FRAME:AddMessage(prefix .. " none")
		return
	end
	local line = prefix
	for i = 1, #list do
		local piece = " " .. list[i]
		if string.len(line) + string.len(piece) > 190 then
			DEFAULT_CHAT_FRAME:AddMessage(line)
			line = "   " .. list[i]
		else
			line = line .. piece
		end
	end
	DEFAULT_CHAT_FRAME:AddMessage(line)
end

local function overlap()
	local cat = C:Resolve("emoteCatalog").Get()
	local lc = {}
	for _, it in ipairs(cat.all) do
		if not lc[it.lc] then lc[it.lc] = it end
	end
	local names = {}
	for name in pairs(C.factories) do
		if string.find(name, "Source$") then names[#names + 1] = name end
	end
	table.sort(names)

	TEP.Print("overlap report. Twitch emote codes checked: " .. cat.total)
	local owners = {}
	for _, name in ipairs(names) do
		local label = (string.gsub(name, "Source$", ""))
		local src = C:Resolve(name)
		local seen, count, hits = {}, 0, {}
		for _, group in ipairs(src.Get()) do
			for _, it in ipairs(group.items) do
				local code = it.text
				if not seen[code] then
					seen[code] = true
					count = count + 1
					owners[code] = owners[code] or {}
					table.insert(owners[code], label)
					local em = cat.byCode[code] or lc[string.lower(code)]
					if em then hits[#hits + 1] = code .. " => " .. em.code end
				end
			end
		end
		DEFAULT_CHAT_FRAME:AddMessage(" " .. label .. ": " .. count .. " codes, " .. #hits .. " also Twitch emote codes")
		if #hits > 0 then printChunks("   same as Twitch:", hits) end
	end

	local shared = {}
	for code, sets in pairs(owners) do
		if #sets > 1 then shared[#shared + 1] = code .. " [" .. table.concat(sets, "+") .. "]" end
	end
	table.sort(shared)
	printChunks(" in more than one set:", shared)
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
	elseif cmd == "overlap" then
		overlap()
	elseif cmd == "yahoo" then
		db.yahooChat = not db.yahooChat
		C:Resolve("yahooChat").active = db.yahooChat and true or false
		TEP.Print("Yahoo smileys as images in chat: " .. (db.yahooChat and "on" or "off"))
	elseif cmd == "yahoostyle" then
		local ys = C:Resolve("yahooSource")
		local given = string.lower(string.match(msg or "", "^%s*%S+%s+(%S+)") or "")
		local want = given
		if want == "" then
			want = (ys.GetStyle and ys.GetStyle() == "advanced") and "classic" or "advanced"
		end
		if ys.SetStyle and ys.SetStyle(want) then
			db.yahooStyle = want
			TEP.Print("Yahoo art style: " .. want .. " (reopen the picker to refresh it)")
		else
			TEP.Print("Yahoo art style must be classic or advanced")
		end
	elseif cmd == "yahooanim" then
		db.yahooAnim = not db.yahooAnim
		C:Resolve("yahooChat").animActive = db.yahooAnim and true or false
		TEP.Print("Yahoo smiley animation in chat: " .. (db.yahooAnim and "on" or "off"))
	elseif cmd == "ascii" then
		db.asciiOnly = not db.asciiOnly
		TEP.Print("ASCII-only kaomoji: " .. (db.asciiOnly and "on" or "off") .. " (applies next time the picker opens)")
	elseif cmd == "always" then
		db.alwaysShow = not db.alwaysShow
		TEP.Print("button always visible: " .. (db.alwaysShow and "on" or "off"))
	else
		TEP.Print("/tep  toggle the picker")
		TEP.Print("/tep status  show what was detected and used")
		TEP.Print("/tep overlap  list codes shared with Twitch emotes or between sets")
		TEP.Print("/tep ascii  toggle ASCII-only kaomoji")
		TEP.Print("/tep yahoo  toggle Yahoo smileys as images in chat")
		TEP.Print("/tep yahooanim  toggle their animation")
		TEP.Print("/tep yahoostyle [classic|advanced]  switch the Yahoo art")
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

	-- Yahoo smileys in chat; independent of the picker, and it must never break chat
	local okY, errY = pcall(function()
		local ys = C:Resolve("yahooSource")
		if ys.SetStyle then ys.SetStyle(TwitchEmotesPlusDB.yahooStyle) end
		local y = C:Resolve("yahooChat")
		y.active = TwitchEmotesPlusDB.yahooChat and true or false
		y.animActive = TwitchEmotesPlusDB.yahooAnim and true or false
		if not y.Install() then TEP.Print("Yahoo chat images unavailable: ChatFrame_OnEvent not found") end
	end)
	if not okY then TEP.Print("Yahoo chat images disabled: " .. tostring(errY)) end

	if not C:Resolve("upstream").ready() then
		TEP.Print("TwitchEmotes data not found. Kaomoji still work; emote packs need TwitchEmotes loaded.")
	end
end)
