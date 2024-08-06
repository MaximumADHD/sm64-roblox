--!strict

local Flags = {}
Flags.__index = Flags
Flags.__type = "BitmaskFlag"

export type Flags = { Value: number }
export type Class = typeof(setmetatable({} :: Flags, Flags))

function Flags.new(...: number): Class
	local flags = { Value = bit32.bor(...) }
	return setmetatable(flags, Flags)
end

function Flags.__call(self: Class): number
	return self.Value
end

function Flags.Get(self: Class): number
	return self.Value
end

function Flags.Set(self: Class, ...: number)
	self.Value = bit32.bor(...)
end

function Flags.Copy(self: Class, flags: Class)
	self.Value = flags.Value
end

function Flags.Add(self: Class, ...: number)
	self.Value = bit32.bor(self.Value, ...)
end

function Flags.Has(self: Class, ...: number): boolean
	local mask = bit32.bor(...)
	return bit32.btest(self.Value, mask)
end

function Flags.Remove(self: Class, ...: number)
	local mask = bit32.bor(...)
	local invert = bit32.bnot(mask)
	self.Value = bit32.band(self.Value, invert)
end

function Flags.Band(self: Class, ...: number)
	self.Value = bit32.band(self.Value, ...)
end

function Flags.Clear(self: Class)
	self.Value = 0
end

return Flags
