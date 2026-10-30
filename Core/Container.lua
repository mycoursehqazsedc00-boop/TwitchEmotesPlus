-- TwitchEmotes+ : Core/Container.lua
-- A tiny dependency-injection container. Every collaborator (upstream
-- adapters, data sources, UI) is a named service built by a factory that
-- receives the container, so nothing reaches for upstream globals directly
-- and any service can be swapped with Container:Override().

TwitchEmotesPlus = TwitchEmotesPlus or {}
local TEP = TwitchEmotesPlus
TEP.version = "1.0.0"

function TEP.Print(msg)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff7fd0TwitchEmotes+|r " .. tostring(msg))
	end
end

local Container = { factories = {}, cache = {}, resolving = {}, overridden = {} }
TEP.Container = Container

-- Register a service. `factory` is a function(container) -> service, or a plain value.
function Container:Register(name, factory)
	self.factories[name] = factory
	self.cache[name] = nil
end

-- Replace a service (same mechanics as Register, but remembered so /tep status
-- can tell you something was swapped). Call before the first Resolve of it.
function Container:Override(name, factory)
	self:Register(name, factory)
	self.overridden[name] = true
end

function Container:Has(name)
	return self.factories[name] ~= nil
end

function Container:Invalidate(name)
	self.cache[name] = nil
end

function Container:Resolve(name)
	local cached = self.cache[name]
	if cached ~= nil then return cached end
	local factory = self.factories[name]
	if factory == nil then
		error("TwitchEmotes+: no service registered as '" .. name .. "'", 2)
	end
	if self.resolving[name] then
		error("TwitchEmotes+: circular dependency while resolving '" .. name .. "'", 2)
	end
	self.resolving[name] = true
	local ok, instance = pcall(function()
		if type(factory) == "function" then return factory(self) end
		return factory
	end)
	self.resolving[name] = nil
	if not ok then
		error("TwitchEmotes+: service '" .. name .. "' failed: " .. tostring(instance), 0)
	end
	self.cache[name] = instance
	return instance
end
