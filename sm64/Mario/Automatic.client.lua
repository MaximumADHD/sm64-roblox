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

type Mario = System.Mario

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

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
