-- TwitchEmotes+ : Adapters/Upstream.lua
-- The ONLY place that knows about TwitchEmotes internals. Everything is read
-- late (at call time, never cached at load) and defensively, so replacing the
-- TwitchEmotes folder with a newer release cannot break this add-on: if a
-- global changes shape the adapter degrades, the rest of the add-on never sees it.
--
-- Upstream surface used (all plain globals, read-only):
--   emoticons                        typed code -> defaultpack key
--   defaultpack                      key -> "path.tga:w:h[:xo:yo:imgW:imgH:l:r:t:b]"
--   TwitchEmotes_animation_metadata  sprite-sheet path -> frame layout
--   ChatFrameEditBox                 Blizzard chat edit box
-- Nothing in upstream is hooked, wrapped or overwritten.

local TEP = TwitchEmotesPlus
local C = TEP.Container

C:Register("upstream", function()
	local up = {}
	function up.emoticons()  return _G["emoticons"] end
	function up.defaultpack() return _G["defaultpack"] end
	function up.animation()  return _G["TwitchEmotes_animation_metadata"] end
	function up.editBox()    return _G["ChatFrameEditBox"] end
	function up.ready()
		return type(up.emoticons()) == "table" and type(up.defaultpack()) == "table"
	end
	return up
end)

-- key -> { path, l, r, t, b, anim }   (first-frame crop + optional animation data)
C:Register("textureResolver", function(c)
	local up = c:Resolve("upstream")
	local cache = {}

	local function parse(key)
		local pack = up.defaultpack()
		local entry = pack and pack[key]
		if type(entry) ~= "string" then return nil end
		local path = string.match(entry, "^([^:]+)")
		if not path then return nil end
		local res = { path = path, l = 0, r = 1, t = 0, b = 1 }
		-- extended form: path:w:h:xoff:yoff:imgW:imgH:left:right:top:bottom
		local nums = {}
		for n in string.gmatch(entry, ":(%d+)") do
			nums[#nums + 1] = tonumber(n)
		end
		if #nums >= 10 and nums[5] > 0 and nums[6] > 0 then
			res.l = nums[7] / nums[5]
			res.r = nums[8] / nums[5]
			res.t = nums[9] / nums[6]
			res.b = nums[10] / nums[6]
		end
		local meta = up.animation()
		res.anim = meta and meta[path] or nil
		return res
	end

	local R = {}
	function R.Resolve(key)
		local r = cache[key]
		if r == nil then
			r = parse(key) or false
			cache[key] = r
		end
		return r or nil
	end
	function R.Flush() cache = {} end
	return R
end)

-- Emote catalog grouped by the sprite folder each emote lives in, so packs
-- added by future upstream releases show up without any change here.
-- Get() -> { available, packs = {{name, items}}, all, byCode, total }
-- item  -> { code, key, lc }
C:Register("emoteCatalog", function(c)
	local up = c:Resolve("upstream")
	local catalog, data = {}, nil

	local function packName(entry)
		local folder = string.match(entry, "([^\\]+)\\[^\\]+$")
		if not folder or folder == "Emotes" then return "Misc" end
		return (string.gsub(folder, "_", " "))
	end

	local function build()
		local emo, dp = up.emoticons(), up.defaultpack()
		local out = { available = false, packs = {}, all = {}, byCode = {}, total = 0 }
		if type(emo) ~= "table" or type(dp) ~= "table" then return out end

		local byPack = {}
		for code, key in pairs(emo) do
			local entry = dp[key]
			if type(entry) == "string" then
				local item = { code = code, key = key, lc = string.lower(code) }
				local name = packName(entry)
				local pack = byPack[name]
				if not pack then
					pack = { name = name, items = {} }
					byPack[name] = pack
					out.packs[#out.packs + 1] = pack
				end
				pack.items[#pack.items + 1] = item
				out.all[#out.all + 1] = item
				out.byCode[code] = item
			end
		end

		local function byLc(a, b) return a.lc < b.lc end
		table.sort(out.all, byLc)
		for _, pack in ipairs(out.packs) do table.sort(pack.items, byLc) end
		table.sort(out.packs, function(a, b) return string.lower(a.name) < string.lower(b.name) end)
		out.total = #out.all
		out.available = out.total > 0
		return out
	end

	function catalog.Get()
		if not data then data = build() end
		return data
	end
	function catalog.Invalidate() data = nil end
	return catalog
end)

-- Puts text into the chat edit box. Opens the box when it is closed (focus
-- changes can close Blizzard's edit box), restoring what was typed before.
C:Register("inserter", function(c)
	local up = c:Resolve("upstream")
	local I = {}
	function I.Snapshot()
		local eb = up.editBox()
		if eb and eb:IsVisible() then return eb:GetText() end
		return nil
	end
	function I.Insert(text, stash)
		local eb = up.editBox()
		if eb and eb:IsVisible() then
			eb:Insert(text)
			return true
		end
		local open = _G["ChatFrame_OpenChat"]
		if open then
			open((stash or "") .. text)
			return true
		end
		return false
	end
	return I
end)

C:Register("clipboard", function()
	local K = {}
	function K.Available() return type(_G["CopyToClipboard"]) == "function" end
	function K.Copy(text)
		local fn = _G["CopyToClipboard"]
		if fn then return fn(text) end
	end
	return K
end)
