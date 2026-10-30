-- TwitchEmotes+ : UI/Launcher.lua
-- The button beside the chat edit box that opens the picker. No hooks on
-- Blizzard or upstream code: visibility is driven by a light poll of the edit
-- box, so pfUI-style chat replacements and upstream updates cannot break it.
--
-- NewLauncher(deps): deps = { resolver, db, editBox (function), getPicker (function) }

local TEP = TwitchEmotesPlus

local ICON_KEYS = { "Kappa", "LUL", "EZ" }
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_Note_01"

function TEP.NewLauncher(deps)
	local L = {}
	local db = deps.db

	local btn = CreateFrame("Button", "TwitchEmotesPlusButton", UIParent)
	btn:SetWidth(24)
	btn:SetHeight(24)
	btn:SetFrameStrata("HIGH")
	btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
	btn:Hide()

	local icon = btn:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints(btn)
	icon:SetTexture(FALLBACK_ICON)
	for _, key in ipairs(ICON_KEYS) do
		local tx = deps.resolver.Resolve(key)
		if tx then
			icon:SetTexture(tx.path)
			icon:SetTexCoord(tx.l, tx.r, tx.t, tx.b)
			break
		end
	end

	local function place()
		btn:ClearAllPoints()
		local eb = deps.editBox()
		if eb then
			btn:SetPoint("LEFT", eb, "RIGHT", 4, 0)
		else
			btn:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 8, 150)
		end
	end

	btn:RegisterForClicks("LeftButtonUp")
	btn:SetScript("OnClick", function() deps.getPicker().Toggle() end)
	btn:SetScript("OnEnter", function()
		GameTooltip:SetOwner(btn, "ANCHOR_TOP")
		GameTooltip:SetText("Emote picker", 1, 0.82, 0)
		GameTooltip:AddLine("Click to browse emotes and kaomoji.", 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- show with the chat edit box (or always, if the user asked for that)
	local driver = CreateFrame("Frame")
	local since = 0
	driver:SetScript("OnUpdate", function(a, b)
		since = since + (b or arg1 or 0)
		if since < 0.15 then return end
		since = 0
		local eb = deps.editBox()
		local want = db.alwaysShow or (eb and eb:IsVisible())
		if want then
			if not btn:IsShown() then place(); btn:Show() end
		elseif btn:IsShown() then
			btn:Hide()
		end
	end)

	L.button = btn
	return L
end
