-- TwitchEmotes+ : Adapters/YahooChat.lua
-- Turns Yahoo smiley codes in incoming chat into their images, and animates
-- them. TwitchEmotes' own replacement cannot carry these codes: it splits text on
-- "space , ' < > ? - . !" and drops each word unescaped into a Lua pattern, so a
-- code like ":-/" or ":)" would never match as one word (or would raise a pattern
-- error). This service therefore does its own whole-token match.
--
-- Rules:
--   * only whole whitespace-separated tokens are replaced, case-insensitively
--   * a code that is also a Twitch emote code is left alone (Twitch has priority);
--     this is decided when the filter is installed, from upstream's own table
--   * "|" travels as "||" on the wire, so those codes are matched in that form
--   * upstream's per-chat-type switches (Emoticons_Settings) are honoured
-- The only thing wrapped is Blizzard's ChatFrame_OnEvent, by name, defensively;
-- if that function is missing the service reports it and does nothing.

local TEP = TwitchEmotesPlus
local C = TEP.Container

C:Register("yahooChat", function(c)
	local up = c:Resolve("upstream")
	local src = c:Resolve("yahooSource")

	local M = { active = false, animActive = false, installed = false, count = 0, deferred = {} }
	local byToken = {}   -- lower-case wire form of a code -> item
	local byFile = {}    -- "Folder/sheet" -> image (both art styles, for the animator)

	local function wire(code) return (string.gsub(code, "|", "||")) end

	-- |Tpath:height:width:0:0:sheetW:sheetH:left:right:top:bottom|t  (frame `n`)
	local function escapeFor(img, n)
		local cols = math.floor(img.iw / img.fw)
		if cols < 1 then cols = 1 end
		local left = (n % cols) * img.fw
		local top = math.floor(n / cols) * img.fh
		return string.format("|T%s:%d:%d:0:0:%d:%d:%d:%d:%d:%d|t", img.path, img.dh, img.dw,
		                     img.iw, img.ih, left, left + img.fw, top, top + img.fh)
	end

	function M.Build()
		byToken, byFile, M.count, M.deferred = {}, {}, 0, {}
		local emo = up.emoticons()
		local twitch = {}
		if type(emo) == "table" then
			for k in pairs(emo) do twitch[string.lower(k)] = true end
		end
		for _, cat in ipairs(src.Get()) do
			for _, it in ipairs(cat.items) do
				if it.img then
					for _, img in pairs(it.imgs or { it.img }) do
						if img.key then byFile[img.key] = img end
					end
					local token = string.lower(wire(it.text))
					if twitch[string.lower(it.text)] then
						M.deferred[#M.deferred + 1] = it.text      -- Twitch emote owns this code
					elseif not byToken[token] then
						byToken[token] = it
						M.count = M.count + 1
					end
				end
			end
		end
	end

	-- NOTE: the client's string library is Lua 5.0's. There, a gsub callback that
	-- returns nothing replaces the match with an empty string (5.1 keeps it), so
	-- every callback in this file returns the original text when it changes nothing.
	local function rewrite(msg)
		return (string.gsub(msg, "%S+", function(tok)
			local it = byToken[string.lower(tok)]
			if it then return escapeFor(it.img, 0) end
			return tok
		end))
	end

	function M.Install()
		if M.installed then return true end
		local prev = _G["ChatFrame_OnEvent"]
		if type(prev) ~= "function" then return false end
		M.Build()
		_G["ChatFrame_OnEvent"] = function(ev, ...)
			if M.active and arg1 and type(ev) == "string" and string.sub(ev, 1, 9) == "CHAT_MSG_" then
				local settings = _G["Emoticons_Settings"]
				if type(settings) ~= "table" or settings[ev] then
					local ok, out = pcall(rewrite, arg1)
					-- a failure, or an empty result for a non-empty message, keeps the original
					if ok and type(out) == "string" and (out ~= "" or arg1 == "") then
						arg1 = out
					end
				end
			end
			return prev(ev, ...)
		end
		M.installed = true
		return true
	end

	-- animation: rewrite the visible chat lines' Yahoo escapes to the current frame,
	-- the same technique TwitchEmotes uses (it only handles its own folder)
	local MARK = "TwitchEmotesPlus\\Emotes\\Yahoo"
	local PAT = "(|TInterface\\AddOns\\TwitchEmotesPlus\\Emotes\\(Yahoo%a*)\\([%w_]+)%.tga:[^|]*|t)"
	local clock, since = 0, 0

	local function updateRegion(region)
		local txt = region:GetText()
		if not txt or not string.find(txt, MARK, 1, true) then return end
		local new = string.gsub(txt, PAT, function(whole, folder, file)
			local img = byFile[folder .. "/" .. file]
			local a = img and img.anim
			if a then
				return escapeFor(img, math.floor((clock * a.framerate) % a.nFrames))
			end
			return whole
		end)
		if new ~= txt and new ~= "" then region:SetText(new) end
	end

	local driver = CreateFrame("Frame")
	driver:SetScript("OnUpdate", function(a, b)
		if not (M.installed and M.animActive) then return end
		local el = b or arg1 or 0
		clock = clock + el
		since = since + el
		if since < 0.1 then return end
		since = 0
		for i = 1, (NUM_CHAT_WINDOWS or 10) do
			local cf = _G["ChatFrame" .. i]
			if cf and cf:IsShown() then
				local regions = { cf:GetRegions() }
				for j = 1, #regions do
					local r = regions[j]
					if r and r:GetObjectType() == "FontString" then updateRegion(r) end
				end
			end
		end
	end)

	return M
end)
