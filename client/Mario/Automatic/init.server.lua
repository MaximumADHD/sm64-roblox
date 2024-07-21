--!strict

local System = require(script.Parent)
local Animations = System.Animations
local Sounds = System.Sounds
local Enums = System.Enums
local Util = System.Util

local Action = Enums.Action
local ActionFlags = Enums.ActionFlags
local ActionGroup = Enums.ActionGroups

local AirStep = Enums.AirStep
local MarioEyes = Enums.MarioEyes
local InputFlags = Enums.InputFlags
local MarioFlags = Enums.MarioFlags
local ParticleFlags = Enums.ParticleFlags
local SurfaceClass = Enums.SurfaceClass

type Mario = System.Mario

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Should this be on the enums?
local HANG_NONE = 0
local HANG_HIT_CEIL_OR_OOB = 1
local HANG_LEFT_CEIL = 2

local function letGoOfLedge(m: Mario)
	local floorHeight
	m.Velocity *= Vector3.new(1, 0, 1)
	m.ForwardVel = -8

	local x = 60 * Util.Sins(m.FaceAngle.Y)
	local z = 60 * Util.Coss(m.FaceAngle.Y)

	m.Position -= Vector3.new(x, 0, z)
	floorHeight = Util.FindFloor(m.Position)

	if floorHeight < m.Position.Y - 100 then
		m.Position -= (Vector3.yAxis * 100)
	else
		m.Position = Util.SetY(m.Position, floorHeight)
	end

	return m:SetAction(Action.SOFT_BONK)
end

local function climbUpLedge(m: Mario)
	local x = 14 * Util.Sins(m.FaceAngle.Y)
	local z = 14 * Util.Coss(m.FaceAngle.Y)

	m:SetAnimation(Animations.IDLE_HEAD_LEFT)
	m.Position += Vector3.new(x, 0, z)
end

local function updateLedgeClimb(m: Mario, anim: Animation, endAction: number)
	m:StopAndSetHeightToFloor()
	m:SetAnimation(anim)

	if m:IsAnimAtEnd() then
		m:SetAction(endAction)

		if endAction == Action.IDLE then
			climbUpLedge(m)
		end
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Actions
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local DEF_ACTION: (number, (Mario) -> boolean) -> () = System.RegisterAction

DEF_ACTION(Action.LEDGE_GRAB, function(m: Mario)
	local intendedDYaw = m.IntendedYaw - m.FaceAngle.Y
	local hasSpaceForMario = m.CeilHeight - m.FloorHeight >= 160

	if m.ActionTimer < 10 then
		m.ActionTimer += 1
	end

	if m.Floor and m.Floor.Normal.Y < 0.9063078 then
		return letGoOfLedge(m)
	end

	if m.Input:Has(InputFlags.Z_PRESSED, InputFlags.OFF_FLOOR) then
		return letGoOfLedge(m)
	end

	if m.Input:Has(InputFlags.A_PRESSED) and hasSpaceForMario then
		return m:SetAction(Action.LEDGE_CLIMB_FAST)
	end

	if m.Input:Has(InputFlags.STOMPED) then
		return letGoOfLedge(m)
	end

	if m.ActionTimer == 10 and m.Input:Has(InputFlags.NONZERO_ANALOG) then
		if math.abs(intendedDYaw) <= 0x4000 then
			if hasSpaceForMario then
				return m:SetAction(Action.LEDGE_CLIMB_SLOW)
			end
		else
			return letGoOfLedge(m)
		end
	end

	local heightAboveFloor = m.Position.Y - m:FindFloorHeightRelativePolar(-0x8000, 30)

	if hasSpaceForMario and heightAboveFloor < 100 then
		return m:SetAction(Action.LEDGE_CLIMB_FAST)
	end

	if m.ActionArg == 0 then
		m:PlaySoundIfNoFlag(Sounds.MARIO_WHOA, MarioFlags.MARIO_SOUND_PLAYED)
	end

	m:StopAndSetHeightToFloor()
	m:SetAnimation(Animations.IDLE_ON_LEDGE)

	return false
end)

DEF_ACTION(Action.LEDGE_CLIMB_SLOW, function(m: Mario)
	if m.Input:Has(InputFlags.OFF_FLOOR) then
		return letGoOfLedge(m)
	end

	if m.ActionTimer >= 28 then
		if
			m.Input:Has(InputFlags.NONZERO_ANALOG, InputFlags.A_PRESSED, InputFlags.OFF_FLOOR, InputFlags.ABOVE_SLIDE)
		then
			climbUpLedge(m)
			return m:CheckCommonActionExits()
		end
	end

	if m.ActionTimer == 10 then
		m:PlaySoundIfNoFlag(Sounds.MARIO_EEUH, MarioFlags.MARIO_SOUND_PLAYED)
	end

	updateLedgeClimb(m, Animations.SLOW_LEDGE_GRAB, Action.IDLE)
	return false
end)

DEF_ACTION(Action.LEDGE_CLIMB_DOWN, function(m: Mario)
	if m.Input:Has(InputFlags.OFF_FLOOR) then
		return letGoOfLedge(m)
	end

	m:PlaySoundIfNoFlag(Sounds.MARIO_WHOA, MarioFlags.MARIO_SOUND_PLAYED)
	updateLedgeClimb(m, Animations.CLIMB_DOWN_LEDGE, Action.LEDGE_GRAB)

	m.ActionArg = 1
	return false
end)

DEF_ACTION(Action.LEDGE_CLIMB_FAST, function(m: Mario)
	if m.Input:Has(InputFlags.OFF_FLOOR) then
		return letGoOfLedge(m)
	end

	m:PlaySoundIfNoFlag(Sounds.MARIO_UH2, MarioFlags.MARIO_SOUND_PLAYED)
	updateLedgeClimb(m, Animations.FAST_LEDGE_GRAB, Action.IDLE)

	if m.AnimFrame == 8 then
		m:PlayLandingSound(Sounds.ACTION_TERRAIN_LANDING)
	end

	return false
end)

local function PerformHangingStep(m: Mario, nextPos: Vector3)
	local ceil, floor
	local ceilHeight, floorHeight
	local ceilOffset
	local nextPos, wall = Util.FindWallCollisions(nextPos, 50, 50)

	m.Wall = wall
	floorHeight, floor = Util.FindFloor(nextPos)
	ceilHeight, ceil = Util.FindCeil(nextPos, floorHeight)

	if floor == nil then
		return HANG_HIT_CEIL_OR_OOB
	end

	if ceil == nil then
		return HANG_LEFT_CEIL
	end

	if ceilHeight - floorHeight <= 160 then
		return HANG_HIT_CEIL_OR_OOB
	end

	if m:GetCeilType() ~= SurfaceClass.HANGABLE then
		return HANG_LEFT_CEIL
	end

	ceilOffset = ceilHeight - (nextPos.Y + 160.0)
	if ceilOffset < -30.0 then
		return HANG_HIT_CEIL_OR_OOB
	elseif ceilOffset > 30.0 then
		return HANG_LEFT_CEIL
	end

	nextPos = Util.SetY(nextPos, m.CeilHeight - 160)
	m.Position = nextPos

	m.Floor = floor
	m.FloorHeight = floorHeight
	m.Ceil = ceil
	m.CeilHeight = ceilHeight

	return HANG_NONE
end

local function UpdateHangMoving(m: Mario)
	local stepResult
	local nextPos = Vector3.zero
	local maxSpeed = 4.0

	m.ForwardVel += 1.0
	if m.ForwardVel > maxSpeed then
		m.ForwardVel = maxSpeed
	end

	local currY = Util.SignedShort(m.IntendedYaw - m.FaceAngle.Y)

	m.FaceAngle = Util.SetY(m.FaceAngle, m.IntendedYaw - Util.ApproachFloat(currY, 0, 0x800, 0x800))

	m.SlideYaw = m.FaceAngle.Y
	m:SetForwardVel(m.ForwardVel)

	m.Velocity = Vector3.new(m.SlideVelX, 0.0, m.SlideVelZ)

	assert(m.Ceil)
	nextPos = Util.SetX(nextPos, m.Position.X - m.Ceil.Normal.Y * m.Velocity.X)
	nextPos = Util.SetZ(nextPos, m.Position.Z - m.Ceil.Normal.Y * m.Velocity.Z)
	nextPos = Util.SetY(nextPos, m.Position.Y)

	stepResult = PerformHangingStep(m, nextPos)

	m.GfxPos = Vector3.zero
	m.GfxAngle = Vector3int16.new(0, m.FaceAngle.Y, 0)
	return stepResult
end

local function UpdateHangStationary(m: Mario)
	m:SetForwardVel(0)

	m.Position = Util.SetY(m.Position, m.CeilHeight - 160.0)
	m.GfxAngle = Vector3int16.new(0, m.FaceAngle.Y, 0)
	m.Velocity = Vector3.zero
	m.GfxPos = Vector3.zero
end

DEF_ACTION(Action.START_HANGING, function(m: Mario)
	m.ActionTimer += 1

	if m.Input:Has(InputFlags.NONZERO_ANALOG) and m.ActionTimer >= 31 then
		return m:SetAction(Action.HANGING, 0)
	end

	if not m.Input:Has(InputFlags.A_DOWN) then
		return m:SetAction(Action.FREEFALL, 0)
	end

	if m.Input:Has(InputFlags.Z_PRESSED) then
		return m:SetAction(Action.GROUND_POUND, 0)
	end

	if m:GetCeilType() ~= SurfaceClass.HANGABLE then
		return m:SetAction(Action.FREEFALL, 0)
	end

	m:SetAnimation(Animations.HANG_ON_CEILING)
	m:PlaySoundIfNoFlag(Sounds.ACTION_HANGING_STEP, MarioFlags.ACTION_SOUND_PLAYED)
	UpdateHangStationary(m)

	if m:IsAnimAtEnd() then
		m:SetAction(Action.HANGING, 0)
	end

	return false
end)

DEF_ACTION(Action.HANGING, function(m: Mario)
	if m.Input:Has(InputFlags.NONZERO_ANALOG) then
		return m:SetAction(Action.HANG_MOVING, m.ActionArg)
	end

	if not m.Input:Has(InputFlags.A_DOWN) then
		return m:SetAction(Action.FREEFALL, 0)
	end

	if m.Input:Has(InputFlags.Z_PRESSED) then
		return m:SetAction(Action.GROUND_POUND, 0)
	end

	if m:GetCeilType() ~= SurfaceClass.HANGABLE then
		return m:SetAction(Action.FREEFALL, 0)
	end

	if bit32.band(m.ActionArg, 1) > 0 then
		m:SetAnimation(Animations.HANDSTAND_LEFT)
	else
		m:SetAnimation(Animations.HANDSTAND_RIGHT)
	end

	UpdateHangStationary(m)

	return false
end)

DEF_ACTION(Action.HANG_MOVING, function(m: Mario)
	if not m.Input:Has(InputFlags.A_DOWN) then
		return m:SetAction(Action.FREEFALL, 0)
	end

	if m.Input:Has(InputFlags.Z_PRESSED) then
		return m:SetAction(Action.GROUND_POUND, 0)
	end

	if m:GetCeilType() ~= SurfaceClass.HANGABLE then
		return m:SetAction(Action.FREEFALL, 0)
	end

	if bit32.band(m.ActionArg, 1) > 0 then
		m:SetAnimation(Animations.MOVE_ON_WIRE_NET_RIGHT)
	else
		m:SetAnimation(Animations.MOVE_ON_WIRE_NET_LEFT)
	end

	if m.AnimFrame == 12 then
		m:PlaySound(Sounds.ACTION_HANGING_STEP)
	end

	if m:IsAnimPastEnd() then
		m.ActionArg = bit32.bxor(m.ActionArg, 1)
		if m.Input:Has(InputFlags.NO_MOVEMENT) then
			-- You'll keep moving if TAS input is enabled
			return m:SetAction(Action.HANGING, m.ActionArg)
		end
	end

	if UpdateHangMoving(m) == 2 then
		m:SetAction(Action.FREEFALL, 0)
	end

	return false
end)
