-- TwitchEmotes+ : Adapters/ClientMods.lua
-- Detects the client DLLs so /tep status can report them. Only ClassicAPI is
-- actually used (script args, 5.1 syntax, CopyToClipboard). The others expose
-- nothing a chat-emote picker can use and are reported, not called:
--   SuperWoW        GUIDs / combat events      - no chat or UI surface
--   nampower        spell queue + combat events - no chat or UI surface
--   UnitXP_SP3      distance / line of sight    - not relevant to chat
--   VanillaHelpers  textures, models, file I/O  - not needed (SavedVariables suffice)
--   WeirdUtils      no Lua-facing API

local TEP = TwitchEmotesPlus
local C = TEP.Container

C:Register("clientMods", function()
	local function present(name) return type(_G[name]) == "function" end
	local unitxp = type(_G["UnitXP"]) == "function" and pcall(_G["UnitXP"], "nop", "nop") and true or false
	return {
		{ name = "ClassicAPI",     found = present("CopyToClipboard") or type(_G["C_Timer"]) == "table",
		  note = "required: Lua 5.1 syntax, script args, CopyToClipboard (shift-click copies)" },
		{ name = "SuperWoW",       found = _G["SUPERWOW_VERSION"] ~= nil,  note = "not used (no chat/UI surface)" },
		{ name = "nampower",       found = present("GetNampowerVersion"),  note = "not used (spell queue / combat events)" },
		{ name = "UnitXP_SP3",     found = unitxp,                         note = "not used (distance / line of sight)" },
		{ name = "VanillaHelpers", found = present("ReadFile") and present("SetUnitBlip"), note = "not used (SavedVariables are enough)" },
		{ name = "WeirdUtils",     found = present("GetWeirdUtilsVersion"), note = "not used (no Lua-facing API)" },
	}
end)
