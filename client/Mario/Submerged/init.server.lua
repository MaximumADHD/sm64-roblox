local System = require(script.Parent)
local Animations = System.Animations
local Sounds = System.Sounds
local Enums = System.Enums
local Util = System.Util

local Action = Enums.Action
local AirStep = Enums.AirStep
local WaterStep = Enums.WaterStep
local GroundStep = Enums.GroundStep
local InputFlags = Enums.InputFlags
local MarioFlags = Enums.MarioFlags
local ActionFlags = Enums.ActionFlags
local ParticleFlags = Enums.ParticleFlags

local MIN_SWIM_STRENGTH = 160
local MIN_SWIM_SPEED = 16

local sWasAtSurface = false
local sSwimStrength = MIN_SWIM_STRENGTH

local sBobTimer = 0
local sBobIncrement = 0
local sBobHeight = 0

type Mario = System.Mario

local function setSwimmingAtSurfaceParticles(m: Mario, particleFlag: number)
	local atSurface = m.Position.Y >= m.WaterLevel - 130

	if atSurface then
		m.ParticleFlags:Add(particleFlag)

		if atSurface ~= sWasAtSurface then
			m:PlaySound(Sounds.ACTION_UNKNOWN431)
		end
	end

	sWasAtSurface = atSurface
end

local function swimmingNearSurface(m: Mario)
	if m.Flags:Has(MarioFlags.METAL_CAP) then
		return false
	end

	return (m.WaterLevel - 80) - m.Position.Y < 400
end

local function getBuoyancy(m: Mario)
	local buoyancy = 0

	if m.Flags:Has(MarioFlags.METAL_CAP) then
		if m.Action:Has(ActionFlags.INVULNERABLE) then
			buoyancy = -2
		else
			buoyancy = -18
		end
	elseif swimmingNearSurface(m) then
		buoyancy = 1.25
	elseif not m.Action:Has(ActionFlags.MOVING) then
		buoyancy = -2
	end

	return buoyancy
end

local function performWaterFullStep(m: Mario, nextPos: Vector3)
	local adjusted, wall = Util.FindWallCollisions(nextPos, 10, 110)
	nextPos = adjusted

	local floorHeight, floor = Util.FindFloor(nextPos)
	local ceilHeight = Util.FindCeil(nextPos, floorHeight)

	if floor == nil then
		return WaterStep.CANCELLED
	end

	if nextPos.Y >= floorHeight then
		if ceilHeight - nextPos.Y >= 160 then
			m.Position = nextPos
			m.Floor = floor
			m.FloorHeight = floorHeight

			if wall then
				return WaterStep.HIT_WALL
			else
				return WaterStep.NONE
			end
		end

		if ceilHeight - floorHeight < 160 then
			return WaterStep.CANCELLED
		end

		--! Water ceiling downwarp
		m.Position = Util.SetY(nextPos, ceilHeight - 160)
		m.Floor = floor
		m.FloorHeight = floorHeight
		return WaterStep.HIT_CEILING
	else
		if ceilHeight - floorHeight < 160 then
			return WaterStep.CANCELLED
		end

		m.Position = Util.SetY(nextPos, floorHeight)
		m.Floor = floor
		m.FloorHeight = floorHeight
		return WaterStep.HIT_FLOOR
	end
end

local function applyWaterCurrent(m: Mario, step: Vector3): Vector3
	-- TODO: Implement if actually needed.
	--       This normally handles whirlpools and moving
	--       water, neither of which I think I'll be using.

	return step
end

local function performWaterStep(m: Mario)
	local nextPos = m.Position
	local step = m.Velocity

	if m.Action:Has(ActionFlags.SWIMMING) then
		step = applyWaterCurrent(m, step)
	end

	nextPos += step

	if nextPos.Y > m.WaterLevel - 80 then
		nextPos = Util.SetY(nextPos, m.WaterLevel - 80)
		m.Velocity *= Vector3.new(1, 0, 1)
	end

	local stepResult = performWaterFullStep(m, nextPos)
	m.GfxAngle = m.FaceAngle * Vector3int16.new(-1, 1, 1)
	m.GfxPos = Vector3.zero

	return stepResult
end

local function updateWaterPitch(m: Mario)
	local gfxAngle = m.GfxAngle

	if gfxAngle.X > 0 then
		local angle = 60 * Util.Sins(gfxAngle.X) * Util.Sins(gfxAngle.X)
		m.GfxPos += Vector3.new(0, angle, 0)
	end

	if gfxAngle.X < 0 then
		local x = gfxAngle.X * 6 / 10
		gfxAngle = Util.SetX(gfxAngle, x)
	end

	if gfxAngle.X > 0 then
		local x = gfxAngle.X * 10 / 8
		gfxAngle = Util.SetX(gfxAngle, x)
	end

	m.GfxAngle = gfxAngle
end

local function stationarySlowDown(m: Mario)
	local buoyancy = getBuoyancy(m)
	m.AngleVel *= Vector3int16.new(0, 0, 1)
	m.ForwardVel = Util.ApproachFloat(m.ForwardVel, 0, 1, 1)

	local faceY = m.FaceAngle.Y
	local faceX = Util.ApproachInt(m.FaceAngle.X, 0, 0x200, 0x200)
	local faceZ = Util.ApproachInt(m.FaceAngle.Z, 0, 0x100, 0x100)

	local velY = Util.ApproachFloat(m.Velocity.Y, buoyancy, 2, 1)
	local velX = m.ForwardVel * Util.Coss(faceX) * Util.Sins(faceY)
	local velZ = m.ForwardVel * Util.Coss(faceX) * Util.Coss(faceY)

	m.FaceAngle = Vector3int16.new(faceX, faceY, faceZ)
	m.Velocity = Vector3.new(velX, velY, velZ)
end

local function updateSwimmingSpeed(m: Mario, maybeDecelThreshold: number?)
	local buoyancy = getBuoyancy(m)
	local decelThreshold = maybeDecelThreshold or MIN_SWIM_SPEED

	if m.Action:Has(ActionFlags.STATIONARY) then
		m.ForwardVel -= 2
	end

	m.ForwardVel = math.clamp(m.ForwardVel, 0, 28)

	if m.ForwardVel > decelThreshold then
		m.ForwardVel -= 0.5
	end

	m.Velocity = Vector3.new(
		m.ForwardVel * Util.Coss(m.FaceAngle.X) * Util.Sins(m.FaceAngle.Y),
		m.ForwardVel * Util.Sins(m.FaceAngle.X) + buoyancy,
		m.ForwardVel * Util.Coss(m.FaceAngle.X) * Util.Coss(m.FaceAngle.Y)
	)
end

local function updateSwimmingYaw(m: Mario)
	local targetYawVel = -Util.SignedShort(10 * m.Controller.StickX)

	if targetYawVel > 0 then
		if m.AngleVel.Y < 0 then
			m.AngleVel += Vector3int16.new(0, 0x40, 0)

			if m.AngleVel.Y > 0x10 then
				m.AngleVel = Util.SetY(m.AngleVel, 0x10)
			end
		else
			local velY = Util.ApproachInt(m.AngleVel.Y, targetYawVel, 0x10, 0x20)
			m.AngleVel = Util.SetY(m.AngleVel, velY)
		end
	elseif targetYawVel < 0 then
		if m.AngleVel.Y > 0 then
			m.AngleVel -= Vector3int16.new(0, 0x40, 0)

			if m.AngleVel.Y < -0x10 then
				m.AngleVel = Util.SetY(m.AngleVel, -0x10)
			end
		else
			local velY = Util.ApproachInt(m.AngleVel.Y, targetYawVel, 0x20, 0x10)
			m.AngleVel = Util.SetY(m.AngleVel, velY)
		end
	else
		local velY = Util.ApproachInt(m.AngleVel.Y, 0, 0x40, 0x40)
		m.AngleVel = Util.SetY(m.AngleVel, velY)
	end

	m.FaceAngle += Vector3int16.new(0, m.AngleVel.Y, 0)
	m.FaceAngle = Util.SetZ(m.FaceAngle, -m.AngleVel.Y * 8)
end

local function updateSwimmingPitch(m: Mario)
	local targetPitch = -Util.SignedShort(252 * m.Controller.StickY)
	
	-- stylua: ignore
	local pitchVel = if m.FaceAngle.X < 0
		then 0x100
		else 0x200

	if m.FaceAngle.X < targetPitch then
		m.FaceAngle += Vector3int16.new(pitchVel, 0, 0)

		if m.FaceAngle.X > targetPitch then
			m.FaceAngle = Util.SetX(m.FaceAngle, targetPitch)
		end
	elseif m.FaceAngle.X > targetPitch then
		m.FaceAngle -= Vector3int16.new(pitchVel, 0, 0)

		if m.FaceAngle.X < targetPitch then
			m.FaceAngle = Util.SetX(m.FaceAngle, targetPitch)
		end
	end
end

local function commonIdleStep(m: Mario, anim: Animation, maybeAccel: number?)
	local accel = maybeAccel or 0
	local bodyState = m.BodyState
	local headAngleX = bodyState.HeadAngle.X

	updateSwimmingYaw(m)
	updateSwimmingPitch(m)
	updateSwimmingSpeed(m)
	performWaterStep(m)
	updateWaterPitch(m)

	if m.FaceAngle.X > 0 then
		headAngleX = Util.ApproachInt(headAngleX, m.FaceAngle.X / 2, 0x80, 0x200)
	else
		headAngleX = Util.ApproachInt(headAngleX, 0, 0x200, 0x200)
	end

	if accel == 0 then
		m:SetAnimation(anim)
	else
		m:SetAnimationWithAccel(anim, accel)
	end

	setSwimmingAtSurfaceParticles(m, ParticleFlags.IDLE_WATER_WAVE)
end

local function resetBobVariables(m: Mario)
	sBobTimer = 0
	sBobIncrement = 0x800
	sBobHeight = m.FaceAngle.X / 256 + 20
end

local function surfaceSwimBob(m: Mario)
	if sBobIncrement ~= 0 and m.Position.Y > m.WaterLevel - 85 and m.FaceAngle.Y >= 0 then
		sBobTimer += sBobIncrement

		if sBobTimer >= 0 then
			m.GfxPos += Vector3.new(0, sBobHeight * Util.Sins(sBobTimer), 0)
			return
		end
	end

	sBobIncrement = 0
end

local function commonSwimmingStep(m: Mario, swimStrength: number)
	local waterStep
	updateSwimmingYaw(m)
	updateSwimmingPitch(m)
	updateSwimmingSpeed(m, swimStrength / 10)

	-- do water step
	waterStep = performWaterStep(m)

	if waterStep == WaterStep.HIT_FLOOR then
		local floorPitch = -m:FindFloorSlope(-0x8000)

		if m.FaceAngle.X < floorPitch then
			m.FaceAngle = Util.SetX(m.FaceAngle, floorPitch)
		end
	elseif waterStep == WaterStep.HIT_CEILING then
		if m.FaceAngle.Y > -0x3000 then
			m.FaceAngle -= Vector3int16.new(0, 0x100, 0)
		end
	elseif waterStep == WaterStep.HIT_WALL then
		if m.Controller.StickY == 0 then
			if m.FaceAngle.X > 0 then
				m.FaceAngle += Vector3int16.new(0x200, 0, 0)

				if m.FaceAngle.X > 0x3F00 then
					m.FaceAngle = Util.SetX(m.FaceAngle, 0x3F00)
				end
			else
				m.FaceAngle -= Vector3int16.new(0x200, 0, 0)

				if m.FaceAngle.X < -0x3F00 then
					m.FaceAngle = Util.SetX(m.FaceAngle, -0x3F00)
				end
			end
		end
	end

	local headAngle = m.BodyState.HeadAngle
	updateWaterPitch(m)

	local angleX = Util.ApproachInt(headAngle.X, 0, 0x200, 0x200)
	m.BodyState.HeadAngle = Util.SetX(headAngle, angleX)

	surfaceSwimBob(m)
	setSwimmingAtSurfaceParticles(m, ParticleFlags.WAVE_TRAIL)
end

local function playSwimmingNoise(m: Mario)
	local animFrame = m.AnimFrame

	if animFrame == 0 or animFrame == 12 then
		m:PlaySound(Sounds.ACTION_SWIM_KICK)
	end
end

local function checkWaterJump(m: Mario)
	local probe = Util.SignedInt(m.Position.Y + 1.5)

	if m.Input:Has(InputFlags.A_PRESSED) then
		if probe >= m.WaterLevel - 80 and m.FaceAngle.X >= 0 and m.Controller.StickY < -60 then
			m.AngleVel = Vector3int16.new()
			m.Velocity = Util.SetY(m.Velocity, 62)

			return m:SetAction(Action.WATER_JUMP)
		end
	end

	return false
end

local function playMetalWaterJumpingSound(m: Mario, landing: boolean)
	if not m.Flags:Has(MarioFlags.ACTION_SOUND_PLAYED) then
		m.ParticleFlags:Add(ParticleFlags.MIST_CIRCLE)
	end

	m:PlaySoundIfNoFlag(
		landing and Sounds.ACTION_METAL_LAND_WATER or Sounds.ACTION_METAL_JUMP_WATER,
		MarioFlags.ACTION_SOUND_PLAYED
	)
end

local function playMetalWaterWalkingSound(m: Mario)
	if m:IsAnimPastFrame(10) or m:IsAnimPastFrame(49) then
		m:PlaySound(Sounds.ACTION_METAL_STEP_WATER)
		m.ParticleFlags:Add(ParticleFlags.DUST)
	end
end

local function updateMetalWaterWalkingSpeed(m: Mario)
	local val = m.IntendedMag / 1.5
	local floor = m.Floor

	if m.ForwardVel <= 0 then
		m.ForwardVel += 1.1
	elseif m.ForwardVel <= val then
		m.ForwardVel += 1.1 - m.ForwardVel / 43
	elseif floor and floor.Normal.Y >= 0.95 then
		m.ForwardVel -= 1
	end

	if m.ForwardVel > 32 then
		m.ForwardVel = 32
	end

	local faceY = m.IntendedYaw - Util.ApproachInt(Util.SignedShort(m.IntendedYaw - m.FaceAngle.Y), 0, 0x800, 0x800)
	m.FaceAngle = Util.SetY(m.FaceAngle, faceY)

	m.SlideVelX = m.ForwardVel * Util.Sins(faceY)
	m.SlideVelZ = m.ForwardVel * Util.Coss(faceY)

	m.Velocity = Vector3.new(m.SlideVelX, 0, m.SlideVelZ)
end

local function updateMetalWaterJumpSpeed(m: Mario)
	local waterSurface = m.WaterLevel - 100

	if m.Velocity.Y > 0 and m.Position.Y > waterSurface then
		return true
	end

	if m.Input:Has(InputFlags.NONZERO_ANALOG) then
		local intendedDYaw = Util.SignedShort(m.IntendedYaw - m.FaceAngle.Y)
		m.ForwardVel += 0.8 * Util.Coss(intendedDYaw)
		m.FaceAngle += Vector3int16.new(0, 0x200 * Util.Sins(intendedDYaw), 0)
	else
		m.ForwardVel = Util.ApproachFloat(m.ForwardVel, 0, 0.25, 0.25)
	end

	if m.ForwardVel > 16 then
		m.ForwardVel -= 1
	end

	if m.ForwardVel < 0 then
		m.ForwardVel += 2
	end

	local velY = m.Velocity.Y
	local velX = m.ForwardVel * Util.Sins(m.FaceAngle.Y)
	local velZ = m.ForwardVel * Util.Coss(m.FaceAngle.Y)

	m.SlideVelX = velX
	m.SlideVelZ = velZ
	m.Velocity = Vector3.new(velX, velY, velZ)

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local DEF_ACTION: (number, (Mario) -> boolean) -> () = System.RegisterAction

DEF_ACTION(Action.WATER_IDLE, function(m: Mario)
	local val = 0x10000

	if m.Flags:Has(MarioFlags.METAL_CAP) then
		return m:SetAction(Action.METAL_WATER_FALLING, 1)
	end

	if m.Input:Has(InputFlags.B_PRESSED) then
		return m:SetAction(Action.WATER_PUNCH)
	end

	if m.Input:Has(InputFlags.A_PRESSED) then
		return m:SetAction(Action.BREASTSTROKE)
	end

	if m.FaceAngle.X < -0x1000 then
		val = 0x30000
	end

	commonIdleStep(m, Animations.WATER_IDLE, val)
	return false
end)

DEF_ACTION(Action.WATER_ACTION_END, function(m: Mario)
	if m.Flags:Has(MarioFlags.METAL_CAP) then
		return m:SetAction(Action.METAL_WATER_FALLING, 1)
	end

	if m.Input:Has(InputFlags.B_PRESSED) then
		return m:SetAction(Action.WATER_PUNCH)
	end

	if m.Input:Has(InputFlags.A_PRESSED) then
		return m:SetAction(Action.BREASTSTROKE)
	end

	commonIdleStep(m, Animations.WATER_ACTION_END)

	if m:IsAnimAtEnd() then
		m:SetAction(Action.WATER_IDLE)
	end

	return false
end)

DEF_ACTION(Action.BREASTSTROKE, function(m: Mario)
	if m.ActionArg == 0 then
		sSwimStrength = MIN_SWIM_STRENGTH
	end

	if m.Flags:Has(MarioFlags.METAL_CAP) then
		return m:SetAction(Action.METAL_WATER_FALLING, 1)
	end

	if m.Input:Has(InputFlags.B_PRESSED) then
		return m:SetAction(Action.WATER_PUNCH)
	end

	m.ActionTimer += 1

	if m.ActionTimer == 14 then
		return m:SetAction(Action.FLUTTER_KICK)
	end

	if checkWaterJump(m) then
		return true
	end

	if m.ActionTimer < 6 then
		m.ForwardVel += 0.5
	end

	if m.ActionTimer >= 9 then
		m.ForwardVel += 1.5
	end

	if m.ActionTimer >= 2 then
		if m.ActionTimer < 6 and m.Input:Has(InputFlags.A_PRESSED) then
			m.ActionState = 1
		end

		if m.ActionTimer == 9 and m.ActionState == 1 then
			m:SetAnimToFrame(0)
			m.ActionState = 0
			m.ActionTimer = 1
			sSwimStrength = MIN_SWIM_STRENGTH
		end
	end

	if m.ActionTimer == 1 then
		m:PlaySound(sSwimStrength == MIN_SWIM_STRENGTH and Sounds.ACTION_SWIM or Sounds.ACTION_SWIM_FAST)
		resetBobVariables(m)
	end

	m:SetAnimation(Animations.SWIM_PART1)
	commonSwimmingStep(m, sSwimStrength)

	return false
end)

DEF_ACTION(Action.SWIMMING_END, function(m: Mario)
	if m.Flags:Has(MarioFlags.METAL_CAP) then
		return m:SetAction(Action.METAL_WATER_FALLING, 1)
	end

	if m.Input:Has(InputFlags.B_PRESSED) then
		return m:SetAction(Action.WATER_PUNCH)
	end

	if m.ActionTimer >= 15 then
		return m:SetAction(Action.WATER_ACTION_END)
	end

	if checkWaterJump(m) then
		return true
	end

	if m.Input:Has(InputFlags.A_DOWN) and m.ActionTimer >= 7 then
		if m.ActionTimer == 7 and sSwimStrength < 280 then
			sSwimStrength += 10
		end

		return m:SetAction(Action.BREASTSTROKE, 1)
	end

	if m.ActionTimer >= 7 then
		sSwimStrength = MIN_SWIM_STRENGTH
	end

	m.ActionTimer += 1
	m.ForwardVel -= 0.25

	m:SetAnimation(Animations.SWIM_PART2)
	commonSwimmingStep(m, sSwimStrength)

	return false
end)

DEF_ACTION(Action.FLUTTER_KICK, function(m: Mario)
	if m.Flags:Has(MarioFlags.METAL_CAP) then
		return m:SetAction(Action.METAL_WATER_FALLING, 1)
	end

	if m.Input:Has(InputFlags.B_PRESSED) then
		return m:SetAction(Action.WATER_PUNCH)
	end

	if not m.Input:Has(InputFlags.A_DOWN) then
		if m.ActionTimer == 0 and sSwimStrength < 280 then
			sSwimStrength += 10
		end

		return m:SetAction(Action.SWIMMING_END)
	end

	m.ForwardVel = Util.ApproachFloat(m.ForwardVel, 12, 0.1, 0.15)
	m.ActionTimer = 1
	sSwimStrength = MIN_SWIM_STRENGTH

	if m.ForwardVel < 14 then
		playSwimmingNoise(m)
		m:SetAnimation(Animations.FLUTTERKICK)
	end

	commonSwimmingStep(m, sSwimStrength)
	return false
end)

DEF_ACTION(Action.WATER_PUNCH, function(m: Mario)
	if m.ForwardVel < 7 then
		m.ForwardVel += 1
	end

	updateSwimmingYaw(m)
	updateSwimmingPitch(m)
	updateSwimmingSpeed(m)
	performWaterStep(m)
	updateWaterPitch(m)

	local headAngle = m.BodyState.HeadAngle
	local angleX = Util.ApproachInt(headAngle.X, 0, 0x200, 0x200)

	m.BodyState.HeadAngle = Util.SetX(headAngle, angleX)
	m:PlaySoundIfNoFlag(Sounds.ACTION_SWIM, MarioFlags.ACTION_SOUND_PLAYED)

	if m.ActionState == 0 then
		m:SetAnimation(Animations.WATER_GRAB_OBJ_PART1)

		if m:IsAnimAtEnd() then
			m.ActionState = 1
		end
	elseif m.ActionState == 1 then
		m:SetAnimation(Animations.WATER_GRAB_OBJ_PART2)

		if m:IsAnimAtEnd() then
			m:SetAction(Action.WATER_ACTION_END)
		end
	end

	return false
end)

DEF_ACTION(Action.WATER_PLUNGE, function(m: Mario)
	local stepResult
	local endVSpeed = swimmingNearSurface(m) and 0 or -5

	local hasMetalCap = m.Flags:Has(MarioFlags.METAL_CAP)
	local isDiving = m.PrevAction:Has(ActionFlags.DIVING) or m.Input:Has(InputFlags.A_DOWN)

	m.ActionTimer += 1
	stationarySlowDown(m)
	stepResult = performWaterStep(m)

	if m.ActionState == 0 then
		m:PlaySound(Sounds.ACTION_WATER_ENTER)

		if m.PeakHeight - m.Position.Y > 1150 then
			m:PlaySound(Sounds.MARIO_HAHA)
		end

		m.ParticleFlags:Add(ParticleFlags.WATER_SPLASH)
		m.ActionState = 1
	end

	if stepResult == WaterStep.HIT_FLOOR or m.Velocity.Y >= endVSpeed or m.ActionTimer > 20 then
		if hasMetalCap then
			m:SetAction(Action.METAL_WATER_FALLING)
		elseif isDiving then
			m:SetAction(Action.FLUTTER_KICK)
		else
			m:SetAction(Action.WATER_ACTION_END)
		end

		sBobIncrement = 0
	end

	if hasMetalCap then
		m:SetAnimation(Animations.GENERAL_FALL)
	elseif isDiving then
		m:SetAnimation(Animations.FLUTTERKICK)
	else
		m:SetAnimation(Animations.WATER_ACTION_END)
	end

	m.Flags:Add(ParticleFlags.PLUNGE_BUBBLE)
	return false
end)

DEF_ACTION(Action.METAL_WATER_STANDING, function(m: Mario)
	if not m.Flags:Has(MarioFlags.METAL_CAP) then
		return m:SetAction(Action.WATER_IDLE)
	end

	if m.Input:Has(InputFlags.A_PRESSED) then
		return m:SetAction(Action.METAL_WATER_JUMP)
	end

	if m.Input:Has(InputFlags.NONZERO_ANALOG) then
		return m:SetAction(Action.METAL_WATER_WALKING)
	end

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
			m.ActionState = 0
		end
	end

	m:StopAndSetHeightToFloor()

	if m.Position.Y >= m.WaterLevel - 150 then
		m.ParticleFlags:Add(ParticleFlags.IDLE_WATER_WAVE)
	end

	return false
end)

DEF_ACTION(Action.METAL_WATER_WALKING, function(m: Mario)
	if not m.Flags:Has(MarioFlags.METAL_CAP) then
		return m:SetAction(Action.WATER_IDLE)
	end

	if m.Input:Has(InputFlags.A_PRESSED) then
		return m:SetAction(Action.METAL_WATER_JUMP)
	end

	if m.Input:Has(InputFlags.NO_MOVEMENT) then
		return m:SetAction(Action.METAL_WATER_STANDING)
	end

	local accel = Util.SignedInt(m.ForwardVel / 4 * 0x10000)
	local groundStep

	if accel < 0x1000 then
		accel = 0x1000
	end

	m:SetAnimationWithAccel(Animations.WALKING, accel)
	playMetalWaterWalkingSound(m)
	updateMetalWaterWalkingSpeed(m)
	groundStep = m:PerformGroundStep()

	if groundStep == GroundStep.LEFT_GROUND then
		m:SetAction(Action.METAL_WATER_FALLING, 1)
	elseif groundStep == GroundStep.HIT_WALL then
		m.ForwardVel = 0
	end

	return false
end)

DEF_ACTION(Action.METAL_WATER_JUMP, function(m: Mario)
	local airStep

	if not m.Flags:Has(MarioFlags.METAL_CAP) then
		return m:SetAction(Action.WATER_IDLE)
	end

	if updateMetalWaterJumpSpeed(m) then
		return m:SetAction(Action.WATER_JUMP, 1)
	end

	playMetalWaterJumpingSound(m, false)
	m:SetAnimation(Animations.SINGLE_JUMP)
	airStep = m:PerformAirStep()

	if airStep == AirStep.LANDED then
		m:SetAction(Action.METAL_WATER_JUMP_LAND)
	elseif airStep == AirStep.HIT_WALL then
		m.ForwardVel = 0
	end

	return false
end)

DEF_ACTION(Action.METAL_WATER_FALLING, function(m: Mario)
	if not m.Flags:Has(MarioFlags.METAL_CAP) then
		return m:SetAction(Action.WATER_IDLE)
	end

	if m.Input:Has(InputFlags.NONZERO_ANALOG) then
		m.FaceAngle += Vector3int16.new(0, 0x400 * Util.Sins(m.IntendedYaw - m.FaceAngle.Y), 0)
	end

	m:SetAnimation(m.ActionArg == 0 and Animations.GENERAL_FALL or Animations.FALL_FROM_WATER)
	stationarySlowDown(m)

	if bit32.btest(performWaterStep(m), WaterStep.HIT_FLOOR) then
		m:SetAction(Action.METAL_WATER_FALL_LAND)
	end

	return false
end)

DEF_ACTION(Action.METAL_WATER_JUMP_LAND, function(m: Mario)
	playMetalWaterJumpingSound(m, true)

	if not m.Flags:Has(MarioFlags.METAL_CAP) then
		return m:SetAction(Action.WATER_IDLE)
	end

	if m.Input:Has(InputFlags.NONZERO_ANALOG) then
		return m:SetAction(Action.METAL_WATER_WALKING)
	end

	m:StopAndSetHeightToFloor()
	m:SetAnimation(Animations.LAND_FROM_SINGLE_JUMP)

	if m:IsAnimAtEnd() then
		return m:SetAction(Action.METAL_WATER_STANDING)
	end

	return false
end)

DEF_ACTION(Action.METAL_WATER_FALL_LAND, function(m: Mario)
	playMetalWaterJumpingSound(m, true)

	if not m.Flags:Has(MarioFlags.METAL_CAP) then
		return m:SetAction(Action.WATER_IDLE)
	end

	if m.Input:Has(InputFlags.NONZERO_ANALOG) then
		return m:SetAction(Action.METAL_WATER_WALKING)
	end

	m:StopAndSetHeightToFloor()
	m:SetAnimation(Animations.GENERAL_LAND)

	if m:IsAnimAtEnd() then
		return m:SetAction(Action.METAL_WATER_STANDING)
	end

	return false
end)
