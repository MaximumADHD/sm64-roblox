--!strict

local System = require(script.Parent)
local Animations = System.Animations
local Sounds = System.Sounds
local Enums = System.Enums
local Util = System.Util

local Action = Enums.Action
local ActionFlags = Enums.ActionFlags

local AirStep = Enums.AirStep
local MarioEyes = Enums.MarioEyes
local InputFlags = Enums.InputFlags
local MarioFlags = Enums.MarioFlags
local ParticleFlags = Enums.ParticleFlags

type Mario = System.Mario

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local DEF_ACTION: (number, (Mario) -> boolean) -> () = System.RegisterAction

local function CommonDeathHandler(m: Mario, animation, frameToDeathWarp)
	local animFrame = m:SetAnimation(animation)

	m.BodyState.EyeState = MarioEyes.DEAD
	m:StopAndSetHeightToFloor()
	return animFrame
end

local function StuckInGroundHandler(m: Mario, animation, unstuckFrame: number, target2, target3, endAction)
	local animFrame = m:SetAnimation(animation)

	if m.Input:Has(InputFlags.A_PRESSED) then
		m.ActionTimer += 1
		if m.ActionTimer >= 5 and animFrame < unstuckFrame - 1 then
			animFrame = unstuckFrame - 1
			m:SetAnimToFrame(animFrame)
		end
	end

	m:StopAndSetHeightToFloor()

	if animFrame == -1 then
		m:PlaySoundAndSpawnParticles(Sounds.ACTION_TERRAIN_STUCK_IN_GROUND, 1)
	elseif animFrame == unstuckFrame then
		m:PlaySoundAndSpawnParticles(Sounds.ACTION_UNSTUCK_FROM_GROUND, 1)
	elseif animFrame == target2 and animFrame == target3 then
		m:PlayLandingSound(Sounds.ACTION_TERRAIN_LANDING)
	end

	if m:IsAnimAtEnd() then
		m:SetAction(endAction, 0)
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Death states
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

DEF_ACTION(Action.STANDING_DEATH, function(m: Mario)
	if m.Input:Has(InputFlags.IN_POISON_GAS) then
		return m:SetAction(Action.SUFFOCATION, 0)
	end

	m:PlaySoundIfNoFlag(Sounds.MARIO_DYING, MarioFlags.ACTION_SOUND_PLAYED)
	CommonDeathHandler(m, Animations.DYING_FALL_OVER, 80)
	if m.AnimFrame == 77 then
		m:PlayLandingSound(Sounds.ACTION_TERRAIN_BODY_HIT_GROUND)
	end

	return false
end)

DEF_ACTION(Action.ELECTROCUTION, function(m: Mario)
	m:PlaySoundIfNoFlag(Sounds.MARIO_DYING, MarioFlags.ACTION_SOUND_PLAYED)
	CommonDeathHandler(m, Animations.ELECTROCUTION, 43)
	return false
end)

DEF_ACTION(Action.DEATH_ON_BACK, function(m: Mario)
	m:PlaySoundIfNoFlag(Sounds.MARIO_DYING, MarioFlags.ACTION_SOUND_PLAYED)
	if CommonDeathHandler(m, Animations.DYING_ON_BACK, 54) == 40 then
		m:PlayLandingSound(Sounds.ACTION_TERRAIN_BODY_HIT_GROUND)
	end
	return false
end)

DEF_ACTION(Action.DEATH_ON_STOMACH, function(m: Mario)
	m:PlaySoundIfNoFlag(Sounds.MARIO_DYING, MarioFlags.ACTION_SOUND_PLAYED)
	if CommonDeathHandler(m, Animations.DYING_ON_STOMACH, 54) == 40 then
		m:PlayLandingSound(Sounds.ACTION_TERRAIN_BODY_HIT_GROUND)
	end
	return false
end)

DEF_ACTION(Action.QUICKSAND_DEATH, function(m: Mario)
	if m.ActionState == 0 then
		m:SetAnimation(Animations.DYING_IN_QUICKSAND)
		m:SetAnimToFrame(60)
		m.ActionState = 1
	end

	if m.ActionState == 1 then
		if m.QuicksandDepth >= 100 then
			m:PlaySoundIfNoFlag(Sounds.MARIO_WAAAOOOW, MarioFlags.ACTION_SOUND_PLAYED)
		end
		m.QuicksandDepth += 5.0
		if m.QuicksandDepth >= 180 then
			-- LevelTriggerWarp
			m.ActionState = 2
		end
	end

	m:StationaryGroundStep()
	m:PlaySound(Sounds.MOVING_QUICKSAND_DEATH)
	return false
end)

DEF_ACTION(Action.SUFFOCATION, function(m: Mario)
	m:PlaySoundIfNoFlag(Sounds.MARIO_DYING, MarioFlags.ACTION_SOUND_PLAYED)
	CommonDeathHandler(m, Animations.SUFFOCATING, 86)
	return false
end)

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Spawning states
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

DEF_ACTION(Action.SPAWN_SPIN_AIRBORNE, function(m: Mario)
	m:SetForwardVel(m.ForwardVel)

	if m:PerformAirStep() == AirStep.LANDED then
		m:PlayLandingSound(Sounds.ACTION_TERRAIN_LANDING)
		m:SetAction(Action.SPAWN_SPIN_LANDING)
	end

	if m.ActionState == 0 and m.Position.Y - m.FloorHeight > 300 then
		if m:SetAnimation(Animations.FORWARD_SPINNING) == 0 then
			m:PlaySound(Sounds.ACTION_SPIN)
		end
	else
		m.ActionState = 1
		m:SetAnimation(Animations.GENERAL_FALL)
	end

	return false
end)

DEF_ACTION(Action.SPAWN_SPIN_LANDING, function(m: Mario)
	m:StopAndSetHeightToFloor()
	m:SetAnimation(Animations.GENERAL_LAND)

	if m:IsAnimAtEnd() then
		m:SetAction(Action.IDLE)
	end

	return false
end)

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Stuck in ground states
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

DEF_ACTION(Action.HEAD_STUCK_IN_GROUND, function(m: Mario)
	StuckInGroundHandler(m, Animations.HEAD_STUCK_IN_GROUND, 96, 105, 135, Action.IDLE)
	return false
end)

DEF_ACTION(Action.BUTT_STUCK_IN_GROUND, function(m: Mario)
	StuckInGroundHandler(m, Animations.BOTTOM_STUCK_IN_GROUND, 127, 136, -2, Action.GROUND_POUND_LAND)
	return false
end)

DEF_ACTION(Action.FEET_STUCK_IN_GROUND, function(m: Mario)
	StuckInGroundHandler(m, Animations.LEGS_STUCK_IN_GROUND, 116, 129, -2, Action.IDLE)
	return false
end)

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
