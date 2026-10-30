-- TwitchEmotes+ : UI/Picker.lua
-- Two separate dropdowns at the top, "Twitch Emote" and "Kaomoji". Each opens a
-- scrolling menu of containers (emote packs / kaomoji categories). The chosen
-- container fills a virtualized grid below (only ~80 buttons exist however many
-- emotes there are). Search, recent items and an ASCII-only kaomoji filter.
--
-- NewPicker(deps) takes everything it needs by injection and touches no
-- upstream global; deps = { catalog, kaomoji, resolver, inserter, clipboard,
-- db, print }.
--
-- Script handlers read both positional args and the this/arg1 globals, so they
-- work whether or not ClassicAPI's modern script args are switched on.

local TEP = TwitchEmotesPlus

local POOL = 80
local GRID_W, GRID_H = 360, 288
local MENU_ROWS, MENU_ROW_H, MENU_W = 12, 18, 196
local LAYOUTS = {
	emote = { cols = 10, cw = 36, ch = 36 },
	kao   = { cols = 3,  cw = 120, ch = 24 },
}
LAYOUTS.emote.rows = math.floor(GRID_H / LAYOUTS.emote.ch)
LAYOUTS.kao.rows   = math.floor(GRID_H / LAYOUTS.kao.ch)

local GROUP_LABEL = { emote = "Twitch Emote", kao = "Kaomoji" }
local RECENT_MAX = 30

local PANEL_BACKDROP = {
	bgFile = "Interface\\Buttons\\WHITE8X8",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 8, edgeSize = 12,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

-- ── sprite-sheet animation (same frame layout the upstream animator uses) ────
local function frameNumber(a, t)
	if a.pingpong then
		local v = math.floor((t * a.framerate) % ((a.nFrames * 2) - 1))
		if v > a.nFrames then v = a.nFrames - (v % a.nFrames) end
		if v >= a.nFrames then v = a.nFrames - 1 end
		return v
	end
	return math.floor((t * a.framerate) % a.nFrames)
end

local function cropToFrame(tex, a, t)
	local cols = math.floor(a.imageWidth / a.frameWidth)
	if cols < 1 then cols = 1 end
	local n = frameNumber(a, t)
	local left = (n % cols) * a.frameWidth
	local top = math.floor(n / cols) * a.frameHeight
	tex:SetTexCoord(left / a.imageWidth, (left + a.frameWidth) / a.imageWidth,
	                top / a.imageHeight, (top + a.frameHeight) / a.imageHeight)
end

-- ── a vertical scroller: slider + mouse wheel, offset counted in rows ────────
local function NewScroll(parent, width, height, onChange)
	local s = { offset = 0, max = 0 }
	local f = CreateFrame("Frame", nil, parent)
	f:SetWidth(width)
	f:SetHeight(height)
	f:EnableMouseWheel(true)
	s.frame = f

	local sl = CreateFrame("Slider", nil, f)
	sl:SetWidth(14)
	sl:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
	sl:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
	sl:SetOrientation("VERTICAL")
	sl:SetMinMaxValues(0, 0)
	sl:SetValueStep(1)
	sl:SetValue(0)
	sl:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", tile = true, tileSize = 8 })
	sl:SetBackdropColor(0.15, 0.15, 0.18, 0.8)
	sl:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
	local thumb = sl:GetThumbTexture()
	if thumb then thumb:SetWidth(14); thumb:SetHeight(24) end
	sl:Hide()
	s.slider = sl

	local function clamp(v)
		v = math.floor(v + 0.5)
		if v < 0 then v = 0 elseif v > s.max then v = s.max end
		return v
	end

	function s:SetOffset(v, silent)
		v = clamp(v)
		local changed = (v ~= self.offset)
		self.offset = v
		self.syncing = true
		sl:SetValue(v)
		self.syncing = nil
		if changed and not silent and onChange then onChange(v) end
	end

	-- m = how many rows can be scrolled past the visible window (0 = no scrolling)
	function s:SetMax(m)
		self.max = m
		sl:SetMinMaxValues(0, m)
		if m > 0 then sl:Show() else sl:Hide() end
		if self.offset > m then self:SetOffset(m, true) end
	end

	sl:SetScript("OnValueChanged", function(a, b)
		if s.syncing then return end
		local v = b or arg1
		if v then s:SetOffset(v) end
	end)
	f:SetScript("OnMouseWheel", function(a, b)
		local d = b or arg1
		if d then s:SetOffset(s.offset - d) end
	end)
	return s
end

-- ── picker ───────────────────────────────────────────────────────────────────
function TEP.NewPicker(deps)
	local P = {}
	local db = deps.db

	local cat            -- emote catalog
	local kaoCats        -- kaomoji categories
	local views = {}     -- every selectable container, both groups
	local kaoByText, allKao = {}, {}
	local cur            -- selected container
	local query = ""
	local shown = {}     -- items currently in the grid (after search)
	local layoutKind
	local stash          -- chat text saved so a closed edit box can be restored
	local suppress

	-- frame ------------------------------------------------------------------
	local frame = CreateFrame("Frame", "TwitchEmotesPlusPicker", UIParent)
	frame:SetWidth(404)
	frame:SetHeight(424)
	frame:SetFrameStrata("DIALOG")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetBackdrop(PANEL_BACKDROP)
	frame:SetBackdropColor(0.06, 0.06, 0.08, 0.96)
	frame:SetBackdropBorderColor(1, 1, 1, 1)
	frame:SetScript("OnDragStart", function() frame:StartMoving() end)
	frame:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		P.moved = true
	end)
	frame:Hide()
	if UISpecialFrames then table.insert(UISpecialFrames, "TwitchEmotesPlusPicker") end
	P.frame = frame

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -12)
	title:SetText("Emote picker")

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)

	-- grid pool + scroller are declared first so menus and views can use them ---
	local cells = {}
	local gridScroll
	local RefreshGrid
	local clock, acc = 0, 0

	-- dropdown buttons ---------------------------------------------------------
	local function NewDropButton(x)
		local b = CreateFrame("Button", nil, frame)
		b:SetWidth(186)
		b:SetHeight(22)
		b:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -34)
		b:SetBackdrop(PANEL_BACKDROP)
		b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		local t = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		t:SetPoint("LEFT", b, "LEFT", 8, 0)
		t:SetPoint("RIGHT", b, "RIGHT", -22, 0)
		t:SetJustifyH("LEFT")
		local arrow = b:CreateTexture(nil, "OVERLAY")
		arrow:SetWidth(18)
		arrow:SetHeight(18)
		arrow:SetPoint("RIGHT", b, "RIGHT", -2, 0)
		arrow:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
		b.text = t
		b:RegisterForClicks("LeftButtonUp")
		return b
	end
	local dropBtn = {
		emote = NewDropButton(14),
		kao   = NewDropButton(204),
	}

	local function updateButtons()
		for kind, b in pairs(dropBtn) do
			if cur and cur.kind == kind then
				b.text:SetText(GROUP_LABEL[kind] .. ": " .. cur.name)
				b.text:SetTextColor(1, 0.82, 0)
				b:SetBackdropColor(0.22, 0.18, 0.05, 0.95)
				b:SetBackdropBorderColor(1, 0.82, 0, 1)
			else
				b.text:SetText(GROUP_LABEL[kind])
				b.text:SetTextColor(0.85, 0.85, 0.85)
				b:SetBackdropColor(0.12, 0.12, 0.15, 0.95)
				b:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
			end
		end
	end

	-- search + footer + ascii --------------------------------------------------
	local searchLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	searchLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -65)
	searchLabel:SetText("Search")

	local search = CreateFrame("EditBox", "TwitchEmotesPlusSearch", frame, "InputBoxTemplate")
	search:SetPoint("TOPLEFT", frame, "TOPLEFT", 66, -59)
	search:SetWidth(300)
	search:SetHeight(20)
	search:SetAutoFocus(false)
	search:SetMaxLetters(40)

	local footer = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 30)
	footer:SetTextColor(0.7, 0.7, 0.7)

	local ascii = CreateFrame("CheckButton", "TwitchEmotesPlusASCII", frame, "UICheckButtonTemplate")
	ascii:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 4)
	ascii:SetWidth(24)
	ascii:SetHeight(24)
	local asciiText = _G["TwitchEmotesPlusASCIIText"]
	if asciiText then asciiText:SetText("ASCII-only kaomoji") end

	-- grid cells ---------------------------------------------------------------
	local function textOf(b)
		if not b.item then return nil end
		if b.kind == "emote" then return b.item.code end
		return b.item.text
	end

	local function remember(kind, text)
		local key = (kind == "emote") and "recentEmotes" or "recentKao"
		local list = db[key]
		if not list then list = {}; db[key] = list end
		for i = #list, 1, -1 do
			if list[i] == text then table.remove(list, i) end
		end
		table.insert(list, 1, text)
		while #list > RECENT_MAX do table.remove(list) end
	end

	local function onCellClick(b)
		local text = textOf(b)
		if not text then return end
		if IsShiftKeyDown() then
			if deps.clipboard.Available() then
				deps.clipboard.Copy(text)
				deps.print("copied " .. text .. " to the clipboard")
			else
				deps.print("clipboard unavailable (needs ClassicAPI)")
			end
			return
		end
		deps.inserter.Insert(text .. " ", stash)
		stash = nil
		remember(b.kind, text)
	end

	local function onCellEnter(b)
		if not b.item then return end
		GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
		if b.kind == "emote" then
			GameTooltip:SetText(b.item.code, 1, 0.82, 0)
		else
			GameTooltip:SetText(b.item.label or "kaomoji", 1, 0.82, 0)
			GameTooltip:AddLine(b.item.text, 1, 1, 1)
		end
		GameTooltip:AddLine("Click: insert. Shift-click: copy.", 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end

	local function bindCell(b, item, kind)
		b.item, b.kind = item, kind
		if kind == "emote" then
			b.lbl:Hide()
			local tx = deps.resolver.Resolve(item.key)
			if tx then
				b.ico:SetTexture(tx.path)
				b.ico:SetTexCoord(tx.l, tx.r, tx.t, tx.b)
				b.anim = tx.anim
				if b.anim then cropToFrame(b.ico, b.anim, clock) end
				b.ico:Show()
			else
				b.anim = nil
				b.ico:Hide()
			end
		else
			b.anim = nil
			b.ico:Hide()
			b.lbl:SetText(item.text)
			b.lbl:Show()
		end
	end

	RefreshGrid = function()
		local L = LAYOUTS[layoutKind or "emote"]
		local first = gridScroll.offset * L.cols
		local visible = L.cols * L.rows
		for i = 1, POOL do
			local b = cells[i]
			local item = (i <= visible) and shown[first + i] or nil
			if item then
				bindCell(b, item, cur.kind)
				b:Show()
			else
				b.item, b.anim = nil, nil
				b:Hide()
			end
		end
	end

	gridScroll = NewScroll(frame, GRID_W + 18, GRID_H, function() RefreshGrid() end)
	gridScroll.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -88)

	for i = 1, POOL do
		local b = CreateFrame("Button", nil, gridScroll.frame)
		cells[i] = b
		b:Hide()
		b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
		local ico = b:CreateTexture(nil, "ARTWORK")
		ico:SetWidth(28)
		ico:SetHeight(28)
		ico:SetPoint("CENTER", b, "CENTER", 0, 0)
		local lbl = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		lbl:SetPoint("LEFT", b, "LEFT", 4, 0)
		lbl:SetPoint("RIGHT", b, "RIGHT", -2, 0)
		lbl:SetJustifyH("LEFT")
		b.ico, b.lbl = ico, lbl
		b:RegisterForClicks("LeftButtonUp")
		b:SetScript("OnClick", function() onCellClick(b) end)
		b:SetScript("OnEnter", function() onCellEnter(b) end)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	end

	local function applyLayout(kind)
		if layoutKind == kind then return end
		layoutKind = kind
		local L = LAYOUTS[kind]
		for i = 1, POOL do
			local b = cells[i]
			local idx = i - 1
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", gridScroll.frame, "TOPLEFT",
			           (idx % L.cols) * L.cw, -math.floor(idx / L.cols) * L.ch)
			b:SetWidth(L.cw)
			b:SetHeight(L.ch)
		end
	end

	-- animate the visible sprite-sheet icons (~30 fps; only runs while shown)
	frame:SetScript("OnUpdate", function(a, b)
		local el = b or arg1 or 0
		clock = clock + el
		acc = acc + el
		if acc < 0.033 then return end
		acc = 0
		for i = 1, POOL do
			local c = cells[i]
			if c.anim and c:IsShown() then cropToFrame(c.ico, c.anim, clock) end
		end
	end)

	-- dropdown menu (a scrolling list of containers) ---------------------------
	local menu = CreateFrame("Frame", "TwitchEmotesPlusMenu", UIParent)
	menu:SetFrameStrata("FULLSCREEN_DIALOG")
	menu:SetWidth(MENU_W + 26)
	menu:SetHeight(MENU_ROWS * MENU_ROW_H + 12)
	menu:SetBackdrop(PANEL_BACKDROP)
	menu:SetBackdropColor(0.05, 0.05, 0.07, 0.98)
	menu:SetBackdropBorderColor(1, 0.82, 0, 1)
	menu:EnableMouse(true)
	menu:Hide()

	-- full-screen click catcher that sits between the picker and the menu
	local catcher = CreateFrame("Button", nil, UIParent)
	catcher:SetFrameStrata("FULLSCREEN")
	catcher:SetAllPoints(UIParent)
	catcher:EnableMouse(true)
	catcher:Hide()

	local menuItems, menuGroup = {}, nil
	local menuRows = {}
	local menuScroll
	local SelectView

	local function RefreshMenu()
		local off = menuScroll.offset
		for i = 1, MENU_ROWS do
			local row = menuRows[i]
			local v = menuItems[off + i]
			if v then
				row.view = v
				row.text:SetText(v.header or v.label or v.name)
				if v.header then
					row.text:SetTextColor(0.7, 0.7, 0.7)
					row.sel:Hide()
				elseif v == cur then
					row.text:SetTextColor(1, 1, 1)
					row.sel:Show()
				else
					row.text:SetTextColor(0.85, 0.85, 0.85)
					row.sel:Hide()
				end
				row:Show()
			else
				row.view = nil
				row:Hide()
			end
		end
	end

	menuScroll = NewScroll(menu, MENU_W + 18, MENU_ROWS * MENU_ROW_H, function() RefreshMenu() end)
	menuScroll.frame:SetPoint("TOPLEFT", menu, "TOPLEFT", 6, -6)

	local function CloseMenu()
		menu:Hide()
		catcher:Hide()
		menuGroup = nil
	end

	for i = 1, MENU_ROWS do
		local row = CreateFrame("Button", nil, menuScroll.frame)
		row:SetWidth(MENU_W)
		row:SetHeight(MENU_ROW_H)
		row:SetPoint("TOPLEFT", menuScroll.frame, "TOPLEFT", 0, -(i - 1) * MENU_ROW_H)
		row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
		local sel = row:CreateTexture(nil, "BACKGROUND")
		sel:SetAllPoints(row)
		sel:SetTexture("Interface\\Buttons\\WHITE8X8")
		sel:SetVertexColor(0.3, 0.3, 0.5, 0.6)
		sel:Hide()
		local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		text:SetPoint("LEFT", row, "LEFT", 6, 0)
		text:SetPoint("RIGHT", row, "RIGHT", -2, 0)
		text:SetJustifyH("LEFT")
		row.sel, row.text = sel, text
		row:SetScript("OnClick", function()
			if row.view and not row.view.header then
				SelectView(row.view)
				CloseMenu()
			end
		end)
		menuRows[i] = row
	end

	catcher:SetScript("OnClick", CloseMenu)
	frame:SetScript("OnHide", CloseMenu)

	local function OpenMenu(group)
		if menuGroup == group then
			CloseMenu()
			return
		end
		menuItems = {}
		for _, v in ipairs(views) do
			if v.kind == group then menuItems[#menuItems + 1] = v end
		end
		if #menuItems == 0 then
			menuItems[1] = { header = (group == "emote") and "(TwitchEmotes data not found)" or "(no kaomoji to show)" }
		end
		menuGroup = group
		menuScroll:SetMax(math.max(0, #menuItems - MENU_ROWS))
		menuScroll:SetOffset(0, true)
		for i, v in ipairs(menuItems) do
			if v == cur then menuScroll:SetOffset(i - 1, true); break end
		end
		menu:ClearAllPoints()
		menu:SetPoint("TOPLEFT", dropBtn[group], "BOTTOMLEFT", 0, -2)
		catcher:Show()
		menu:Show()
		RefreshMenu()
	end

	dropBtn.emote:SetScript("OnClick", function() OpenMenu("emote") end)
	dropBtn.kao:SetScript("OnClick", function() OpenMenu("kao") end)

	-- data -------------------------------------------------------------------
	local function itemsOf(view)
		if view.recent then
			local out = {}
			local list = db[view.recent] or {}
			for i = 1, #list do
				local it
				if view.kind == "emote" then
					it = cat.byCode[list[i]]
				else
					it = kaoByText[list[i]]
					if it and db.asciiOnly and not it.ascii then it = nil end
				end
				if it then out[#out + 1] = it end
			end
			return out
		end
		return view.items
	end

	local function buildViews()
		cat = deps.catalog.Get()
		kaoCats = deps.kaomoji.Get()
		views, kaoByText, allKao = {}, {}, {}

		if cat.available then
			views[#views + 1] = { id = "emote/recent", kind = "emote", name = "Recent", recent = "recentEmotes" }
			views[#views + 1] = { id = "emote/all", kind = "emote", name = "All emotes",
			                      label = "All emotes (" .. cat.total .. ")", items = cat.all }
			for _, p in ipairs(cat.packs) do
				views[#views + 1] = { id = "emote/pack/" .. p.name, kind = "emote", name = p.name,
				                      label = p.name .. " (" .. #p.items .. ")", items = p.items }
			end
		end

		local kaoViews = {}
		for _, c in ipairs(kaoCats) do
			local items = {}
			for _, it in ipairs(c.items) do
				kaoByText[it.text] = it
				if not db.asciiOnly or it.ascii then
					items[#items + 1] = it
					allKao[#allKao + 1] = it
				end
			end
			if #items > 0 then
				kaoViews[#kaoViews + 1] = { id = "kao/cat/" .. c.name, kind = "kao", name = c.name,
				                            label = c.name .. " (" .. #items .. ")", items = items }
			end
		end
		views[#views + 1] = { id = "kao/recent", kind = "kao", name = "Recent", recent = "recentKao" }
		if #allKao > 0 then
			views[#views + 1] = { id = "kao/all", kind = "kao", name = "All kaomoji",
			                      label = "All kaomoji (" .. #allKao .. ")", items = allKao }
		end
		for _, v in ipairs(kaoViews) do views[#views + 1] = v end
	end

	local function findView(id)
		for _, v in ipairs(views) do
			if v.id == id then return v end
		end
	end

	local function firstView()
		return findView("emote/all") or findView("kao/all") or findView("kao/recent")
	end

	local function filter(items, q)
		if q == "" then return items end
		local out = {}
		for i = 1, #items do
			local it = items[i]
			if string.find(it.lc or it.hay or "", q, 1, true) then out[#out + 1] = it end
		end
		return out
	end

	local function Recompute()
		local L = LAYOUTS[cur.kind]
		applyLayout(cur.kind)
		local base
		if query ~= "" then
			base = (cur.kind == "emote") and cat.all or allKao
		else
			base = itemsOf(cur)
		end
		shown = filter(base, query)
		local totalRows = math.ceil(#shown / L.cols)
		gridScroll:SetMax(math.max(0, totalRows - L.rows))
		gridScroll:SetOffset(0, true)
		RefreshGrid()
		updateButtons()
		if query ~= "" then
			footer:SetText("Search in all " .. ((cur.kind == "emote") and "emotes" or "kaomoji") .. ": " .. #shown .. " found")
		else
			footer:SetText(GROUP_LABEL[cur.kind] .. " / " .. cur.name .. ": " .. #shown .. ". Click inserts, shift-click copies.")
		end
	end

	SelectView = function(view)
		cur = view
		db.lastView = view.id
		suppress = true
		search:SetText("")
		suppress = nil
		query = ""
		Recompute()
	end

	search:SetScript("OnTextChanged", function()
		if suppress then return end
		query = string.lower(search:GetText() or "")
		if cur then Recompute() end
	end)
	search:SetScript("OnEnterPressed", function() search:ClearFocus() end)
	search:SetScript("OnEscapePressed", function() search:ClearFocus() end)
	search:SetScript("OnEditFocusGained", function()
		local snap = deps.inserter.Snapshot()
		if snap then stash = snap end
	end)

	ascii:SetScript("OnClick", function()
		db.asciiOnly = ascii:GetChecked() and true or false
		local keep = cur and cur.id
		buildViews()
		local v = (keep and findView(keep)) or firstView()
		if v then SelectView(v) end
	end)

	-- public -----------------------------------------------------------------
	function P.Open()
		buildViews()
		stash = deps.inserter.Snapshot()
		ascii:SetChecked(db.asciiOnly and true or false)
		local v = (db.lastView and findView(db.lastView)) or firstView()
		if not v then
			deps.print("nothing to show: no TwitchEmotes data and no kaomoji")
			return
		end
		if not P.moved then
			frame:ClearAllPoints()
			local eb = _G["ChatFrameEditBox"]
			if eb then
				frame:SetPoint("BOTTOMLEFT", eb, "TOPLEFT", 0, 10)
			else
				frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
			end
		end
		frame:Show()
		SelectView(v)
	end

	function P.Close() frame:Hide() end
	function P.IsShown() return frame:IsShown() end
	function P.Toggle()
		if frame:IsShown() then P.Close() else P.Open() end
	end
	return P
end
