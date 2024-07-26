--!strict
local RunService = game:GetService("RunService")
local Core = script.Parent.Parent

local Util = {
	GlobalTimer = 0,
	Scale = 1 / 20,
}

local rayParams = RaycastParams.new()
rayParams.RespectCanCollide = true
rayParams.IgnoreWater = true

local SHORT_TO_RAD = (2 * math.pi) / 0x10000
local VECTOR3_XZ = Vector3.one - Vector3.yAxis

local TweenService = game:GetService("TweenService")
local fadeOut = TweenInfo.new(0.5)

local waterPlane = Instance.new("BoxHandleAdornment")
waterPlane.Size = Vector3.new(48, 0, 48)
waterPlane.Adornee = workspace.Terrain
waterPlane.Transparency = 0.5
waterPlane.Name = "WaterPlane"

local focalPlane = waterPlane:Clone()
focalPlane.Size = Vector3.new(4, 0, 4)
focalPlane.Color3 = Color3.new(1, 0, 1)
focalPlane.Name = "FocalPlane"
focalPlane.Transparency = 0.1
focalPlane.Parent = waterPlane

-- [!!] Photosensitivity warning for this debug util
-- causes flashing colors sometimes
local surfacePlane = Instance.new("Decal")
surfacePlane.Texture = "rbxassetid://11996254337"
surfacePlane.Name = "CollisionSurfacePlane"
surfacePlane.Transparency = 0.5
surfacePlane.ZIndex = 512
local surfacePlanes: { [string]: Decal } = {
	Wall = surfacePlane,
	Ceil = surfacePlane:Clone(),
	Floor = surfacePlane:Clone(),
}

-- ignore allat sorry
for planeName, color in
	{
		["Ceil"] = Color3.fromRGB(200, 0, 0),
		["Wall"] = Color3.fromRGB(128, 255, 0),
		["Floor"] = Color3.fromRGB(0, 64, 255),
	}
do
	surfacePlanes[planeName :: string].Color3 = color :: Color3
end

local CARDINAL = {
	-Vector3.xAxis,
	-Vector3.zAxis,
	Vector3.xAxis,
	Vector3.zAxis,
}

local CONSTRUCTORS = {
	Vector3 = Vector3.new,
	Vector3int16 = Vector3int16.new,
}

-- To assist with making proper BLJ-able staircases.
-- (or just plain ignoring some collision types)
-- Most staircases in 64 don't have wall-type collision and that's why you're able to BLJ on them.
-- (unless its collision is a slope that's not steep enough)
local function shouldIgnoreSurface(result: RaycastResult?, side: string): (RaycastResult?, boolean)
	if result and type(side) == "string" then
		result = if result.Instance:HasTag(`CollIgnore{side}`) then nil else result
		return result, (result == nil)
	end

	return result, false
end

local function normalIdFromRaycast(result: RaycastResult): Enum.NormalId
	local part = result.Instance :: BasePart
	local direction = result.Normal

	local maxDot, maxNormal = 0, nil
	local maxNormalId = Enum.NormalId.Front
	for _, normalId in Enum.NormalId:GetEnumItems() do
		local normal = part.CFrame:VectorToWorldSpace(Vector3.fromNormalId(normalId))
		local dot = normal:Dot(direction)
		if dot > 0 and dot > maxDot then
			maxDot = dot
			maxNormal = normal
			maxNormalId = normalId
		end
	end

	return maxNormalId
end

-- stylua: ignore
local function vectorModifier(getArgs: (Vector3 | Vector3int16, number) -> (number, number, number)):
	((vec: Vector3, value: number) -> Vector3) & 
	((vec: Vector3int16, value: number) -> Vector3int16)

	return function (vector, new)
		local constructor = CONSTRUCTORS[typeof(vector)]
		return constructor(getArgs(vector, new))
	end
end

Util.SetX = vectorModifier(function(vector, x)
	return x, vector.Y, vector.Z
end)

Util.SetY = vectorModifier(function(vector, y)
	return vector.X, y, vector.Z
end)

Util.SetZ = vectorModifier(function(vector, z)
	return vector.X, vector.Y, z
end)

function Util.ToRoblox(v: Vector3)
	return v * Util.Scale
end

function Util.ToSM64(v: Vector3)
	return v / Util.Scale
end

function Util.ToEulerAngles(v: Vector3int16): Vector3
	return Vector3.new(v.X, v.Y, v.Z) * SHORT_TO_RAD
end

function Util.ToRotation(v: Vector3int16): CFrame
	local angle = Util.ToEulerAngles(v)

	-- stylua: ignore
	local matrix = CFrame.fromAxisAngle(Vector3.yAxis, angle.Y)
	             * CFrame.fromAxisAngle(Vector3.xAxis, -angle.X)
	             * CFrame.fromAxisAngle(Vector3.zAxis, -angle.Z)

	return matrix
end

function Util.DebugWater(waterLevel: number)
	if script:GetAttribute("Debug") then
		local robloxLevel = (waterLevel * Util.Scale) + 0.01
		local focus = workspace.CurrentCamera.Focus

		local x = math.floor(focus.X / 4) * 4
		local z = math.floor(focus.Z / 4) * 4

		local cf = CFrame.new(x, robloxLevel, z)
		waterPlane.Parent = script

		focalPlane.CFrame = cf
		waterPlane.CFrame = cf
	else
		waterPlane.Parent = nil
	end
end

function Util.DebugCollisionFaces(wall: RaycastResult?, ceil: RaycastResult?, floor: RaycastResult?)
	local colliding = {
		Wall = wall,
		Ceil = ceil,
		Floor = floor,
	}

	for side, decal in surfacePlanes do
		if script:GetAttribute("Debug") then
			local hit: RaycastResult? = colliding[side]
			local part: BasePart? = hit and hit.Instance :: BasePart

			if
				(hit and part)
				and part ~= workspace.Terrain
				and (RunService:IsStudio() and true or part.Transparency < 1)
			then
				decal.Face = normalIdFromRaycast(hit)
				decal.Parent = part
				continue
			end
		end

		decal.Parent = nil
	end
end

function Util.Raycast(pos: Vector3, dir: Vector3, maybeParams: RaycastParams?, worldRoot: WorldRoot?): RaycastResult?
	local root = worldRoot or workspace
	local params = maybeParams or rayParams
	local result = root:Raycast(pos, dir, params)

	if script:GetAttribute("Debug") then
		local color = Color3.new(result and 0 or 1, result and 1 or 0, 0)

		local line = Instance.new("LineHandleAdornment")
		line.CFrame = CFrame.new(pos, pos + dir)
		line.Length = dir.Magnitude
		line.Thickness = 3
		line.Color3 = color
		line.Adornee = workspace.Terrain
		line.Parent = workspace.Terrain

		local tween = TweenService:Create(line, fadeOut, {
			Transparency = 1,
		})

		tween:Play()
		task.delay(fadeOut.Time, line.Destroy, line)
	end

	return result
end

-- stylua: ignore
function Util.RaycastSM64(pos: Vector3, dir: Vector3, maybeParams: RaycastParams?, worldRoot: WorldRoot?): RaycastResult?
	local result: RaycastResult? = Util.Raycast(pos * Util.Scale, dir * Util.Scale, maybeParams or rayParams, worldRoot)

	if result then
		-- Cast back to SM64 unit scale.
		result = {
			Normal = result.Normal,
			Material = result.Material,
			Instance = result.Instance,
			Distance = result.Distance / Util.Scale,
			Position = result.Position / Util.Scale,
		} :: any
	end

	return result
end

function Util.FindFloor(pos: Vector3): (number, RaycastResult?)
	local newPos = pos
	local height = -11000

	if Core:GetAttribute("TruncateBounds") then
		local trunc = Vector3int16.new(pos.X, pos.Y, pos.Z)

		if math.abs(trunc.X) >= 0x2000 then
			return height, nil
		end

		if math.abs(trunc.Z) >= 0x2000 then
			return height, nil
		end

		newPos = Vector3.new(trunc.X, trunc.Y, trunc.Z)
	end

	-- Odd solution for parts that have their floor ignored
	-- while being above a floor that you can stand on
	-- (exposed ceiling stuff)

	local result
	local unqueried: { [BasePart]: any } = {}

	for i = 1, 2 do
		result = Util.RaycastSM64(newPos + (Vector3.yAxis * 100), -Vector3.yAxis * 10000, rayParams)
		local _, ignored = shouldIgnoreSurface(result, "Floor")
		local hit: BasePart? = result and (result.Instance :: BasePart)

		if (ignored and result) and (hit and hit.CanQuery and hit.CanCollide) then
			unqueried[hit] = true
			hit.CanCollide = false
			hit.CanQuery = false
			result = nil

			continue
		end

		if result then
			height = Util.SignedShort(result.Position.Y)
			result.Position = Vector3.new(pos.X, height, pos.Z)
			break
		end
	end

	for part in unqueried do
		part.CanCollide = true
		part.CanQuery = true
	end
	unqueried = nil :: any

	return height, result
end

function Util.FindCeil(pos: Vector3, height: number?): (number, RaycastResult?)
	local truncateBounds = Core:GetAttribute("TruncateBounds")
	local newHeight = truncateBounds and 10000 or math.huge

	if truncateBounds then
		local trunc = Vector3int16.new(pos.X, pos.Y, pos.Z)

		if math.abs(trunc.X) >= 0x2000 then
			return newHeight, nil
		end

		if math.abs(trunc.Z) >= 0x2000 then
			return newHeight, nil
		end

		pos = Vector3.new(trunc.X, trunc.Y, trunc.Z)
	end

	local head = Vector3.new(pos.X, (height or pos.Y) + 80, pos.Z)
	local result = Util.RaycastSM64(head, Vector3.yAxis * 10000, rayParams)
	result = shouldIgnoreSurface(result, "Ceil")

	if result then
		newHeight = result.Position.Y
	end

	return newHeight, result
end

function Util.FindWallCollisions(pos: Vector3, offset: number, radius: number): (Vector3, RaycastResult?)
	local origin = pos + Vector3.new(0, offset, 0)
	local lastWall: RaycastResult?
	local disp = Vector3.zero

	for i, dir in CARDINAL do
		local contact = Util.RaycastSM64(origin, dir * radius)
		contact = shouldIgnoreSurface(contact, "Wall")

		if contact then
			local normal = contact.Normal

			if math.abs(normal.Y) < 0.01 then
				local surface = contact.Position
				local move = (surface - pos) * VECTOR3_XZ
				local dist = move.Magnitude

				if dist < radius then
					disp += (contact.Normal * VECTOR3_XZ) * (radius - dist)
					lastWall = contact
				end
			end
		end
	end

	return pos + disp, lastWall
end

function Util.SignedShort(x: number)
	return -0x8000 + math.floor((x + 0x8000) % 0x10000)
end

function Util.SignedInt(x: number)
	return -0x80000000 + math.floor(x + 0x80000000) % 0x100000000
end

function Util.ApproachFloat(current: number, target: number, inc: number, dec: number?): number
	if dec == nil then
		dec = inc
	end

	assert(dec)

	if current < target then
		current = math.min(target, current + inc)
	else
		current = math.max(target, current - dec)
	end

	return current
end

function Util.ApproachInt(current: number, target: number, inc: number, dec: number?): number
	if dec == nil then
		dec = inc
	end

	assert(dec)

	if current < target then
		current = Util.SignedInt(current + inc)
		current = math.min(target, current)
	else
		current = Util.SignedInt(current - dec)
		current = math.max(target, current)
	end

	return Util.SignedInt(current)
end

function Util.Sins(short: number): number
	local value = Util.SignedShort(short)
	value = math.floor(value / 16) * 16

	return math.sin(value * SHORT_TO_RAD)
end

function Util.Coss(short: number): number
	local value = Util.SignedShort(short)
	value = math.floor(value / 16) * 16

	return math.cos(short * SHORT_TO_RAD)
end

local function atan2_lookup(y: number, x: number)
	local value = math.atan2(y, x) / SHORT_TO_RAD
	value = math.floor(value / 16) * 16
	return Util.SignedShort(value)
end

function Util.Atan2s(y: number, x: number): number
	local ret: number

	if x >= 0 then
		if y >= 0 then
			if y >= x then
				ret = atan2_lookup(x, y)
			else
				ret = 0x4000 - atan2_lookup(y, x)
			end
		else
			y = -y

			if y < x then
				ret = 0x4000 + atan2_lookup(y, x)
			else
				ret = 0x8000 - atan2_lookup(x, y)
			end
		end
	else
		x = -x

		if y < 0 then
			y = -y

			if y >= x then
				ret = 0x8000 + atan2_lookup(x, y)
			else
				ret = 0xC000 - atan2_lookup(y, x)
			end
		else
			if y < x then
				ret = 0xC000 + atan2_lookup(y, x)
			else
				ret = -atan2_lookup(x, y)
			end
		end
	end

	return Util.SignedShort(ret)
end

return Util
