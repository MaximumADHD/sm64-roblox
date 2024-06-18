--!strict

local System = require(script.Parent)
local Animations = System.Animations
local Sounds = System.Sounds
local Enums = System.Enums
local Util = System.Util

local Action = Enums.Action
local MarioEyes = Enums.MarioEyes
local InputFlags = Enums.InputFlags
local MarioFlags = Enums.MarioFlags

type Mario = System.Mario

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local DEF_ACTION: (number, (Mario) -> boolean) -> () = System.RegisterAction

local function checkCommonIdleCancels(m: Mario)
	local floor = m.Floor

	if floor and floor.Normal.Y < 0.29237169 then
		return m:PushOffSteepFloor(Action.FREEFALL, 0)
	end

	if m.Input:Has(InputFlags.STOMPED) then
		return m:SetAction(Action.SHOCKWAVE_BOUNCE)
	end

	if m.Input:Has(InputFlags.A_PRESSED) then
		return m:SetJumpingAction(Action.JUMP, 0)
	end

	if m.Input:Has(InputFlags.OFF_FLOOR) then
		return m:SetAction(Action.FREEFALL)
	end

	if m.Input:Has(InputFlags.ABOVE_SLIDE) then
		return m:SetAction(Action.BEGIN_SLIDING)
	end

	if m.Input:Has(InputFlags.NONZERO_ANALOG) then
		m.FaceAngle = Util.SetY(m.FaceAngle, m.IntendedYaw)
		return m:SetAction(Action.WALKING)
	end

	if m.Input:Has(InputFlags.B_PRESSED) then
		return m:SetAction(Action.PUNCHING)
	end

	if m.Input:Has(InputFlags.Z_DOWN) then
		return m:SetAction(Action.START_CROUCHING)
	end

	return false
end

local function playAnimSound(m: Mario, actionState: number, animFrame: number, sound: Sound)
	if m.ActionState == actionState and m.AnimFrame == animFrame then
		m:PlaySound(sound)
	end
end

local function stoppingStep(m: Mario, anim: Animation, action: number)
	m:StationaryGroundStep()
	m:SetAnimation(anim)

	if m:IsAnimPastEnd() then
		m:SetAction(action)
	end
end

local function landingStep(m: Mario, anim: Animation, action: number)
	stoppingStep(m, anim, action)
	return false
end

local function checkCommonLandingCancels(m: Mario, action: number)
	if m.Input:Has(InputFlags.STOMPED) then
		return m:SetAction(Action.SHOCKWAVE_BOUNCE)
	end

	if m.Input:Has(InputFlags.A_PRESSED) then
		if action == 0 then
			m:SetJumpFromLanding()
		else
			m:SetJumpingAction(action, 0)
		end
	end

	if m.Input:Has(InputFlags.NONZERO_ANALOG, InputFlags.A_PRESSED, InputFlags.OFF_FLOOR, InputFlags.ABOVE_SLIDE) then
		return m:CheckCommonActionExits()
	end

	if m.Input:Has(InputFlags.B_PRESSED) then
		return m:SetAction(Action.PUNCHING)
	end

	return false
end

local function animatedStationaryGroundStep(m: Mario, anim: Animation, endAction: number)
	m:StationaryGroundStep()
	m:SetAnimation(anim)

	if m:IsAnimAtEnd() then
		m:SetAction(endAction)
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Actions
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

DEF_ACTION(Action.IDLE, function(m: Mario)
	if m.QuicksandDepth > 30.0 then
		return m:SetAction(Action.IN_QUICKSAND, 0)
	end

	if not bit32.btest(m.ActionArg, 1) and m.Health < 0x300 then
		return m:SetAction(Action.PANTING)
	end

	if checkCommonIdleCancels(m) then
		return true
	end

	if m.ActionState == 3 then
		return m:SetAction(Action.START_SLEEPING)
	end

	if bit32.btest(m.ActionArg, 1) then
		m:SetAnimation(Animations.STAND_AGAINST_WALL)
	else
		if m.ActionState == 0 then
			m:SetAnimation(Animations.IDLE_HEAD_LEFT)
		elseif m.ActionState == 1 then
			m:SetAnimation(Animations.IDLE_HEAD_RIGHT)
		elseif m.ActionState == 2 then
			m:SetAnimation(Animations.IDLE_HEAD_CENTER)
		end

		if m:IsAnimAtEnd() then
			m.ActionState += 1

			if m.ActionState == 3 then
				local deltaYOfFloorBehindMario = m.Position.Y - m:FindFloorHeightRelativePolar(-0x8000, 60)

				if 24 < math.abs(deltaYOfFloorBehindMario) then
					m.ActionState = 0
				else
					m.ActionTimer += 1

					if m.ActionTimer < 10 then
						m.ActionState = 0
					end
				end
			end
		end
	end

	m:StationaryGroundStep()
	return false
end)

DEF_ACTION(Action.START_SLEEPING, function(m: Mario)
	local animFrame

	if checkCommonIdleCancels(m) then
		return true
	end

	if m.QuicksandDepth > 30.0 then
		return m:SetAction(Action.IN_QUICKSAND, 0)
	end

	if m.ActionState == 4 then
		m:SetAction(Action.SLEEPING)
	end

	if m.ActionState == 0 then
		animFrame = m:SetAnimation(Animations.START_SLEEP_IDLE)
	elseif m.ActionState == 1 then
		animFrame = m:SetAnimation(Animations.START_SLEEP_SCRATCH)
	elseif m.ActionState == 2 then
		animFrame = m:SetAnimation(Animations.START_SLEEP_YAWN)
		m.BodyState.EyeState = MarioEyes.HALF_CLOSED
	elseif m.ActionState == 3 then
		animFrame = m:SetAnimation(Animations.START_SLEEP_SITTING)
		m.BodyState.EyeState = MarioEyes.HALF_CLOSED
	end

	playAnimSound(m, 1, 41, Sounds.ACTION_PAT_BACK)
	playAnimSound(m, 1, 49, Sounds.ACTION_PAT_BACK)

	if m:IsAnimAtEnd() then
		m.ActionState += 1
	end

	if m.ActionState == 2 and animFrame == -1 then
		m:PlaySound(Sounds.MARIO_YAWNING)
	end

	if m.ActionState == 1 and animFrame == -1 then
		m:PlaySound(Sounds.MARIO_IMA_TIRED)
	end

	m:StationaryGroundStep()
	return false
end)

DEF_ACTION(Action.SLEEPING, function(m: Mario)
	local animFrame

	if
		m.Input:Has(
			InputFlags.NONZERO_ANALOG,
			InputFlags.A_PRESSED,
			InputFlags.OFF_FLOOR,
			InputFlags.ABOVE_SLIDE,
			InputFlags.FIRST_PERSON,
			InputFlags.STOMPED,
			InputFlags.B_PRESSED,
			InputFlags.Z_PRESSED
		)
	then
		return m:SetAction(Action.WAKING_UP, m.ActionState)
	end

	if m.Position.Y - m:FindFloorHeightRelativePolar(-0x8000, 60) > 24 then
		return m:SetAction(Action.WAKING_UP, m.ActionState)
	end

	m.BodyState.EyeState = MarioEyes.CLOSED
	m:StationaryGroundStep()

	if m.ActionState == 0 then
		animFrame = m:SetAnimation(Animations.SLEEP_IDLE)

		if animFrame == 2 then
			m:PlaySound(Sounds.MARIO_SNORING1)
		end

		if animFrame == 20 then
			m:PlaySound(Sounds.MARIO_SNORING2)
		end

		if m:IsAnimAtEnd() then
			m.ActionTimer += 1

			if m.ActionTimer > 45 then
				m.ActionState += 1
			end
		end
	elseif m.ActionState == 1 then
		if m:SetAnimation(Animations.SLEEP_START_LYING) == 18 then
			m:PlayHeavyLandingSound(Sounds.ACTION_TERRAIN_BODY_HIT_GROUND)
		end

		if m:IsAnimAtEnd() then
			m.ActionState += 1
		end
	elseif m.ActionState == 2 then
		m:SetAnimation(Animations.SLEEP_LYING)
		m:PlaySoundIfNoFlag(Sounds.MARIO_SNORING3, MarioFlags.ACTION_SOUND_PLAYED)
	end

	return false
end)

DEF_ACTION(Action.WAKING_UP, function(m: Mario)
	if m.Input:Has(InputFlags.STOMPED) then
		return m:SetAction(Action.SHOCKWAVE_BOUNCE)
	end

	if m.Input:Has(InputFlags.OFF_FLOOR) then
		return m:SetAction(Action.FREEFALL)
	end

	if m.Input:Has(InputFlags.ABOVE_SLIDE) then
		return m:SetAction(Action.BEGIN_SLIDING)
	end

	m.ActionTimer += 1

	if m.ActionTimer > 20 then
		return m:SetAction(Action.IDLE)
	end

	m:StationaryGroundStep()
	m:SetAnimation(if m.ActionArg == 0 then Animations.WAKE_FROM_SLEEP else Animations.WAKE_FROM_LYING)

	return false
end)

DEF_ACTION(Action.STANDING_AGAINST_WALL, function(m: Mario)
	if m.Input:Has(InputFlags.STOMPED) then
		return m:SetAction(Action.SHOCKWAVE_BOUNCE)
	end

	if m.Input:Has(InputFlags.NONZERO_ANALOG, InputFlags.A_PRESSED, InputFlags.OFF_FLOOR, InputFlags.ABOVE_SLIDE) then
		return m:CheckCommonActionExits()
	end

	if m.Input:Has(InputFlags.B_PRESSED) then
		return m:SetAction(Action.PUNCHING)
	end

	m:SetAnimation(Animations.A_POSE)
	m:StationaryGroundStep()

	return false
end)

DEF_ACTION(Action.CROUCHING, function(m: Mario)
	if m.Input:Has(InputFlags.STOMPED) then
		return m:SetAction(Action.SHOCKWAVE_BOUNCE)
	end

	if m.Input:Has(InputFlags.A_PRESSED) then
		return m:SetAction(Action.BACKFLIP)
	end

	if m.Input:Has(InputFlags.OFF_FLOOR) then
		return m:SetAction(Action.FREEFALL)
	end

	if m.Input:Has(InputFlags.ABOVE_SLIDE) then
		return m:SetAction(Action.BEGIN_SLIDING)
	end

	if not m.Input:Has(InputFlags.Z_DOWN) then
		return m:SetAction(Action.STOP_CROUCHING)
	end

	if m.Input:Has(InputFlags.NONZERO_ANALOG) then
		return m:SetAction(Action.START_CRAWLING)
	end

	if m.Input:Has(InputFlags.B_PRESSED) then
		return m:SetAction(Action.PUNCHING, 9)
	end

	m:StationaryGroundStep()
	m:SetAnimation(Animations.CROUCHING)

	return false
end)

DEF_ACTION(Action.PANTING, function(m: Mario)
	if m.Input:Has(InputFlags.STOMPED) then
		return m:SetAction(Action.SHOCKWAVE_BOUNCE)
	end

	if m.Health >= 0x500 then
		return m:SetAction(Action.IDLE)
	end

	if checkCommonIdleCancels(m) then
		return true
	end

	if m:SetAnimation(Animations.PANTING) == 1 then
		m:PlaySound(Sounds.MARIO_PANTING)
	end

	m:StationaryGroundStep()
	m.BodyState.EyeState = MarioEyes.HALF_CLOSED

	return false
end)

DEF_ACTION(Action.BRAKING_STOP, function(m: Mario)
	if m.Input:Has(InputFlags.STOMPED) then
		return m:SetAction(Action.SHOCKWAVE_BOUNCE)
	end

	if m.Input:Has(InputFlags.OFF_FLOOR) then
		return m:SetAction(Action.FREEFALL)
	end

	if m.Input:Has(InputFlags.B_PRESSED) then
		return m:SetAction(Action.PUNCHING)
	end

	if m.Input:Has(InputFlags.NONZERO_ANALOG, InputFlags.A_PRESSED, InputFlags.OFF_FLOOR, InputFlags.ABOVE_SLIDE) then
		return m:CheckCommonActionExits()
	end

	stoppingStep(m, Animations.STOP_SKID, Action.IDLE)
	return false
end)

DEF_ACTION(Action.BUTT_SLIDE_STOP, function(m: Mario)
	if m.Input:Has(InputFlags.STOMPED) then
		return m:SetAction(Action.SHOCKWAVE_BOUNCE)
	end

	if m.Input:Has(InputFlags.NONZERO_ANALOG, InputFlags.A_PRESSED, InputFlags.OFF_FLOOR, InputFlags.ABOVE_SLIDE) then
		return m:CheckCommonActionExits()
	end

	stoppingStep(m, Animations.STOP_SLIDE, Action.IDLE)

	if m.AnimFrame == 6 then
		m:PlayLandingSound()
	end

	return false
end)

DEF_ACTION(Action.SLIDE_KICK_SLIDE_STOP, function(m: Mario)
	if m.Input:Has(InputFlags.STOMPED) then
		return m:SetAction(Action.SHOCKWAVE_BOUNCE)
	end

	if m.Input:Has(InputFlags.OFF_FLOOR) then
		return m:SetAction(Action.FREEFALL)
	end

	stoppingStep(m, Animations.CROUCH_FROM_SLIDE_KICK, Action.CROUCHING)
	return false
end)

DEF_ACTION(Action.START_CROUCHING, function(m: Mario)
	if m:CheckCommonActionExits() then
		return true
	end

	m:StationaryGroundStep()
	m:SetAnimation(Animations.START_CROUCHING)

	if m:IsAnimPastEnd() then
		m:SetAction(Action.CROUCHING)
	end

	return false
end)

DEF_ACTION(Action.STOP_CROUCHING, function(m: Mario)
	if m:CheckCommonActionExits() then
		return true
	end

	m:StationaryGroundStep()
	m:SetAnimation(Animations.START_CROUCHING)

	if m:IsAnimPastEnd() then
		m:SetAction(Action.IDLE)
	end

	return false
end)

DEF_ACTION(Action.START_CRAWLING, function(m: Mario)
	if m.Input:Has(InputFlags.OFF_FLOOR) then
		return m:SetAction(Action.FREEFALL)
	end

	if m.Input:Has(InputFlags.STOMPED) then
		return m:SetAction(Action.SHOCKWAVE_BOUNCE)
	end

	if m.Input:Has(InputFlags.ABOVE_SLIDE) then
		return m:SetAction(Action.BEGIN_SLIDING)
	end

	m:StationaryGroundStep()
	m:SetAnimation(Animations.START_CRAWLING)

	if m:IsAnimPastEnd() then
		m:SetAction(Action.CRAWLING)
	end

	return false
end)

DEF_ACTION(Action.STOP_CRAWLING, function(m: Mario)
	if m.Input:Has(InputFlags.OFF_FLOOR) then
		return m:SetAction(Action.FREEFALL)
	end

	if m.Input:Has(InputFlags.STOMPED) then
		return m:SetAction(Action.SHOCKWAVE_BOUNCE)
	end

	if m.Input:Has(InputFlags.ABOVE_SLIDE) then
		return m:SetAction(Action.BEGIN_SLIDING)
	end

	m:StationaryGroundStep()
	m:SetAnimation(Animations.STOP_CRAWLING)

	if m:IsAnimPastEnd() then
		m:SetAction(Action.CROUCHING)
	end

	return false
end)

DEF_ACTION(Action.SHOCKWAVE_BOUNCE, function(m: Mario)
	m.ActionTimer += 1

	if m.ActionTimer == 48 then
		m:SetAction(Action.IDLE)
	end

	local sp1E = bit32.lshift(m.ActionTimer % 16, 12)
	local sp18 = ((6 - m.ActionTimer / 8) * 8) + 4

	m:SetForwardVel(0)
	m.Velocity = Vector3.zero

	if Util.Sins(sp1E) >= 0 then
		m.Position = Util.SetY(m.Position, Util.Sins(sp1E) * sp18 + m.FloorHeight)
	else
		m.Position = Util.SetY(m.Position, m.FloorHeight - Util.Sins(sp1E) * sp18)
	end

	m:SetAnimation(Animations.A_POSE)
	return false
end)

DEF_ACTION(Action.JUMP_LAND_STOP, function(m: Mario)
	if checkCommonLandingCancels(m, 0) then
		return true
	end

	landingStep(m, Animations.LAND_FROM_SINGLE_JUMP, Action.IDLE)
	return false
end)

DEF_ACTION(Action.DOUBLE_JUMP_LAND_STOP, function(m: Mario)
	if checkCommonLandingCancels(m, 0) then
		return true
	end

	landingStep(m, Animations.LAND_FROM_DOUBLE_JUMP, Action.IDLE)
	return false
end)

DEF_ACTION(Action.SIDE_FLIP_LAND_STOP, function(m: Mario)
	if checkCommonLandingCancels(m, 0) then
		return true
	end

	landingStep(m, Animations.SLIDEFLIP_LAND, Action.IDLE)
	--m.GfxAngle += Vector3int16.new(0, 0x8000, 0)

	return false
end)

DEF_ACTION(Action.FREEFALL_LAND_STOP, function(m: Mario)
	if checkCommonLandingCancels(m, 0) then
		return true
	end

	landingStep(m, Animations.GENERAL_LAND, Action.IDLE)
	return false
end)

DEF_ACTION(Action.TRIPLE_JUMP_LAND_STOP, function(m: Mario)
	if checkCommonLandingCancels(m, Action.JUMP) then
		return true
	end

	landingStep(m, Animations.TRIPLE_JUMP_LAND, Action.IDLE)
	return false
end)

DEF_ACTION(Action.BACKFLIP_LAND_STOP, function(m: Mario)
	if not m.Input:Has(InputFlags.Z_DOWN) and m.AnimFrame >= 6 then
		m.Input:Remove(InputFlags.A_PRESSED)
	end

	if checkCommonLandingCancels(m, Action.BACKFLIP) then
		return true
	end

	landingStep(m, Animations.TRIPLE_JUMP_LAND, Action.IDLE)
	return false
end)

DEF_ACTION(Action.LAVA_BOOST_LAND, function(m: Mario)
	m.Input:Remove(InputFlags.FIRST_PERSON, InputFlags.B_PRESSED)

	if checkCommonLandingCancels(m, 0) then
		return true
	end

	landingStep(m, Animations.STAND_UP_FROM_LAVA_BOOST, Action.IDLE)
	return false
end)

DEF_ACTION(Action.LONG_JUMP_LAND_STOP, function(m: Mario)
	m.Input:Remove(InputFlags.B_PRESSED)

	if checkCommonLandingCancels(m, Action.JUMP) then
		return true
	end

	landingStep(
		m,
		if m.LongJumpIsSlow then Animations.CROUCH_FROM_FAST_LONGJUMP else Animations.CROUCH_FROM_SLOW_LONGJUMP,
		Action.CROUCHING
	)

	return false
end)

DEF_ACTION(Action.TWIRL_LAND, function(m: Mario)
	m.ActionState = 1

	if m.Input:Has(InputFlags.STOMPED) then
		return m:SetAction(Action.SHOCKWAVE_BOUNCE)
	end

	if m.Input:Has(InputFlags.OFF_FLOOR) then
		return m:SetAction(Action.FREEFALL)
	end

	m:StationaryGroundStep()
	m:SetAnimation(Animations.TWIRL_LAND)

	if m.AngleVel.Y > 0 then
		m.AngleVel -= Vector3int16.new(0, 0x400, 0)

		if m.AngleVel.Y < 0 then
			m.AngleVel *= Vector3int16.new(1, 0, 1)
		end

		m.TwirlYaw += m.AngleVel.Y
	end

	m.GfxAngle += Vector3int16.new(0, m.TwirlYaw, 0)

	if m:IsAnimAtEnd() and m.AngleVel.Y == 0 then
		m.FaceAngle += Vector3int16.new(0, m.TwirlYaw, 0)
		m:SetAction(Action.IDLE)
	end

	return false
end)

DEF_ACTION(Action.GROUND_POUND_LAND, function(m: Mario)
	if m.Input:Has(InputFlags.STOMPED) then
		return m:SetAction(Action.SHOCKWAVE_BOUNCE)
	end

	if m.Input:Has(InputFlags.OFF_FLOOR) then
		return m:SetAction(Action.FREEFALL)
	end

	if m.Input:Has(InputFlags.ABOVE_SLIDE) then
		return m:SetAction(Action.BUTT_SLIDE)
	end

	landingStep(m, Animations.GROUND_POUND_LANDING, Action.BUTT_SLIDE_STOP)
	return false
end)

DEF_ACTION(Action.STOMACH_SLIDE_STOP, function(m: Mario)
	if m.Input:Has(InputFlags.STOMPED) then
		return m:SetAction(Action.SHOCKWAVE_BOUNCE)
	end

	if m.Input:Has(InputFlags.OFF_FLOOR) then
		return m:SetAction(Action.FREEFALL)
	end

	if m.Input:Has(InputFlags.ABOVE_SLIDE) then
		return m:SetAction(Action.BEGIN_SLIDING)
	end

	animatedStationaryGroundStep(m, Animations.SLOW_LAND_FROM_DIVE, Action.IDLE)
	return false
end)

DEF_ACTION(Action.IN_QUICKSAND, function(m: Mario)
	if m.QuicksandDepth < 30.0 then
		return m:SetAction(Action.IDLE, 0)
	end

	if checkCommonIdleCancels(m) then
		return true
	end

	if m.QuicksandDepth > 70 then
		m:SetAnimation(Animations.DYING_IN_QUICKSAND)
	else
		m:SetAnimation(Animations.IDLE_IN_QUICKSAND)
	end

	m:StationaryGroundStep()
	return false
end)

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
