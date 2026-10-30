-- Stock-client fallback. Written in plain Lua 5.0 on purpose (no #, %, ...):
-- the real add-on uses 5.1 syntax that only exists once ClassicAPI is loaded,
-- and ClassicAPI picks TwitchEmotesPlus_ClassicAPI.toc over this file.
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()
	f:UnregisterEvent("PLAYER_ENTERING_WORLD")
	DEFAULT_CHAT_FRAME:AddMessage("TwitchEmotes+ is disabled: the ClassicAPI DLL isn't loaded. https://github.com/brues-code/ClassicAPI/releases/latest", 1, 0.3, 0.3)
end)
