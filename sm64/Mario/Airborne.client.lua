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

local function stopRising(m: Mario)
	if m.Velocity.Y > 0 then
		m.Velocity *= Vector3.new(1, 0, 1)
	end
end

local function playFlipSounds(m: Mario, frame1: number, frame2: number, frame3: number)
	local animFrame = m.AnimFrame

	if animFrame == frame1 or animFrame == frame2 or animFrame == frame3 then
		m:PlaySound(Sounds.ACTION_SPIN)
	end
end

local function playFarFallSound(m: Mario)
	if m.Flags:Has(MarioFlags.FALLING_FAR) then
		return
	end

	local action = m.Action

	if action() == Action.TWIRLING then
		return
	end

	if action() == Action.FLYING then
		return
	end

	if action:Has(ActionFlags.INVULNERABLE) then
		return
	end

	if m.PeakHeight - m.Position.Y > 1150 then
		m:PlaySound(Sounds.MARIO_WAAAOOOW)
		m.Flags:Add(MarioFlags.FALLING_FAR)
	end
end

local function playKnockbackSound(m: Mario)
	if m.ActionArg == 0 and math.abs(m.ForwardVel) >= 28 then
		m:PlaySoundIfNoFlag(Sounds.MARIO_DOH, MarioFlags.MARIO_SOUND_PLAYED)
	else
		m:PlaySoundIfNoFlag(Sounds.MARIO_UH, MarioFlags.MARIO_SOUND_PLAYED)
	end
end

local function lavaBoostOnWall(m: Mario)
	local wall = m.Wall

	if wall then
		local angle = Util.Atan2s(wall.Normal.Z, wall.Normal.X)
		m.FaceAngle = Util.SetYint16(m.FaceAngle, angle)
	end

	if m.ForwardVel < 24 then
		m.ForwardVel = 24
	end

	if not m.Flags:Has(MarioFlags.METAL_CAP) then
		m.HurtCounter += if m.Flags:Has(MarioFlags.CAP_ON_HEAD) then 12 else 18
	end

	m:PlaySound(Sounds.MARIO_ON_FIRE)
	m:SetAction(Action.LAVA_BOOST, 1)
end

local function checkFallDamage(m: Mario, hardFallAction: number): boolean
	local fallHeight = m.PeakHeight - m.Position.Y
	local damageHeight = 1150

	if m.Action() == Action.TWIRLING then
		return false
	end

	if m.Velocity.Y < -55 and fallHeight > 3000 then
		m.HurtCounter += if m.Flags:Has(MarioFlags.CAP_ON_HEAD) then 16 else 24
		m:PlaySound(Sounds.MARIO_ATTACKED)
		m:SetAction(hardFallAction, 4)
	elseif fallHeight > damageHeight and not m:FloorIsSlippery() then
		m.HurtCounter += if m.Flags:Has(MarioFlags.CAP_ON_HEAD) then 8 else 12
		m:PlaySound(Sounds.MARIO_ATTACKED)
		m.SquishTimer = 30
	end

	return false
end

local function checkKickOrDiveInAir(m: Mario): boolean
	if m.Input:Has(InputFlags.B_PRESSED) then
		m:SetAction(if m.ForwardVel > 28 then Action.DIVE else Action.JUMP_KICK)
	end

	return false
end

local function updateAirWithTurn(m: Mario)
	local dragThreshold = if m.Action() == Action.LONG_JUMP then 48 else 32
	m.ForwardVel = Util.ApproachFloat(m.ForwardVel, 0, 0.35)

	if m.Input:Has(InputFlags.NONZERO_ANALOG) then
		local intendedDYaw = m.IntendedYaw - m.FaceAngle.Y
		local intendedMag = m.IntendedMag / 32

		m.ForwardVel += 1.5 * Util.Coss(intendedDYaw) * intendedMag
		m.FaceAngle += Vector3int16.new(0, 512 * Util.Sins(intendedDYaw) * intendedMag, 0)
	end

	if m.ForwardVel > dragThreshold then
		m.ForwardVel -= 1
	end

	if m.ForwardVel < -16 then
		m.ForwardVel += 2
	end

	m.SlideVelX = m.ForwardVel * Util.Sins(m.FaceAngle.Y)
	m.SlideVelZ = m.ForwardVel * Util.Coss(m.FaceAngle.Y)
	m.Velocity = Vector3.new(m.SlideVelX, m.Velocity.Y, m.SlideVelZ)
end

local function updateAirWithoutTurn(m: Mario)
	local dragThreshold = 32

	if m.Action() == Action.LONG_JUMP then
		dragThreshold = 48
	end

	local sidewaysSpeed = 0
	m.ForwardVel = Util.ApproachFloat(m.ForwardVel, 0, 0.35)

	if m.Input:Has(InputFlags.NONZERO_ANALOG) then
		local intendedDYaw = m.IntendedYaw - m.FaceAngle.Y
		local intendedMag = m.IntendedMag / 32

		m.ForwardVel += intendedMag * Util.Coss(intendedDYaw) * 1.5
		sidewaysSpeed = intendedMag * Util.Sins(intendedDYaw) * 10
	end

	--! Uncapped air speed. Net positive when moving forward.
	if m.ForwardVel > dragThreshold then
		m.ForwardVel -= 1
	end

	if m.ForwardVel < -16 then
		m.ForwardVel += 2
	end

	m.SlideVelX = m.ForwardVel * Util.Sins(m.FaceAngle.Y)
	m.SlideVelZ = m.ForwardVel * Util.Coss(m.FaceAngle.Y)

	m.SlideVelX += sidewaysSpeed * Util.Sins(m.FaceAngle.Y + 0x4000)
	m.SlideVelZ += sidewaysSpeed * Util.Coss(m.FaceAngle.Y + 0x4000)

	m.Velocity = Vector3.new(m.SlideVelX, m.Velocity.Y, m.SlideVelZ)
end

local function updateLavaBoostOrTwirling(m: Mario)
	if m.Input:Has(InputFlags.NONZERO_ANALOG) then
		local intendedDYaw = m.IntendedYaw - m.FaceAngle.Y
		local intendedMag = m.IntendedMag / 32

		m.ForwardVel += Util.Coss(intendedDYaw) * intendedMag
		m.FaceAngle += Vector3int16.new(0, Util.Sins(intendedDYaw) * intendedMag * 1024, 0)

		if m.ForwardVel < 0 then
			m.FaceAngle += Vector3int16.new(0, 0x8000, 0)
			m.ForwardVel *= -1
		end

		if m.ForwardVel > 32 then
			m.ForwardVel -= 2
		end
	end

	m.SlideVelX = m.ForwardVel * Util.Sins(m.FaceAngle.Y)
	m.SlideVelZ = m.ForwardVel * Util.Coss(m.FaceAngle.Y)

	m.Velocity = Vector3.new(m.SlideVelX, m.Velocity.Y, m.SlideVelZ)
end

local function updateFlyingYaw(m: Mario)
	local targetYawVel = -Util.SignedShort(m.Controller.StickX * (m.ForwardVel / 4))

	if targetYawVel > 0 then
		if m.AngleVel.Y < 0 then
			m.AngleVel += Vector3int16.new(0, 0x40, 0)

			if m.AngleVel.Y > 0x10 then
				m.AngleVel = Util.SetYint16(m.AngleVel, 0x10)
			end
		else
			local y = Util.ApproachInt(m.AngleVel.Y, targetYawVel, 0x10, 0x20)
			m.AngleVel = Util.SetYint16(m.AngleVel, y)
		end
	elseif targetYawVel < 0 then
		if m.AngleVel.Y > 0 then
			m.AngleVel -= Vector3int16.new(0, 0x40, 0)

			if m.AngleVel.Y < -0x10 then
				m.AngleVel = Util.SetYint16(m.AngleVel, -0x10)
			end
		else
			local y = Util.ApproachInt(m.AngleVel.Y, targetYawVel, 0x20, 0x10)
			m.AngleVel = Util.SetYint16(m.AngleVel, y)
		end
	end

	m.FaceAngle += Vector3int16.new(0, m.AngleVel.Y, 0)
	m.FaceAngle = Util.SetZint16(m.FaceAngle, 20 * -m.AngleVel.Y)
end

local function updateFlyingPitch(m: Mario)
	local targetPitchVel = -Util.SignedShort(m.Controller.StickY * (m.ForwardVel / 5))

	if targetPitchVel > 0 then
		if m.AngleVel.X < 0 then
			m.AngleVel += Vector3int16.new(0x40, 0, 0)

			if m.AngleVel.X > 0x20 then
				m.AngleVel = Util.SetXint16(m.AngleVel, 0x20)
			end
		else
			local x = Util.ApproachInt(m.AngleVel.X, targetPitchVel, 0x20, 0x40)
			m.AngleVel = Util.SetXint16(m.AngleVel, x)
		end
	elseif targetPitchVel < 0 then
		if m.AngleVel.X > 0 then
			m.AngleVel -= Vector3int16.new(0x40, 0, 0)

			if m.AngleVel.X < -0x20 then
				m.AngleVel = Util.SetXint16(m.AngleVel, -0x20)
			end
		else
			local x = Util.ApproachInt(m.AngleVel.X, targetPitchVel, 0x40, 0x20)
			m.AngleVel = Util.SetXint16(m.AngleVel, x)
		end
	else
		local x = Util.ApproachInt(m.AngleVel.X, targetPitchVel, 0x40)
		m.AngleVel = Util.SetXint16(m.AngleVel, x)
	end
end

local function updateFlying(m: Mario)
	updateFlyingPitch(m)
	updateFlyingYaw(m)

	m.ForwardVel -= 2 * (m.FaceAngle.X / 0x4000) + 0.1
	m.ForwardVel -= 0.5 * (1 - Util.Coss(m.AngleVel.Y))

	if m.ForwardVel < 0 then
		m.ForwardVel = 0
	end

	if m.ForwardVel > 16 then
		m.FaceAngle = Util.SetXint16(m.FaceAngle, (m.ForwardVel - 32) * 6)
	elseif m.ForwardVel > 4 then
		m.FaceAngle = Util.SetXint16(m.FaceAngle, (m.ForwardVel - 32) * 10)
	else
		m.FaceAngle -= Vector3int16.new(0x400, 0, 0)
	end

	m.FaceAngle += Vector3int16.new(m.AngleVel.X, 0, 0)

	if m.FaceAngle.X > 0x2AAA then
		m.FaceAngle = Util.SetXint16(m.FaceAngle, 0x2AAA)
	end

	if m.FaceAngle.X < -0x2AAA then
		m.FaceAngle = Util.SetXint16(m.FaceAngle, -0x2AAA)
	end

	local velX = Util.Coss(m.FaceAngle.X) * Util.Sins(m.FaceAngle.Y)
	m.SlideVelX = velX

	local velZ = Util.Coss(m.FaceAngle.X) * Util.Coss(m.FaceAngle.Y)
	m.SlideVelZ = velZ

	local velY = Util.Sins(m.FaceAngle.X)
	m.Velocity = m.ForwardVel * Vector3.new(velX, velY, velZ)
end

local function commonAirActionStep(m: Mario, landAction: number, anim: Animation, stepArg: number): number
	-- stylua: ignore
	local stepResult do
		updateAirWithoutTurn(m)
		stepResult = m:PerformAirStep(stepArg)
	end

	if stepResult == AirStep.NONE then
		m:SetAnimation(anim)
	elseif stepResult == AirStep.LANDED then
		if not checkFallDamage(m, Action.HARD_BACKWARD_GROUND_KB) then
			m:SetAction(landAction)
		end
	elseif stepResult == AirStep.HIT_WALL then
		m:SetAnimation(anim)

		if m.ForwardVel > 16 then
			m:BonkReflection()
			m.FaceAngle += Vector3int16.new(0, 0x8000, 0)

			if m.Wall then
				m:SetAction(Action.AIR_HIT_WALL)
			else
				stopRising(m)

				if m.ForwardVel >= 38 then
					m.ParticleFlags:Add(ParticleFlags.VERTICAL_STAR)
					m:SetAction(Action.BACKWARD_AIR_KB)
				else
					if m.ForwardVel > 8 then
						m:SetForwardVel(-8)
					end

					m:SetAction(Action.SOFT_BONK)
				end
			end
		else
			m:SetForwardVel(0)
		end
	elseif stepResult == AirStep.GRABBED_LEDGE then
		m:SetAnimation(Animations.IDLE_ON_LEDGE)
		m:SetAction(Action.LEDGE_GRAB)
	elseif stepResult == AirStep.GRABBED_CEILING then
		m:SetAction(Action.START_HANGING)
	elseif stepResult == AirStep.HIT_LAVA_WALL then
		lavaBoostOnWall(m)
	end

	return stepResult
end

local function commonRolloutStep(m: Mario, anim: Animation)
	local stepResult

	if m.ActionState == 0 then
		m.Velocity = Util.SetY(m.Velocity, 30)
		m.ActionState = 1
	end

	m:PlaySound(Sounds.ACTION_TERRAIN_JUMP)
	updateAirWithoutTurn(m)

	stepResult = m:PerformAirStep()

	if stepResult == AirStep.NONE then
		if m.ActionState == 1 then
			if m:SetAnimation(anim) == 4 then
				m:PlaySound(Sounds.ACTION_SPIN)
			end
		else
			m:SetAnimation(Animations.GENERAL_FALL)
		end
	elseif stepResult == AirStep.LANDED then
		m:SetAction(Action.FREEFALL_LAND_STOP)
		m:PlayLandingSound()
	elseif stepResult == AirStep.HIT_WALL then
		m:SetForwardVel(0)
	elseif stepResult == AirStep.HIT_LAVA_WALL then
		lavaBoostOnWall(m)
	end

	if m.ActionState == 1 and m:IsAnimPastEnd() then
		m.ActionState = 2
	end
end

local function commonAirKnockbackStep(
	m: Mario,
	landAction: number,
	hardFallAction: number,
	anim: Animation,
	speed: number
)
	-- stylua: ignore
	local stepResult do
		m:SetForwardVel(speed)
		stepResult = m:PerformAirStep()
	end

	if stepResult == AirStep.NONE then
		m:SetAnimation(anim)
	elseif stepResult == AirStep.LANDED then
		if not checkFallDamage(m, hardFallAction) then
			local action = m.Action()

			if action == Action.THROWN_FORWARD or action == Action.THROWN_BACKWARD then
				m:SetAction(landAction, m.HurtCounter)
			else
				m:SetAction(landAction, m.ActionArg)
			end
		end
	elseif stepResult == AirStep.HIT_WALL then
		m:SetAnimation(Animations.BACKWARD_AIR_KB)
		m:BonkReflection()

		stopRising(m)
		m:SetForwardVel(-speed)
	elseif stepResult == AirStep.HIT_LAVA_WALL then
		lavaBoostOnWall(m)
	end

	return stepResult
end

local function checkWallKick(m: Mario)
	if m.WallKickTimer ~= 0 then
		if m.Input:Has(InputFlags.A_PRESSED) then
			if m.PrevAction() == Action.AIR_HIT_WALL then
				m.FaceAngle += Vector3int16.new(0, 0x8000, 0)
			end
		end
	end

	return false
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Actions
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local AIR_STEP_CHECK_BOTH = bit32.bor(AirStep.CHECK_LEDGE_GRAB, AirStep.CHECK_HANG)
local DEF_ACTION: (number, (Mario) -> boolean) -> () = System.RegisterAction

DEF_ACTION(Action.JUMP, function(m: Mario)
	if checkKickOrDiveInAir(m) then
		return true
	end

	if m.Input:Has(InputFlags.Z_PRESSED) then
		return m:SetAction(Action.GROUND_POUND)
	end

	m:PlayMarioSound(Sounds.ACTION_TERRAIN_JUMP)
	commonAirActionStep(m, Action.JUMP_LAND, Animations.SINGLE_JUMP, AIR_STEP_CHECK_BOTH)

	return false
end)

DEF_ACTION(Action.DOUBLE_JUMP, function(m: Mario)
	local anim = if m.Velocity.Y >= 0 then Animations.DOUBLE_JUMP_RISE else Animations.DOUBLE_JUMP_FALL

	if checkKickOrDiveInAir(m) then
		return true
	end

	if m.Input:Has(InputFlags.Z_PRESSED) then
		return m:SetAction(Action.GROUND_POUND)
	end

	m:PlayMarioSound(Sounds.ACTION_TERRAIN_JUMP, Sounds.MARIO_HOOHOO)
	commonAirActionStep(m, Action.DOUBLE_JUMP_LAND, anim, AIR_STEP_CHECK_BOTH)

	return false
end)

DEF_ACTION(Action.TRIPLE_JUMP, function(m: Mario)
	if m.Input:Has(InputFlags.B_PRESSED) then
		return m:SetAction(Action.DIVE)
	end

	if m.Input:Has(InputFlags.Z_PRESSED) then
		return m:SetAction(Action.GROUND_POUND)
	end

	m:PlayMarioSound(Sounds.ACTION_TERRAIN_JUMP)
	commonAirActionStep(m, Action.TRIPLE_JUMP_LAND, Animations.TRIPLE_JUMP, 0)

	playFlipSounds(m, 2, 8, 20)
	return false
end)

DEF_ACTION(Action.BACKFLIP, function(m: Mario)
	if m.Input:Has(InputFlags.Z_PRESSED) then
		return m:SetAction(Action.GROUND_POUND)
	end

	m:PlayMarioSound(Sounds.ACTION_TERRAIN_JUMP, Sounds.MARIO_YAH_WAH_HOO)
	commonAirActionStep(m, Action.BACKFLIP_LAND, Animations.BACKFLIP, 0)

	playFlipSounds(m, 2, 3, 17)
	return false
end)

DEF_ACTION(Action.FREEFALL, function(m: Mario)
	if m.Input:Has(InputFlags.B_PRESSED) then
		return m:SetAction(Action.DIVE)
	end

	if m.Input:Has(InputFlags.Z_PRESSED) then
		return m:SetAction(Action.GROUND_POUND)
	end

	local anim

	if m.ActionArg == 0 then
		anim = Animations.GENERAL_FALL
	elseif m.ActionArg == 1 then
		anim = Animations.FALL_FROM_SLIDE
	elseif m.ActionArg == 2 then
		anim = Animations.FALL_FROM_SLIDE_KICK
	end

	commonAirActionStep(m, Action.FREEFALL_LAND, anim, AirStep.CHECK_LEDGE_GRAB)
	return false
end)

DEF_ACTION(Action.SIDE_FLIP, function(m: Mario)
	if m.Input:Has(InputFlags.B_PRESSED) then
		return m:SetAction(Action.DIVE)
	end

	if m.Input:Has(InputFlags.Z_PRESSED) then
		return m:SetAction(Action.GROUND_POUND)
	end

	m:PlayMarioSound(Sounds.ACTION_TERRAIN_JUMP)
	commonAirActionStep(m, Action.SIDE_FLIP_LAND, Animations.SLIDEFLIP, AirStep.CHECK_LEDGE_GRAB)

	if m.AnimFrame == 6 then
		m:PlaySound(Sounds.ACTION_SIDE_FLIP)
	end

	return false
end)

DEF_ACTION(Action.WALL_KICK_AIR, function(m: Mario)
	if m.Input:Has(InputFlags.B_PRESSED) then
		return m:SetAction(Action.DIVE)
	end

	if m.Input:Has(InputFlags.Z_PRESSED) then
		return m:SetAction(Action.GROUND_POUND)
	end

	m:PlayJumpSound()
	commonAirActionStep(m, Action.JUMP_LAND, Animations.SLIDEJUMP, AirStep.CHECK_LEDGE_GRAB)

	return false
end)

DEF_ACTION(Action.LONG_JUMP, function(m: Mario)
	local anim = if m.LongJumpIsSlow then Animations.SLOW_LONGJUMP else Animations.FAST_LONGJUMP

	m:PlayMarioSound(Sounds.ACTION_TERRAIN_JUMP, Sounds.MARIO_YAHOO)
	commonAirActionStep(m, Action.LONG_JUMP_LAND, anim, AirStep.CHECK_LEDGE_GRAB)

	return false
end)

DEF_ACTION(Action.TWIRLING, function(m: Mario)
	local startTwirlYaw = m.TwirlYaw
	local yawVelTarget = 0x1000

	if m.Input:Has(InputFlags.A_DOWN) then
		yawVelTarget = 0x2000
	end

	local yVel = Util.ApproachInt(m.AngleVel.Y, yawVelTarget, 0x200)
	m.AngleVel = Util.SetYint16(m.AngleVel, yVel)
	m.TwirlYaw += yVel

	m:SetAnimation(if m.ActionArg == 0 then Animations.START_TWIRL else Animations.TWIRL)

	if m:IsAnimPastEnd() then
		m.ActionArg = 1
	end

	if startTwirlYaw > m.TwirlYaw then
		m:PlaySound(Sounds.ACTION_TWIRL)
	end

	local step = m:PerformAirStep()

	if step == AirStep.LANDED then
		m:SetAction(Action.TWIRL_LAND)
	elseif step == AirStep.HIT_WALL then
		m:BonkReflection(false)
	elseif step == AirStep.HIT_LAVA_WALL then
		lavaBoostOnWall(m)
	end

	m.GfxAngle += Vector3int16.new(0, m.TwirlYaw, 0)
	return false
end)

DEF_ACTION(Action.DIVE, function(m: Mario)
	local airStep

	if m.ActionArg == 0 then
		m:PlayMarioSound(Sounds.ACTION_THROW, Sounds.MARIO_HOOHOO)
	else
		m:PlayMarioSound(Sounds.ACTION_TERRAIN_JUMP)
	end

	m:SetAnimation(Animations.DIVE)
	updateAirWithoutTurn(m)
	airStep = m:PerformAirStep()

	if airStep == AirStep.NONE then
		if m.Velocity.Y < 0 and m.FaceAngle.X > -0x2AAA then
			m.FaceAngle -= Vector3int16.new(0x200, 0, 0)

			if m.FaceAngle.X < -0x2AAA then
				m.FaceAngle = Util.SetXint16(m.FaceAngle, -0x2AAA)
			end
		end

		m.GfxAngle = Util.SetXint16(m.GfxAngle, -m.FaceAngle.X)
	elseif airStep == AirStep.LANDED then
		if not checkFallDamage(m, Action.HARD_FORWARD_GROUND_KB) then
			m:SetAction(Action.DIVE_SLIDE)
		end

		m.FaceAngle *= Vector3int16.new(0, 1, 1)
	elseif airStep == AirStep.HIT_WALL then
		m:BonkReflection(true)
		m.FaceAngle *= Vector3int16.new(0, 1, 1)

		stopRising(m)

		m.ParticleFlags:Add(ParticleFlags.VERTICAL_STAR)
		m:SetAction(Action.BACKWARD_AIR_KB)
	elseif airStep == AirStep.HIT_LAVA_WALL then
		lavaBoostOnWall(m)
	end

	return false
end)

DEF_ACTION(Action.STEEP_JUMP, function(m: Mario)
	local airStep

	if m.Input:Has(InputFlags.B_PRESSED) then
		return m:SetAction(Action.DIVE)
	end

	m:PlayMarioSound(Sounds.ACTION_TERRAIN_JUMP)
	m:SetForwardVel(0.98 * m.ForwardVel)
	airStep = m:PerformAirStep()

	if airStep == AirStep.LANDED then
		if not checkFallDamage(m, Action.HARD_BACKWARD_GROUND_KB) then
			m.FaceAngle *= Vector3int16.new(0, 1, 1)
			m:SetAction(if m.ForwardVel < 0 then Action.BEGIN_SLIDING else Action.JUMP_LAND)
		end
	elseif airStep == AirStep.HIT_WALL then
		m:SetForwardVel(0)
	elseif airStep == AirStep.HIT_LAVA_WALL then
		lavaBoostOnWall(m)
	end

	m:SetAnimation(Animations.SINGLE_JUMP)
	m.GfxAngle = Util.SetYint16(m.GfxAngle, m.SteepJumpYaw)

	return false
end)

DEF_ACTION(Action.GROUND_POUND, function(m: Mario)
	local stepResult
	local yOffset

	m:PlaySoundIfNoFlag(Sounds.ACTION_THROW, MarioFlags.ACTION_SOUND_PLAYED)

	if m.ActionState == 0 then
		if m.ActionTimer < 10 then
			yOffset = 20 - 2 * m.ActionTimer

			if m.Position.Y + yOffset + 160 < m.CeilHeight then
				m.Position += Vector3.new(0, yOffset, 0)
				m.PeakHeight = m.Position.Y
			end
		end

		m.Velocity = Util.SetY(m.Velocity, -50)
		m:SetForwardVel(0)

		m:SetAnimation(if m.ActionArg == 0 then Animations.START_GROUND_POUND else Animations.TRIPLE_JUMP_GROUND_POUND)

		if m.ActionTimer == 0 then
			m:PlaySound(Sounds.ACTION_SPIN)
		end

		m.ActionTimer += 1

		if m.ActionTimer >= m.AnimFrameCount + 4 then
			m:PlaySound(Sounds.MARIO_GROUND_POUND_WAH)
			m.ActionState = 1
		end
	else
		m:SetAnimation(Animations.GROUND_POUND)
		stepResult = m:PerformAirStep()

		if stepResult == AirStep.LANDED then
			m:PlayHeavyLandingSound(Sounds.ACTION_HEAVY_LANDING)

			if not checkFallDamage(m, Action.HARD_BACKWARD_GROUND_KB) then
				m.ParticleFlags:Add(ParticleFlags.MIST_CIRCLE, ParticleFlags.HORIZONTAL_STAR)
				m:SetAction(Action.GROUND_POUND_LAND)
			end
		elseif stepResult == AirStep.HIT_WALL then
			m:SetForwardVel(-16)
			stopRising(m)

			m.ParticleFlags:Add(ParticleFlags.VERTICAL_STAR)
			m:SetAction(Action.BACKWARD_AIR_KB)
		end
	end

	return false
end)

DEF_ACTION(Action.BURNING_JUMP, function(m: Mario)
	m:PlayMarioSound(Sounds.ACTION_TERRAIN_JUMP)
	m:SetForwardVel(m.ForwardVel)

	if m:PerformAirStep() == AirStep.LANDED then
		m:PlayLandingSound()
		m:SetAction(Action.BURNING_GROUND)
	end

	m:SetAnimation(Animations.GENERAL_FALL)
	m.ParticleFlags:Add(ParticleFlags.FIRE)
	m:PlaySound(Sounds.MOVING_LAVA_BURN)

	m.BurnTimer += 3
	m.Health -= 10

	if m.Health < 0x100 then
		m.Health = 0xFF
	end

	return false
end)

DEF_ACTION(Action.BURNING_FALL, function(m: Mario)
	m:SetForwardVel(m.ForwardVel)

	if m:PerformAirStep() == AirStep.LANDED then
		m:PlayLandingSound(Sounds.ACTION_TERRAIN_LANDING)
		m:SetAction(Action.BURNING_GROUND)
	end

	m:SetAnimation(Animations.GENERAL_FALL)
	m.ParticleFlags:Add(ParticleFlags.FIRE)

	m.BurnTimer += 3
	m.Health -= 10

	if m.Health < 0x100 then
		m.Health = 0xFF
	end

	return false
end)

DEF_ACTION(Action.BACKWARD_AIR_KB, function(m: Mario)
	if checkWallKick(m) then
		return true
	end

	playKnockbackSound(m)
	commonAirKnockbackStep(
		m,
		Action.BACKWARD_GROUND_KB,
		Action.HARD_BACKWARD_GROUND_KB,
		Animations.BACKWARD_AIR_KB,
		-16
	)

	return false
end)

DEF_ACTION(Action.FORWARD_AIR_KB, function(m: Mario)
	if checkWallKick(m) then
		return true
	end

	playKnockbackSound(m)
	commonAirKnockbackStep(m, Action.FORWARD_GROUND_KB, Action.HARD_FORWARD_GROUND_KB, Animations.FORWARD_AIR_KB, 16)

	return false
end)

DEF_ACTION(Action.HARD_BACKWARD_AIR_KB, function(m: Mario)
	if checkWallKick(m) then
		return true
	end

	playKnockbackSound(m)
	commonAirKnockbackStep(
		m,
		Action.HARD_BACKWARD_GROUND_KB,
		Action.HARD_BACKWARD_GROUND_KB,
		Animations.BACKWARD_AIR_KB,
		-16
	)

	return false
end)

DEF_ACTION(Action.HARD_FORWARD_AIR_KB, function(m: Mario)
	if checkWallKick(m) then
		return true
	end

	playKnockbackSound(m)
	commonAirKnockbackStep(
		m,
		Action.HARD_FORWARD_GROUND_KB,
		Action.HARD_FORWARD_GROUND_KB,
		Animations.FORWARD_AIR_KB,
		16
	)

	return false
end)

DEF_ACTION(Action.THROWN_BACKWARD, function(m: Mario)
	local landAction = if m.ActionArg ~= 0 then Action.HARD_BACKWARD_GROUND_KB else Action.BACKWARD_GROUND_KB

	m:PlaySoundIfNoFlag(Sounds.MARIO_WAAAOOOW, MarioFlags.MARIO_SOUND_PLAYED)
	commonAirKnockbackStep(m, landAction, Action.HARD_BACKWARD_GROUND_KB, Animations.BACKWARD_AIR_KB, m.ForwardVel)

	m.ForwardVel *= 0.98
	return false
end)

DEF_ACTION(Action.THROWN_FORWARD, function(m: Mario)
	local landAction = if m.ActionArg ~= 0 then Action.HARD_FORWARD_GROUND_KB else Action.FORWARD_GROUND_KB

	m:PlaySoundIfNoFlag(Sounds.MARIO_WAAAOOOW, MarioFlags.MARIO_SOUND_PLAYED)

	if
		commonAirKnockbackStep(m, landAction, Action.HARD_FORWARD_GROUND_KB, Animations.FORWARD_AIR_KB, m.ForwardVel)
		== AirStep.NONE
	then
		local pitch = Util.Atan2s(m.ForwardVel, -m.Velocity.Y)

		if pitch > 0x1800 then
			pitch = 0x1800
		end

		m.GfxAngle = Util.SetXint16(m.GfxAngle, pitch + 0x1800)
	end

	m.ForwardVel *= 0.98
	return false
end)

DEF_ACTION(Action.SOFT_BONK, function(m: Mario)
	if checkWallKick(m) then
		return true
	end

	playKnockbackSound(m)
	commonAirKnockbackStep(
		m,
		Action.FREEFALL_LAND,
		Action.HARD_BACKWARD_GROUND_KB,
		Animations.GENERAL_FALL,
		m.ForwardVel
	)

	return false
end)

DEF_ACTION(Action.AIR_HIT_WALL, function(m: Mario)
	m.ActionTimer += 1

	if m.ActionTimer <= 2 then
		if m.Input:Has(InputFlags.A_PRESSED) then
			m.Velocity = Util.SetY(m.Velocity, 52)
			m.FaceAngle += Vector3int16.new(0, 0x8000, 0)
			return m:SetAction(Action.WALL_KICK_AIR)
		end
	else
		m.WallKickTimer = 5
		stopRising(m)

		if m.ForwardVel >= 38 then
			m.ParticleFlags:Add(ParticleFlags.VERTICAL_STAR)
			return m:SetAction(Action.BACKWARD_AIR_KB)
		elseif m.ForwardVel > 8 then
			m:SetForwardVel(-8)
			return m:SetAction(Action.SOFT_BONK)
		end
	end

	m:SetAnimation(Animations.START_WALLKICK)
	return true
end)

DEF_ACTION(Action.FORWARD_ROLLOUT, function(m: Mario)
	commonRolloutStep(m, Animations.FORWARD_SPINNING)
	return false
end)

DEF_ACTION(Action.BACKWARD_ROLLOUT, function(m: Mario)
	commonRolloutStep(m, Animations.BACKWARD_SPINNING)
	return false
end)

DEF_ACTION(Action.BUTT_SLIDE_AIR, function(m: Mario)
	local stepResult
	m.ActionTimer += 1

	if m.ActionTimer > 30 and m.Position.Y - m.FloorHeight > 500 then
		return m:SetAction(Action.FREEFALL, 1)
	end

	updateAirWithTurn(m)
	stepResult = m:PerformAirStep()

	if stepResult == AirStep.LANDED then
		if m.ActionState == 0 and m.Velocity.Y < 0 then
			local floor = m.Floor

			if floor and floor.Normal.Y > 0.9848077 then
				m.Velocity *= Vector3.new(1, -0.5, 1)
				m.ActionState = 1
			else
				m:SetAction(Action.BUTT_SLIDE)
			end
		else
			m:SetAction(Action.BUTT_SLIDE)
		end

		m:PlayLandingSound()
	elseif stepResult == AirStep.HIT_WALL then
		stopRising(m)
		m.ParticleFlags:Add(ParticleFlags.VERTICAL_STAR)
		m:SetAction(Action.BACKWARD_AIR_KB)
	elseif stepResult == AirStep.HIT_LAVA_WALL then
		lavaBoostOnWall(m)
	end

	m:SetAnimation(Animations.SLIDE)
	return false
end)

DEF_ACTION(Action.LAVA_BOOST, function(m: Mario)
	local stepResult
	m:PlaySoundIfNoFlag(Sounds.MARIO_ON_FIRE, MarioFlags.MARIO_SOUND_PLAYED)

	if not m.Input:Has(InputFlags.NONZERO_ANALOG) then
		m.ForwardVel = Util.ApproachFloat(m.ForwardVel, 0, 0.35)
	end

	updateLavaBoostOrTwirling(m)
	stepResult = m:PerformAirStep()

	if stepResult == AirStep.LANDED then
		local floor = m.Floor
		local floorType: Enum.Material?

		if floor then
			floorType = floor.Material
		end

		if floorType == Enum.Material.CrackedLava then
			m.ActionState = 0

			if not m.Flags:Has(MarioFlags.METAL_CAP) then
				m.HurtCounter += if m.Flags:Has(MarioFlags.CAP_ON_HEAD) then 12 else 18
			end

			m.Velocity = Util.SetY(m.Velocity, 84)
			m:PlaySound(Sounds.MARIO_ON_FIRE)
		else
			m:PlayHeavyLandingSound(Sounds.ACTION_TERRAIN_BODY_HIT_GROUND)

			if m.ActionState < 2 and m.Velocity.Y < 0 then
				m.Velocity *= Vector3.new(1, -0.4, 1)
				m:SetForwardVel(m.ForwardVel / 2)
				m.ActionState += 1
			else
				m:SetAction(Action.LAVA_BOOST_LAND)
			end
		end
	elseif stepResult == AirStep.HIT_WALL then
		m:BonkReflection()
	elseif stepResult == AirStep.HIT_LAVA_WALL then
		lavaBoostOnWall(m)
	end

	m:SetAnimation(Animations.FIRE_LAVA_BURN)

	if not m.Flags:Has(MarioFlags.METAL_CAP) and m.Velocity.Y > 0 then
		m.ParticleFlags:Add(ParticleFlags.FIRE)

		if m.ActionState == 0 then
			m:PlaySound(Sounds.MOVING_LAVA_BURN)
		end
	end

	m.BodyState.EyeState = MarioEyes.DEAD
	return false
end)

DEF_ACTION(Action.SLIDE_KICK, function(m: Mario)
	local stepResult

	if m.ActionState == 0 and m.ActionTimer == 0 then
		m:PlayMarioSound(Sounds.ACTION_TERRAIN_JUMP, Sounds.MARIO_HOOHOO)
		m:SetAnimation(Animations.SLIDE_KICK)
	end

	m.ActionTimer += 1

	if m.ActionTimer > 30 and m.Position.Y - m.FloorHeight > 500 then
		return m:SetAction(Action.FREEFALL, 2)
	end

	updateAirWithoutTurn(m)
	stepResult = m:PerformAirStep()

	if stepResult == AirStep.NONE then
		if m.ActionState == 0 then
			local tilt = Util.Atan2s(m.ForwardVel, -m.Velocity.Y)

			if tilt > 0x1800 then
				tilt = 0x1800
			end

			m.GfxAngle = Util.SetXint16(m.GfxAngle, tilt)
		end
	elseif stepResult == AirStep.LANDED then
		if m.ActionState == 0 and m.Velocity.Y < 0 then
			m.Velocity *= Vector3.new(1, -0.5, 1)
			m.ActionState = 1
			m.ActionTimer = 0
		else
			m:SetAction(Action.SLIDE_KICK_SLIDE)
		end

		m:PlayLandingSound()
	elseif stepResult == AirStep.HIT_WALL then
		stopRising(m)
		m.ParticleFlags:Add(ParticleFlags.VERTICAL_STAR)
		m:SetAction(Action.BACKWARD_AIR_KB)
	elseif stepResult == AirStep.HIT_LAVA_WALL then
		lavaBoostOnWall(m)
	end

	return false
end)

DEF_ACTION(Action.JUMP_KICK, function(m: Mario)
	local stepResult

	if m.ActionState == 0 then
		m:PlaySoundIfNoFlag(Sounds.MARIO_PUNCH_HOO, MarioFlags.ACTION_SOUND_PLAYED)
		m.AnimReset = true

		m:SetAnimation(Animations.AIR_KICK)
		m.ActionState = 1
	end

	local animFrame = m.AnimFrame

	if animFrame == 0 then
		m.BodyState.PunchType = 2
		m.BodyState.PunchTimer = 6
	end

	if animFrame >= 0 and animFrame < 8 then
		m.Flags:Add(MarioFlags.KICKING)
	end

	updateAirWithoutTurn(m)
	stepResult = m:PerformAirStep()

	if stepResult == AirStep.LANDED then
		if not checkFallDamage(m, Action.HARD_BACKWARD_GROUND_KB) then
			m:SetAction(Action.FREEFALL_LAND)
		end
	elseif stepResult == AirStep.HIT_WALL then
		m:SetForwardVel(0)
	end

	return false
end)

DEF_ACTION(Action.FLYING, function(m: Mario)
	local startPitch = m.FaceAngle.X

	if m.Input:Has(InputFlags.Z_PRESSED) then
		return m:SetAction(Action.GROUND_POUND)
	end

	if not m.Flags:Has(MarioFlags.WING_CAP) then
		return m:SetAction(Action.FREEFALL)
	end

	if m.ActionState == 0 then
		if m.ActionArg == 0 then
			m:SetAnimation(Animations.FLY_FROM_CANNON)
		else
			m:SetAnimation(Animations.FORWARD_SPINNING_FLIP)

			if m.AnimFrame == 1 then
				m:PlaySound(Sounds.ACTION_SPIN)
			end
		end

		if m:IsAnimAtEnd() then
			m:SetAnimation(Animations.WING_CAP_FLY)
			m.ActionState = 1
		end
	end

	local stepResult
	do
		updateFlying(m)
		stepResult = m:PerformAirStep()
	end

	if stepResult == AirStep.NONE then
		local faceAngle = m.FaceAngle
		m.GfxAngle = Util.SetXint16(m.GfxAngle, -m.FaceAngle.X)
		m.GfxAngle = Util.SetZint16(m.GfxAngle, m.FaceAngle.Z)
		m.ActionTimer = 0
	elseif stepResult == AirStep.LANDED then
		m:SetAction(Action.DIVE_SLIDE)
		m:SetAnimation(Animations.DIVE)

		m:SetAnimToFrame(7)
		m.FaceAngle *= Vector3int16.new(0, 1, 1)
	elseif stepResult == AirStep.HIT_WALL then
		if m.Wall then
			m:SetForwardVel(-16)
			m.FaceAngle *= Vector3int16.new(0, 1, 1)

			stopRising(m)
			m:PlaySound(if m.Flags:Has(MarioFlags.METAL_CAP) then Sounds.ACTION_METAL_BONK else Sounds.ACTION_BONK)

			m.ParticleFlags:Add(ParticleFlags.VERTICAL_STAR)
			m:SetAction(Action.BACKWARD_AIR_KB)
		else
			m.ActionTimer += 1

			if m.ActionTimer == 0 then
				m:PlaySound(Sounds.ACTION_HIT)
			end

			if m.ActionTimer == 30 then
				m.ActionTimer = 0
			end

			m.FaceAngle -= Vector3int16.new(0x200, 0, 0)

			if m.FaceAngle.X < -0x2AAA then
				m.FaceAngle = Util.SetXint16(m.FaceAngle, -0x2AAA)
			end

			m.GfxAngle = Util.SetXint16(m.GfxAngle, -m.FaceAngle.X)
			m.GfxAngle = Util.SetZint16(m.GfxAngle, m.FaceAngle.Z)
		end
	elseif stepResult == AirStep.HIT_LAVA_WALL then
		lavaBoostOnWall(m)
	end

	if m.FaceAngle.X > 0x800 and m.ForwardVel >= 48 then
		m.ParticleFlags:Add(ParticleFlags.DUST)
	end

	if startPitch <= 0 and m.FaceAngle.X > 0 and m.ForwardVel >= 48 then
		m:PlaySound(Sounds.ACTION_FLYING_FAST)
		m:PlaySound(Sounds.MARIO_YAHOO_WAHA_YIPPEE)
	end

	m:PlaySound(Sounds.MOVING_FLYING)
	m:AdjustSoundForSpeed()

	return false
end)

DEF_ACTION(Action.FLYING_TRIPLE_JUMP, function(m: Mario)
	if m.Input:Has(InputFlags.B_PRESSED) then
		return m:SetAction(Action.DIVE)
	end

	if m.Input:Has(InputFlags.Z_PRESSED) then
		return m:SetAction(Action.GROUND_POUND)
	end

	m:PlayMarioSound(Sounds.ACTION_TERRAIN_JUMP, Sounds.MARIO_YAHOO)

	if m.ActionState == 0 then
		m:SetAnimation(Animations.TRIPLE_JUMP_FLY)

		if m.AnimFrame == 7 then
			m:PlaySound(Sounds.ACTION_SPIN)
		end

		if m:IsAnimPastEnd() then
			m:SetAnimation(Animations.FORWARD_SPINNING)
			m.ActionState = 1
		end
	end

	if m.ActionState == 1 and m.AnimFrame == 1 then
		m:PlaySound(Sounds.ACTION_SPIN)
	end

	if m.Velocity.Y < 4 then
		if m.ForwardVel < 32 then
			m:SetForwardVel(32)
		end

		m:SetAction(Action.FLYING, 1)
	end

	m.ActionTimer += 1

	local stepResult
	do
		updateAirWithoutTurn(m)
		stepResult = m:PerformAirStep()
	end

	if stepResult == AirStep.LANDED then
		if not checkFallDamage(m, Action.HARD_BACKWARD_GROUND_KB) then
			m:SetAction(Action.DOUBLE_JUMP_LAND)
		end
	elseif stepResult == AirStep.HIT_WALL then
		m:BonkReflection()
	elseif stepResult == AirStep.HIT_LAVA_WALL then
		lavaBoostOnWall(m)
	end

	return false
end)

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
