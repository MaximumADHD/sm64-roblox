--!strict

local System = require(script.Parent)
local Animations = System.Animations
local Sounds = System.Sounds
local Enums = System.Enums
local Util = System.Util

local Action = Enums.Action
local ActionFlags = Enums.ActionFlags
local ActionGroup = Enums.ActionGroups

local MarioEyes = Enums.MarioEyes
local GroundStep = Enums.GroundStep
local InputFlags = Enums.InputFlags
local MarioFlags = Enums.MarioFlags
local SurfaceClass = Enums.SurfaceClass
local ParticleFlags = Enums.ParticleFlags

type Mario = System.Mario

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Landing Actions
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

type LandingAction = {
	NumFrames: number,
	JumpTimer: number,
	EndAction: number,
	APressedAction: number,
}

local sJumpLandAction: LandingAction = {
	NumFrames = 4,
	JumpTimer = 5,

	EndAction = Action.JUMP_LAND_STOP,
	APressedAction = Action.DOUBLE_JUMP,
}

local sFreefallLandAction: LandingAction = {
	NumFrames = 4,
	JumpTimer = 5,

	EndAction = Action.FREEFALL_LAND_STOP,
	APressedAction = Action.DOUBLE_JUMP,
}

local sSideFlipLandAction: LandingAction = {
	NumFrames = 4,
	JumpTimer = 5,

	EndAction = Action.SIDE_FLIP_LAND_STOP,
	APressedAction = Action.DOUBLE_JUMP,
}

local sLongJumpLandAction: LandingAction = {
	NumFrames = 6,
	JumpTimer = 5,

	EndAction = Action.LONG_JUMP_LAND_STOP,
	APressedAction = Action.LONG_JUMP,
}

local sDoubleJumpLandAction: LandingAction = {
	NumFrames = 4,
	JumpTimer = 5,

	EndAction = Action.DOUBLE_JUMP_LAND_STOP,
	APressedAction = Action.JUMP,
}

local sTripleJumpLandAction: LandingAction = {
	NumFrames = 4,
	JumpTimer = 0,

	EndAction = Action.TRIPLE_JUMP_LAND_STOP,
	APressedAction = Action.UNINITIALIZED,
}

local sBackflipLandAction: LandingAction = {
	NumFrames = 4,
	JumpTimer = 0,

	EndAction = Action.BACKFLIP_LAND_STOP,
	APressedAction = Action.BACKFLIP,
}

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local DEF_ACTION: (number, (Mario) -> boolean) -> () = System.RegisterAction
local sPunchingForwardVelocities = { 0, 1, 1, 2, 3, 5, 7, 10 }

local function tiltBodyRunning(m: Mario)
	local pitch = m:FindFloorSlope(0)
	pitch = pitch * m.ForwardVel / 40

	return -pitch
end

local function playStepSound(m: Mario, frame1: number, frame2: number)
	if m:IsAnimPastFrame(frame1) or m:IsAnimPastFrame(frame2) then
		if m.Flags:Has(MarioFlags.METAL_CAP) then
			m:PlaySoundAndSpawnParticles(Sounds.ACTION_METAL_STEP, 0)
		else
			m:PlaySoundAndSpawnParticles(Sounds.ACTION_TERRAIN_STEP, 0)
		end
	end
end

local function alignWithFloor(m: Mario)
	local pos = Util.SetY(m.Position, m.FloorHeight)
	m.Position = pos

	local radius = 40
	local minY = -radius * 3
	local yaw = m.FaceAngle.Y

	local p0_x = pos.X + radius * Util.Sins(yaw + 0x2AAA)
	local p0_z = pos.Z + radius * Util.Coss(yaw + 0x2AAA)

	local p1_x = pos.X + radius * Util.Sins(yaw + 0x8000)
	local p1_z = pos.Z + radius * Util.Coss(yaw + 0x8000)

	local p2_x = pos.X + radius * Util.Sins(yaw + 0xD555)
	local p2_z = pos.Z + radius * Util.Coss(yaw + 0xD555)

	local test0 = Vector3.new(p0_x, pos.Y + 150, p0_z)
	local test1 = Vector3.new(p1_x, pos.Y + 150, p1_z)
	local test2 = Vector3.new(p2_x, pos.Y + 150, p2_z)

	local p0_y = Util.FindFloor(test0)
	local p1_y = Util.FindFloor(test1)
	local p2_y = Util.FindFloor(test2)

	p0_y = p0_y - pos.Y < minY and pos.Y or p0_y
	p1_y = p1_y - pos.Y < minY and pos.Y or p1_y
	p2_y = p2_y - pos.Y < minY and pos.Y or p2_y

	local avgY = (p0_y + p1_y + p2_y) / 3
	local forward = Vector3.new(Util.Sins(yaw), 0, Util.Coss(yaw))

	if avgY >= pos.Y then
		pos = Util.SetY(pos, avgY)
	end

	local a = Vector3.new(p0_x, p0_y, p0_z)
	local b = Vector3.new(p1_x, p1_y, p1_z)
	local c = Vector3.new(p2_x, p2_y, p2_z)

	local yColumn = (b - a):Cross(c - a).Unit
	local xColumn = yColumn:Cross(forward).Unit
	m.ThrowMatrix = CFrame.fromMatrix(pos, xColumn, yColumn)
end

local function beginWalkingAction(m: Mario, forwardVel: number, action: number, actionArg: number?)
	m:SetForwardVel(forwardVel)
	m.FaceAngle = Util.SetYint16(m.FaceAngle, m.IntendedYaw)
	return m:SetAction(action, actionArg)
end

local function checkLedgeClimbDown(m: Mario)
	if m.ForwardVel < 10 then
		local pos, wall = Util.FindWallCollisions(m.Position, -10, 10)

		if wall then
			local floorHeight, floor = Util.FindFloor(pos)

			if floor and pos.Y - floorHeight > 160 then
				local wallAngle = Util.Atan2s(wall.Normal.Z, wall.Normal.X)
				local wallDYaw = wallAngle - m.FaceAngle.Y

				if math.abs(wallDYaw) < 0x4000 then
					pos -= Vector3.new(20 * wall.Normal.X, 0, 20 * wall.Normal.Z)
					m.Position = pos

					m.FaceAngle *= Vector3int16.new(0, 1, 1)
					m.FaceAngle = Util.SetYint16(m.FaceAngle, wallAngle + 0x8000)

					m:SetAction(Action.LEDGE_CLIMB_DOWN)
					m:SetAnimation(Animations.CLIMB_DOWN_LEDGE)
				end
			end
		end
	end
end

local function slideBonk(m: Mario, fastAction: number, slowAction: number)
	if m.ForwardVel > 16 then
		m:BonkReflection(true)
		m:SetAction(fastAction)
	else
		m:SetForwardVel(0)
		m:SetAction(slowAction)
	end
end

local function setTripleJumpAction(m: Mario)
	if m.Flags:Has(MarioFlags.WING_CAP) then
		return m:SetAction(Action.FLYING_TRIPLE_JUMP)
	elseif m.ForwardVel > 20 then
		return m:SetAction(Action.TRIPLE_JUMP)
	else
		return m:SetAction(Action.JUMP)
	end
end

local function updateSlidingAngle(m: Mario, accel: number, lossFactor: number)
	local newFacingDYaw
	local facingDYaw

	local floor = m.Floor

	if not floor then
		return
	end

	assert(floor)

	local slopeAngle = Util.Atan2s(floor.Normal.Z, floor.Normal.X)
	local steepness = math.sqrt(floor.Normal.X ^ 2 + floor.Normal.Z ^ 2)

	m.SlideVelX += accel * steepness * Util.Sins(slopeAngle)
	m.SlideVelZ += accel * steepness * Util.Coss(slopeAngle)

	m.SlideVelX *= lossFactor
	m.SlideVelZ *= lossFactor

	m.SlideYaw = Util.Atan2s(m.SlideVelZ, m.SlideVelX)

	facingDYaw = m.FaceAngle.Y - m.SlideYaw
	newFacingDYaw = facingDYaw

	if newFacingDYaw > 0 and newFacingDYaw <= 0x4000 then
		newFacingDYaw -= 0x200

		if newFacingDYaw < 0 then
			newFacingDYaw = 0
		end
	elseif newFacingDYaw > -0x4000 and newFacingDYaw < 0 then
		newFacingDYaw += 0x200

		if newFacingDYaw > 0 then
			newFacingDYaw = 0
		end
	elseif newFacingDYaw > 0x4000 and newFacingDYaw < 0x8000 then
		newFacingDYaw += 0x200

		if newFacingDYaw > 0x8000 then
			newFacingDYaw = 0x8000
		end
	elseif newFacingDYaw > -0x8000 and newFacingDYaw < -0x4000 then
		newFacingDYaw -= 0x200

		if newFacingDYaw < -0x8000 then
			newFacingDYaw = -0x8000
		end
	end

	m.FaceAngle = Util.SetYint16(m.FaceAngle, m.SlideYaw + newFacingDYaw)
	m.Velocity = Vector3.new(m.SlideVelX, 0, m.SlideVelZ)

	--! Speed is capped a frame late (butt slide HSG)
	m.ForwardVel = math.sqrt(m.SlideVelX ^ 2 + m.SlideVelZ ^ 2)

	if m.ForwardVel > 100 then
		m.SlideVelX = m.SlideVelX * 100 / m.ForwardVel
		m.SlideVelZ = m.SlideVelZ * 100 / m.ForwardVel
	end

	if newFacingDYaw < -0x4000 or newFacingDYaw > 0x4000 then
		m.ForwardVel *= -1
	end
end

local function updateSliding(m: Mario, stopSpeed: number)
	local intendedDYaw = m.IntendedYaw - m.SlideYaw
	local forward = Util.Coss(intendedDYaw)
	local sideward = Util.Sins(intendedDYaw)

	--! 10k glitch
	if forward < 0 and m.ForwardVel > 0 then
		forward *= 0.5 + 0.5 * m.ForwardVel / 100
	end

	local floorClass = m:GetFloorClass()
	local lossFactor
	local accel

	if floorClass == SurfaceClass.VERY_SLIPPERY then
		accel = 10
		lossFactor = m.IntendedMag / 32 * forward * 0.02 + 0.98
	elseif floorClass == SurfaceClass.SLIPPERY then
		accel = 8
		lossFactor = m.IntendedMag / 32 * forward * 0.02 + 0.96
	elseif floorClass == SurfaceClass.DEFAULT then
		accel = 7
		lossFactor = m.IntendedMag / 32 * forward * 0.02 + 0.92
	elseif floorClass == SurfaceClass.NOT_SLIPPERY then
		accel = 5
		lossFactor = m.IntendedMag / 32 * forward * 0.02 + 0.92
	end

	local oldSpeed = math.sqrt(m.SlideVelX ^ 2 + m.SlideVelZ ^ 2)

	--! This is attempting to use trig derivatives to rotate Mario's speed.
	--  It is slightly off/asymmetric since it uses the new X speed, but the old
	--  Z speed.

	m.SlideVelX += m.SlideVelZ * (m.IntendedMag / 32) * sideward * 0.05
	m.SlideVelZ -= m.SlideVelX * (m.IntendedMag / 32) * sideward * 0.05

	local newSpeed = math.sqrt(m.SlideVelX ^ 2 + m.SlideVelZ ^ 2)

	if oldSpeed > 0 and newSpeed > 0 then
		m.SlideVelX *= oldSpeed / newSpeed
		m.SlideVelZ *= oldSpeed / newSpeed
	end

	local stopped = false
	updateSlidingAngle(m, accel, lossFactor)

	if not m:FloorIsSlope() and m.ForwardVel ^ 2 < stopSpeed ^ 2 then
		m:SetForwardVel(0)
		stopped = true
	end

	return stopped
end

local function applySlopeAccel(m: Mario)
	local floor = m.Floor
	local floorNormal: Vector3

	if floor then
		floorNormal = floor.Normal
	else
		floorNormal = Vector3.yAxis
	end

	local floorDYaw = m.FloorAngle - m.FaceAngle.Y
	local steepness = math.sqrt(floorNormal.X ^ 2 + floorNormal.Z ^ 2)

	if m:FloorIsSlope() then
		local slopeClass = 0
		local slopeAccel

		if m.Action() ~= Action.SOFT_BACKWARD_GROUND_KB then
			if m.Action() ~= Action.SOFT_FORWARD_GROUND_KB then
				slopeClass = m:GetFloorClass()
			end
		end

		if slopeClass == SurfaceClass.VERY_SLIPPERY then
			slopeAccel = 5.3
		elseif slopeClass == SurfaceClass.SLIPPERY then
			slopeAccel = 2.7
		elseif slopeClass == SurfaceClass.DEFAULT then
			slopeAccel = 1.7
		else
			slopeAccel = 0
		end

		if floorDYaw > -0x4000 and floorDYaw < 0x4000 then
			m.ForwardVel += slopeAccel * steepness
		else
			m.ForwardVel -= slopeAccel * steepness
		end
	end

	m.SlideYaw = m.FaceAngle.Y
	m.SlideVelX = m.ForwardVel * Util.Sins(m.FaceAngle.Y)
	m.SlideVelZ = m.ForwardVel * Util.Coss(m.FaceAngle.Y)
	m.Velocity = Vector3.new(m.SlideVelX, 0, m.SlideVelZ)
end

local function applyLandingAccel(m: Mario, frictionFactor: number)
	local stopped = false
	applySlopeAccel(m)

	if not m:FloorIsSlope() then
		m.ForwardVel *= frictionFactor

		if m.ForwardVel ^ 2 < 1 then
			m:SetForwardVel(0)
			stopped = true
		end
	end

	return stopped
end

local function applySlopeDecel(m: Mario, decelCoef: number)
	local decel
	local stopped = false
	local floorClass = m:GetFloorClass()

	if floorClass == SurfaceClass.VERY_SLIPPERY then
		decel = decelCoef * 0.2
	elseif floorClass == SurfaceClass.SLIPPERY then
		decel = decelCoef * 0.7
	elseif floorClass == SurfaceClass.DEFAULT then
		decel = decelCoef * 2
	elseif floorClass == SurfaceClass.NOT_SLIPPERY then
		decel = decelCoef * 3
	end

	m.ForwardVel = Util.ApproachFloat(m.ForwardVel, 0, decel)

	if m.ForwardVel == 0 then
		stopped = true
	end

	applySlopeAccel(m)
	return stopped
end

local function updateDeceleratingSpeed(m: Mario)
	local stopped = false
	m.ForwardVel = Util.ApproachFloat(m.ForwardVel, 0, 1)

	if m.ForwardVel == 0 then
		stopped = true
	end

	m:SetForwardVel(m.ForwardVel)
	return stopped
end

local function updateWalkingSpeed(m: Mario)
	local maxTargetSpeed = 32
	local floor = m.Floor

	local targetSpeed = if m.IntendedMag < maxTargetSpeed then m.IntendedMag else maxTargetSpeed

	if m.ForwardVel < 0 then
		m.ForwardVel += 1.1
	elseif m.ForwardVel <= targetSpeed then
		m.ForwardVel += 1.1 - m.ForwardVel / 43
	elseif floor and floor.Normal.Y >= 0.95 then
		m.ForwardVel -= 1
	end

	if m.ForwardVel > 48 then
		m.ForwardVel = 48
	end

	local currY = Util.SignedShort(m.IntendedYaw - m.FaceAngle.Y)
	local faceY = m.IntendedYaw - Util.ApproachInt(currY, 0, 0x800)

	m.FaceAngle = Util.SetYint16(m.FaceAngle, faceY)
	applySlopeAccel(m)
end

local function shouldBeginSliding(m: Mario)
	if m.Input:Has(InputFlags.ABOVE_SLIDE) then
		if m.ForwardVel < -1 or m:FacingDownhill() then
			return true
		end
	end

	return false
end

local function analogStickHeldBack(m: Mario)
	local intendedDYaw = Util.SignedShort(m.IntendedYaw - m.FaceAngle.Y)
	return math.abs(intendedDYaw) > 0x471C
end

local function checkGroundDiveOrPunch(m: Mario)
	if m.Input:Has(InputFlags.B_PRESSED) then
		--! Speed kick (shoutouts to SimpleFlips)
		if m.ForwardVel >= 29 and m.Controller.StickMag > 48 then
			m.Velocity = Util.SetY(m.Velocity, 20)
			return m:SetAction(Action.DIVE, 1)
		end

		return m:SetAction(Action.MOVE_PUNCHING)
	end

	return false
end

local function beginBrakingAction(m: Mario)
	if m.ActionState == 1 then
		m.FaceAngle = Util.SetYint16(m.FaceAngle, m.ActionArg)
		return m:SetAction(Action.STANDING_AGAINST_WALL)
	end

	if m.ForwardVel > 16 then
		local floor = m.Floor

		if floor and floor.Normal.Y >= 0.17364818 then
			return m:SetAction(Action.BRAKING)
		end
	end

	return m:SetAction(Action.DECELERATING)
end

local function animAndAudioForWalk(m: Mario)
	local baseAccel = if m.IntendedMag > m.ForwardVel then m.IntendedMag else m.ForwardVel

	if baseAccel < 4 then
		baseAccel = 4
	end

	local targetPitch = 0
	local accel

	while true do
		if m.ActionTimer == 0 then
			if baseAccel > 8 then
				m.ActionTimer = 2
			else
				accel = baseAccel / 4 * 0x10000

				if accel < 0x1000 then
					accel = 0x1000
				end

				m:SetAnimationWithAccel(Animations.START_TIPTOE, accel)
				playStepSound(m, 7, 22)

				if m:IsAnimPastFrame(23) then
					m.ActionTimer = 2
				end

				break
			end
		elseif m.ActionTimer == 1 then
			if baseAccel > 8 then
				m.ActionTimer = 2
			else
				accel = baseAccel * 0x10000

				if accel < 0x1000 then
					accel = 0x1000
				end

				m:SetAnimationWithAccel(Animations.TIPTOE, accel)
				playStepSound(m, 14, 72)

				break
			end
		elseif m.ActionTimer == 2 then
			if baseAccel < 5 then
				m.ActionTimer = 1
			elseif baseAccel > 22 then
				m.ActionTimer = 3
			else
				accel = baseAccel / 4 * 0x10000
				m:SetAnimationWithAccel(Animations.WALKING, accel)
				playStepSound(m, 10, 49)
				break
			end
		elseif m.ActionTimer == 3 then
			if baseAccel < 18 then
				m.ActionTimer = 2
			else
				accel = baseAccel / 4 * 0x10000
				m:SetAnimationWithAccel(Animations.RUNNING, accel)

				playStepSound(m, 9, 45)
				targetPitch = tiltBodyRunning(m)

				break
			end
		end
	end

	local walkingPitch = Util.ApproachInt(m.WalkingPitch, targetPitch, 0x800)
	walkingPitch = Util.SignedShort(walkingPitch)

	m.WalkingPitch = walkingPitch
	m.GfxAngle = Util.SetXint16(m.GfxAngle, walkingPitch)
end

local function pushOrSidleWall(m: Mario, startPos: Vector3)
	local wallAngle: number
	local dWallAngle: number

	local dx = m.Position.X - startPos.X
	local dz = m.Position.Z - startPos.Z

	local movedDist = math.sqrt(dx ^ 2 + dz ^ 2)
	local accel = movedDist * 2 * 0x10000

	if m.ForwardVel > 6 then
		m:SetForwardVel(6)
	end

	local wall = m.Wall

	if wall then
		wallAngle = Util.Atan2s(wall.Normal.Z, wall.Normal.X)
		dWallAngle = Util.SignedShort(assert(wallAngle) - m.FaceAngle.Y)
	end

	if wall == nil or math.abs(dWallAngle) >= 0x71C8 then
		m:SetAnimation(Animations.PUSHING)
		playStepSound(m, 6, 18)
	else
		if dWallAngle < 0 then
			m:SetAnimationWithAccel(Animations.SIDESTEP_RIGHT, accel)
		else
			m:SetAnimationWithAccel(Animations.SIDESTEP_LEFT, accel)
		end

		if m.AnimFrame < 20 then
			m:PlaySound(Sounds.MOVING_TERRAIN_SLIDE)
			m.ParticleFlags:Add(ParticleFlags.DUST)
		end

		m.ActionState = 1
		m.ActionArg = Util.SignedShort(wallAngle + 0x8000)

		m.GfxAngle = Util.SetYint16(m.GfxAngle, m.ActionArg)
		m.GfxAngle = Util.SetZint16(m.GfxAngle, m:FindFloorSlope(0x4000))
	end
end

local function tiltBodyWalking(m: Mario, startYaw: number)
	local anim = m.AnimCurrent
	local bodyState = m.BodyState

	if anim == Animations.WALKING or anim == Animations.RUNNING then
		local dYaw = m.FaceAngle.Y - startYaw

		local tiltZ = -math.clamp(dYaw * m.ForwardVel / 12, -0x1555, 0x1555)
		local tiltX = math.clamp(m.ForwardVel * 170, 0, 0x1555)

		local torsoAngle = bodyState.TorsoAngle
		tiltZ = Util.ApproachInt(torsoAngle.Z, tiltZ, 0x400)
		tiltX = Util.ApproachInt(torsoAngle.X, tiltX, 0x400)

		bodyState.TorsoAngle = Vector3int16.new(tiltX, torsoAngle.Y, tiltZ)
	else
		bodyState.TorsoAngle *= Vector3int16.new(0, 1, 0)
	end
end

local function tiltBodyButtSlide(m: Mario)
	local intendedDYaw = m.IntendedYaw - m.FaceAngle.Y
	local bodyState = m.BodyState

	local tiltX = 5461.3335 * m.IntendedMag / 32 * Util.Coss(intendedDYaw)
	local tiltZ = -(5461.3335 * m.IntendedMag / 32 * Util.Sins(intendedDYaw))

	local torsoAngle = bodyState.TorsoAngle
	bodyState.TorsoAngle = Vector3int16.new(tiltX, torsoAngle.Y, tiltZ)
end

local function commonSlideAction(m: Mario, endAction: number, airAction: number, anim: Animation)
	local pos = m.Position
	m:PlaySound(Sounds.MOVING_TERRAIN_SLIDE)
	m:AdjustSoundForSpeed()

	local step = m:PerformGroundStep()

	if step == GroundStep.LEFT_GROUND then
		m:SetAction(airAction)

		if math.abs(m.ForwardVel) >= 50 then
			m:PlaySound(Sounds.MARIO_HOOHOO)
		end
	elseif step == GroundStep.NONE then
		m:SetAnimation(anim)
		alignWithFloor(m)

		m.ParticleFlags:Add(ParticleFlags.DUST)
	elseif step == GroundStep.HIT_WALL then
		local wall = m.Wall

		if not m:FloorIsSlippery() then
			if m.ForwardVel > 16 then
				m.ParticleFlags:Add(ParticleFlags.VERTICAL_STAR)
			end

			slideBonk(m, Action.GROUND_BONK, endAction)
		elseif wall then
			local wallAngle = Util.Atan2s(wall.Normal.Z, wall.Normal.X)
			local slideSpeed = math.sqrt(m.SlideVelX ^ 2 * m.SlideVelZ ^ 2) * 0.9

			if slideSpeed < 4 then
				slideSpeed = 4
			end

			local slideYaw = Util.SignedShort(m.SlideYaw - wallAngle)
			m.SlideYaw = Util.SignedShort(wallAngle - slideYaw + 0x8000)
			m.SlideVelX = slideSpeed * Util.Sins(m.SlideYaw)
			m.SlideVelZ = slideSpeed * Util.Coss(m.SlideYaw)
			m.Velocity = Vector3.new(m.SlideVelX, m.Velocity.Y, m.SlideVelZ)
		end

		alignWithFloor(m)
	end
end

local function commonSlideActionWithJump(m: Mario, stopAction: number, airAction: number, anim: Animation)
	if m.ActionTimer == 5 then
		if m.Input:Has(InputFlags.A_PRESSED) then
			return m:SetJumpingAction(Action.JUMP)
		end
	else
		m.ActionTimer += 1
	end

	if updateSliding(m, 4) then
		m:SetAction(stopAction)
	end

	commonSlideAction(m, stopAction, airAction, anim)
	return false
end

local function commonLandingCancels(
	m: Mario,
	landingAction: LandingAction,
	setAPressAction: (Mario, number, any) -> any
)
	local floor = m.Floor

	if floor and floor.Normal.Y < 0.2923717 then
		return m:PushOffSteepFloor(Action.FREEFALL)
	end

	m.DoubleJumpTimer = landingAction.JumpTimer

	if shouldBeginSliding(m) then
		return m:SetAction(Action.BEGIN_SLIDING)
	end

	if m.Input:Has(InputFlags.FIRST_PERSON) then
		return m:SetAction(landingAction.EndAction)
	end

	m.ActionTimer += 1

	if m.ActionTimer >= landingAction.NumFrames then
		return m:SetAction(landingAction.EndAction)
	end

	if m.Input:Has(InputFlags.A_PRESSED) then
		return setAPressAction(m, landingAction.APressedAction, 0)
	end

	if m.Input:Has(InputFlags.OFF_FLOOR) then
		return m:SetAction(Action.FREEFALL)
	end

	return false
end

local function stomachSlideAction(m: Mario, stopAction: number, airAction: number, anim: Animation)
	if m.ActionTimer == 5 then
		if not m.Input:Has(InputFlags.ABOVE_SLIDE) and m.Input:Has(InputFlags.A_PRESSED, InputFlags.B_PRESSED) then
			return m:SetAction(if m.ForwardVel >= 0 then Action.FORWARD_ROLLOUT else Action.BACKWARD_ROLLOUT)
		end
	else
		m.ActionTimer += 1
	end

	if updateSliding(m, 4) then
		return m:SetAction(stopAction)
	end

	commonSlideAction(m, stopAction, airAction, anim)
	return false
end

local function commonGroundKnockbackAction(
	m: Mario,
	anim: Animation,
	minFrame: number,
	playHeavyLanding: boolean,
	attacked: number
)
	local animFrame

	if playHeavyLanding then
		m:PlayHeavyLandingSoundOnce(Sounds.ACTION_TERRAIN_BODY_HIT_GROUND)
	end

	if attacked > 0 then
		m:PlaySoundIfNoFlag(Sounds.MARIO_ATTACKED, MarioFlags.MARIO_SOUND_PLAYED)
	else
		m:PlaySoundIfNoFlag(Sounds.MARIO_OOOF, MarioFlags.MARIO_SOUND_PLAYED)
	end

	m.ForwardVel = math.clamp(m.ForwardVel, -32, 32)
	animFrame = m:SetAnimation(anim)

	if animFrame < minFrame then
		applyLandingAccel(m, 0.9)
	elseif m.ForwardVel > 0 then
		m:SetForwardVel(0.1)
	else
		m:SetForwardVel(-0.1)
	end

	if m:PerformGroundStep() == GroundStep.LEFT_GROUND then
		if m.ForwardVel >= 0 then
			m:SetAction(Action.FORWARD_AIR_KB, attacked)
		else
			m:SetAction(Action.BACKWARD_AIR_KB, attacked)
		end
	elseif m:IsAnimAtEnd() then
		if m.Health < 0x100 then
			m:SetAction(Action.STANDING_DEATH)
		else
			if attacked > 0 then
				m.InvincTimer = 30
			end

			m:SetAction(Action.IDLE)
		end
	end

	return animFrame
end

local function commonLandingAction(m: Mario, anim: Animation)
	if m.Input:Has(InputFlags.NONZERO_ANALOG) then
		applyLandingAccel(m, 0.98)
	elseif m.ForwardVel > 16 then
		applySlopeDecel(m, 2)
	else
		m.Velocity *= Vector3.new(1, 0, 1)
	end

	local stepResult = m:PerformGroundStep()

	if stepResult == GroundStep.LEFT_GROUND then
		m:SetAction(Action.FREEFALL)
	elseif stepResult == GroundStep.HIT_WALL then
		m:SetAnimation(Animations.PUSHING)
	end

	if m.ForwardVel > 16 then
		m.ParticleFlags:Add(ParticleFlags.DUST)
	end

	m:SetAnimation(anim)
	m:PlayLandingSoundOnce(Sounds.ACTION_TERRAIN_LANDING)

	return stepResult
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

DEF_ACTION(Action.WALKING, function(m: Mario)
	local startPos
	local startYaw = m.FaceAngle.Y

	if shouldBeginSliding(m) then
		return m:SetAction(Action.BEGIN_SLIDING)
	end

	if m.Input:Has(InputFlags.FIRST_PERSON) then
		return beginBrakingAction(m)
	end

	if m.Input:Has(InputFlags.A_PRESSED) then
		return m:SetJumpFromLanding()
	end

	if checkGroundDiveOrPunch(m) then
		return true
	end

	if m.Input:Has(InputFlags.UNKNOWN_5) then
		return beginBrakingAction(m)
	end

	if analogStickHeldBack(m) and m.ForwardVel >= 16 then
		return m:SetAction(Action.TURNING_AROUND)
	end

	if m.Input:Has(InputFlags.Z_PRESSED) then
		return m:SetAction(Action.CROUCH_SLIDE)
	end

	local step
	do
		m.ActionState = 0
		startPos = m.Position

		updateWalkingSpeed(m)
		step = m:PerformGroundStep()
	end

	if step == GroundStep.LEFT_GROUND then
		m:SetAction(Action.FREEFALL)
		m:SetAnimation(Animations.GENERAL_FALL)
	elseif step == GroundStep.NONE then
		animAndAudioForWalk(m)

		if m.IntendedMag - m.ForwardVel > 16 then
			m.ParticleFlags:Add(ParticleFlags.DUST)
		end
	elseif step == GroundStep.HIT_WALL then
		pushOrSidleWall(m, startPos)
		m.ActionTimer = 0
	end

	checkLedgeClimbDown(m)
	tiltBodyWalking(m, startYaw)

	return false
end)

DEF_ACTION(Action.MOVE_PUNCHING, function(m: Mario)
	if shouldBeginSliding(m) then
		return m:SetAction(Action.BEGIN_SLIDING)
	end

	if m.ActionState == 0 and m.Input:Has(InputFlags.A_DOWN) then
		return m:SetAction(Action.JUMP_KICK)
	end

	m.ActionState = 1
	m:UpdatePunchSequence()

	if m.ForwardVel > 0 then
		applySlopeDecel(m, 0.5)
	else
		m.ForwardVel += 8

		if m.ForwardVel >= 0 then
			m.ForwardVel = 0
		end

		applySlopeAccel(m)
	end

	local step = m:PerformGroundStep()

	if step == GroundStep.LEFT_GROUND then
		m:SetAction(Action.FREEFALL)
	elseif step == GroundStep.NONE then
		m.ParticleFlags:Add(ParticleFlags.DUST)
	end

	return false
end)

DEF_ACTION(Action.TURNING_AROUND, function(m: Mario)
	if m.Input:Has(InputFlags.ABOVE_SLIDE) then
		return m:SetAction(Action.BEGIN_SLIDING)
	end

	if m.Input:Has(InputFlags.A_PRESSED) then
		return m:SetAction(Action.SIDE_FLIP)
	end

	if not analogStickHeldBack(m) then
		return m:SetAction(Action.WALKING)
	end

	if applySlopeDecel(m, 2) then
		return beginWalkingAction(m, 8, Action.FINISH_TURNING_AROUND)
	end

	m:PlaySound(Sounds.MOVING_TERRAIN_SLIDE)
	m:AdjustSoundForSpeed()

	local step = m:PerformGroundStep()

	if step == GroundStep.LEFT_GROUND then
		m:SetAction(Action.FREEFALL)
	elseif step == GroundStep.NONE then
		m.ParticleFlags:Add(ParticleFlags.DUST)
	end

	if m.ForwardVel >= 18 then
		m:SetAnimation(Animations.TURNING_PART1)
	else
		m:SetAnimation(Animations.TURNING_PART2)

		if m:IsAnimAtEnd() then
			if m.ForwardVel > 0 then
				beginWalkingAction(m, -m.ForwardVel, Action.WALKING)
			else
				beginWalkingAction(m, 8, Action.WALKING)
			end

			m.AnimSkipInterp = true
		end
	end

	return false
end)

DEF_ACTION(Action.FINISH_TURNING_AROUND, function(m: Mario)
	if m.Input:Has(InputFlags.ABOVE_SLIDE) then
		return m:SetAction(Action.BEGIN_SLIDING)
	end

	if m.Input:Has(InputFlags.A_PRESSED) then
		return m:SetAction(Action.SIDE_FLIP)
	end

	updateWalkingSpeed(m)
	m:SetAnimation(Animations.TURNING_PART2)

	if m:PerformGroundStep() == GroundStep.LEFT_GROUND then
		m:SetAction(Action.FREEFALL)
	end

	if m:IsAnimAtEnd() then
		m:SetAction(Action.WALKING)
	end

	m.GfxAngle += Vector3int16.new(0, 0x8000, 0)
	return false
end)

DEF_ACTION(Action.BRAKING, function(m: Mario)
	if not m.Input:Has(InputFlags.FIRST_PERSON) then
		if
			m.Input:Has(InputFlags.NONZERO_ANALOG, InputFlags.A_PRESSED, InputFlags.OFF_FLOOR, InputFlags.ABOVE_SLIDE)
		then
			return m:CheckCommonActionExits()
		end
	end

	if applySlopeDecel(m, 2) then
		return m:SetAction(Action.BRAKING_STOP)
	end

	if m.Input:Has(InputFlags.B_PRESSED) then
		return m:SetAction(Action.MOVE_PUNCHING)
	end

	local stepResult = m:PerformGroundStep()

	if stepResult == GroundStep.LEFT_GROUND then
		m:SetAction(Action.FREEFALL)
	elseif stepResult == GroundStep.NONE then
		m.ParticleFlags:Add(ParticleFlags.DUST)
	elseif stepResult == GroundStep.HIT_WALL then
		slideBonk(m, Action.BACKWARD_GROUND_KB, Action.BRAKING_STOP)
	end

	m:PlaySound(Sounds.MOVING_TERRAIN_SLIDE)
	m:SetAnimation(Animations.SKID_ON_GROUND)
	m:AdjustSoundForSpeed()

	return false
end)

DEF_ACTION(Action.DECELERATING, function(m: Mario)
	if not m.Input:Has(InputFlags.FIRST_PERSON) then
		if shouldBeginSliding(m) then
			return m:SetAction(Action.BEGIN_SLIDING)
		end

		if m.Input:Has(InputFlags.A_PRESSED) then
			return m:SetJumpFromLanding()
		end

		if checkGroundDiveOrPunch(m) then
			return true
		end

		if m.Input:Has(InputFlags.NONZERO_ANALOG) then
			return m:SetAction(Action.CROUCH_SLIDE)
		end

		if m.Input:Has(InputFlags.Z_PRESSED) then
			return m:SetAction(Action.CROUCH_SLIDE)
		end
	end

	if updateDeceleratingSpeed(m) then
		return m:SetAction(Action.IDLE)
	end

	local slopeClass = m:GetFloorClass()
	local stepResult = m:PerformGroundStep()

	if stepResult == GroundStep.LEFT_GROUND then
		m:SetAction(Action.FREEFALL)
	elseif stepResult == GroundStep.HIT_WALL then
		if slopeClass == SurfaceClass.VERY_SLIPPERY then
			m:BonkReflection(true)
		else
			m:SetForwardVel(0)
		end
	end

	if slopeClass == SurfaceClass.VERY_SLIPPERY then
		m:SetAnimation(Animations.IDLE_HEAD_LEFT)
		m:PlaySound(Sounds.MOVING_TERRAIN_SLIDE)

		m:AdjustSoundForSpeed()
		m.ParticleFlags:Add(ParticleFlags.DUST)
	else
		local accel = m.ForwardVel / 4 * 0x10000

		if accel < 0x1000 then
			accel = 0x1000
		end

		m:SetAnimationWithAccel(Animations.WALKING, accel)
		playStepSound(m, 10, 49)
	end

	return false
end)

DEF_ACTION(Action.CRAWLING, function(m: Mario)
	if shouldBeginSliding(m) then
		return m:SetAction(Action.BEGIN_SLIDING)
	end

	if m.Input:Has(InputFlags.FIRST_PERSON) then
		return m:SetAction(Action.STOP_CRAWLING)
	end

	if m.Input:Has(InputFlags.A_PRESSED) then
		return m:SetJumpingAction(Action.JUMP)
	end

	if checkGroundDiveOrPunch(m) then
		return true
	end

	if m.Input:Has(InputFlags.UNKNOWN_5) then
		return m:SetAction(Action.STOP_CRAWLING)
	end

	if not m.Input:Has(InputFlags.Z_DOWN) then
		return m:SetAction(Action.STOP_CRAWLING)
	end

	m.IntendedMag *= 0.1
	updateWalkingSpeed(m)

	local stepResult = m:PerformGroundStep()

	if stepResult == GroundStep.LEFT_GROUND then
		m:SetAction(Action.FREEFALL)
	elseif stepResult == GroundStep.HIT_WALL then
		if m.ForwardVel > 10 then
			m:SetForwardVel(10)
		end

		alignWithFloor(m)
	elseif stepResult == GroundStep.NONE then
		alignWithFloor(m)
	end

	local accel = m.IntendedMag * 2 * 0x10000
	m:SetAnimationWithAccel(Animations.CRAWLING, accel)
	playStepSound(m, 26, 79)

	return false
end)

DEF_ACTION(Action.BURNING_GROUND, function(m: Mario)
	if m.Input:Has(InputFlags.A_PRESSED) then
		return m:SetAction(Action.BURNING_JUMP)
	end

	m.BurnTimer += 2

	if m.BurnTimer > 160 then
		return m:SetAction(Action.WALKING)
	end

	if m.ForwardVel < 8 then
		m.ForwardVel = 8
	end

	if m.ForwardVel > 48 then
		m.ForwardVel = 48
	end

	m.ForwardVel = Util.ApproachFloat(m.ForwardVel, 32, 4, 1)

	if m.Input:Has(InputFlags.NONZERO_ANALOG) then
		local faceY = m.IntendedYaw - Util.ApproachFloat(m.IntendedYaw - m.FaceAngle.Y, 0, 0x600)
		m.FaceAngle = Util.SetYint16(m.FaceAngle, faceY)
	end

	applySlopeAccel(m)

	if m:PerformGroundStep() == GroundStep.LEFT_GROUND then
		m:SetAction(Action.BURNING_FALL)
	end

	local accel = m.ForwardVel / 2 * 0x10000
	m:SetAnimationWithAccel(Animations.RUNNING, accel)
	playStepSound(m, 9, 45)

	m.ParticleFlags:Add(ParticleFlags.FIRE)
	m:PlaySound(Sounds.MOVING_LAVA_BURN)

	m.Health -= 10

	if m.Health < 0x100 then
		m:SetAction(Action.STANDING_DEATH)
	end

	m.BodyState.EyeState = MarioEyes.DEAD
	return false
end)

DEF_ACTION(Action.BUTT_SLIDE, function(m: Mario)
	local cancel = commonSlideActionWithJump(m, Action.BUTT_SLIDE_STOP, Action.BUTT_SLIDE_AIR, Animations.SLIDE)
	tiltBodyButtSlide(m)

	return cancel
end)

DEF_ACTION(Action.CROUCH_SLIDE, function(m: Mario)
	if m.Input:Has(InputFlags.ABOVE_SLIDE) then
		return m:SetAction(Action.BUTT_SLIDE)
	end

	if m.ActionTimer < 30 then
		m.ActionTimer += 1

		if m.Input:Has(InputFlags.A_PRESSED) then
			if m.ForwardVel > 10 then
				return m:SetJumpingAction(Action.LONG_JUMP)
			end
		end
	end

	if m.Input:Has(InputFlags.B_PRESSED) then
		if m.ForwardVel >= 10 then
			m:SetAction(Action.SLIDE_KICK)
		else
			m:SetAction(Action.MOVE_PUNCHING, 9)
		end
	end

	if m.Input:Has(InputFlags.A_PRESSED) then
		return m:SetAction(Action.JUMP)
	end

	if m.Input:Has(InputFlags.FIRST_PERSON) then
		return m:SetAction(Action.BRAKING)
	end

	return commonSlideActionWithJump(m, Action.CROUCHING, Action.FREEFALL, Animations.START_CROUCHING)
end)

DEF_ACTION(Action.SLIDE_KICK_SLIDE, function(m: Mario)
	local step

	if m.Input:Has(InputFlags.A_PRESSED) then
		return m:SetAction(Action.FORWARD_ROLLOUT)
	end

	m:SetAnimation(Animations.SLIDE_KICK)

	if m:IsAnimAtEnd() and m.ForwardVel < 1 then
		return m:SetAction(Action.SLIDE_KICK_SLIDE_STOP)
	end

	updateSliding(m, 1)
	step = m:PerformGroundStep()

	if step == GroundStep.LEFT_GROUND then
		m:SetAction(Action.FREEFALL, 2)
	elseif step == GroundStep.HIT_WALL then
		m:BonkReflection(true)
		m.ParticleFlags:Add(ParticleFlags.VERTICAL_STAR)
		m:SetAction(Action.BACKWARD_GROUND_KB)
	end

	m:PlaySound(Sounds.MOVING_TERRAIN_SLIDE)
	m.ParticleFlags:Add(ParticleFlags.DUST)

	return false
end)

DEF_ACTION(Action.STOMACH_SLIDE, function(m: Mario)
	if m.ActionTimer == 5 then
		if not m.Input:Has(InputFlags.ABOVE_SLIDE) and m.Input:Has(InputFlags.A_PRESSED, InputFlags.B_PRESSED) then
			return m:SetAction(if m.ForwardVel >= 0 then Action.FORWARD_ROLLOUT else Action.BACKWARD_ROLLOUT)
		end
	else
		m.ActionTimer += 1
	end

	if updateSliding(m, 4) then
		return m:SetAction(Action.STOMACH_SLIDE_STOP)
	end

	commonSlideAction(m, Action.STOMACH_SLIDE_STOP, Action.FREEFALL, Animations.SLIDE_DIVE)
	return false
end)

DEF_ACTION(Action.DIVE_SLIDE, function(m: Mario)
	if not m.Input:Has(InputFlags.ABOVE_SLIDE) and m.Input:Has(InputFlags.A_PRESSED, InputFlags.B_PRESSED) then
		return m:SetAction(if m.ForwardVel >= 0 then Action.FORWARD_ROLLOUT else Action.BACKWARD_ROLLOUT)
	end

	m:PlayLandingSoundOnce(Sounds.ACTION_TERRAIN_BODY_HIT_GROUND)

	if updateSliding(m, 8) and m:IsAnimAtEnd() then
		m:SetForwardVel(0)
		m:SetAction(Action.STOMACH_SLIDE_STOP)
	end

	commonSlideAction(m, Action.STOMACH_SLIDE_STOP, Action.FREEFALL, Animations.DIVE)
	return false
end)

DEF_ACTION(Action.HARD_BACKWARD_GROUND_KB, function(m: Mario)
	local animFrame = commonGroundKnockbackAction(m, Animations.FALL_OVER_BACKWARDS, 43, true, m.ActionArg)

	if animFrame == 43 and m.Health < 0x100 then
		m:SetAction(Action.DEATH_ON_BACK)
	end

	if animFrame == 54 and m.PrevAction() == Action.SPECIAL_DEATH_EXIT then
		m:PlaySound(Sounds.MARIO_MAMA_MIA)
	end

	if animFrame == 69 then
		m:PlayLandingSoundOnce(Sounds.ACTION_TERRAIN_LANDING)
	end

	return false
end)

DEF_ACTION(Action.HARD_FORWARD_GROUND_KB, function(m: Mario)
	local animFrame = commonGroundKnockbackAction(m, Animations.LAND_ON_STOMACH, 21, true, m.ActionArg)

	if animFrame == 23 and m.Health < 0x100 then
		m:SetAction(Action.DEATH_ON_STOMACH)
	end

	return false
end)

DEF_ACTION(Action.BACKWARD_GROUND_KB, function(m: Mario)
	commonGroundKnockbackAction(m, Animations.BACKWARD_KB, 22, true, m.ActionArg)
	return false
end)

DEF_ACTION(Action.FORWARD_GROUND_KB, function(m: Mario)
	commonGroundKnockbackAction(m, Animations.FORWARD_KB, 20, true, m.ActionArg)
	return false
end)

DEF_ACTION(Action.SOFT_BACKWARD_GROUND_KB, function(m: Mario)
	commonGroundKnockbackAction(m, Animations.SOFT_BACK_KB, 100, false, m.ActionArg)
	return false
end)

DEF_ACTION(Action.SOFT_FORWARD_GROUND_KB, function(m: Mario)
	commonGroundKnockbackAction(m, Animations.SOFT_FRONT_KB, 100, false, m.ActionArg)
	return false
end)

DEF_ACTION(Action.GROUND_BONK, function(m: Mario)
	local animFrame = commonGroundKnockbackAction(m, Animations.GROUND_BONK, 32, true, m.ActionArg)

	if animFrame == 32 then
		m:PlayLandingSound(Sounds.ACTION_TERRAIN_LANDING)
	end

	return false
end)

DEF_ACTION(Action.JUMP_LAND, function(m: Mario)
	if commonLandingCancels(m, sJumpLandAction, m.SetJumpingAction) then
		return true
	end

	commonLandingAction(m, Animations.LAND_FROM_SINGLE_JUMP)
	return false
end)

DEF_ACTION(Action.FREEFALL_LAND, function(m: Mario)
	if commonLandingCancels(m, sFreefallLandAction, m.SetJumpingAction) then
		return true
	end

	commonLandingAction(m, Animations.GENERAL_LAND)
	return false
end)

DEF_ACTION(Action.SIDE_FLIP_LAND, function(m: Mario)
	if commonLandingCancels(m, sSideFlipLandAction, m.SetJumpingAction) then
		return true
	end

	if commonLandingAction(m, Animations.SLIDEFLIP_LAND) ~= GroundStep.HIT_WALL then
		--m.GfxAngle += Vector3int16.new(0, 0x8000, 0)
	end

	return false
end)

DEF_ACTION(Action.LONG_JUMP_LAND, function(m: Mario)
	if not m.Input:Has(InputFlags.Z_DOWN) then
		m.Input:Remove(InputFlags.A_PRESSED)
	end

	if commonLandingCancels(m, sLongJumpLandAction, m.SetJumpingAction) then
		return true
	end

	if not m.Input:Has(InputFlags.NONZERO_ANALOG) then
		m:PlaySoundIfNoFlag(Sounds.MARIO_UH, MarioFlags.MARIO_SOUND_PLAYED)
	end
	
	-- stylua: ignore
	commonLandingAction(m, if m.LongJumpIsSlow
		then Animations.CROUCH_FROM_FAST_LONGJUMP
		else Animations.CROUCH_FROM_SLOW_LONGJUMP)

	return false
end)

DEF_ACTION(Action.DOUBLE_JUMP_LAND, function(m: Mario)
	if commonLandingCancels(m, sDoubleJumpLandAction, setTripleJumpAction) then
		return true
	end

	commonLandingAction(m, Animations.LAND_FROM_DOUBLE_JUMP)
	return false
end)

DEF_ACTION(Action.TRIPLE_JUMP_LAND, function(m: Mario)
	m.Input:Remove(InputFlags.A_PRESSED)

	if commonLandingCancels(m, sTripleJumpLandAction, m.SetJumpingAction) then
		return true
	end

	if not m.Input:Has(InputFlags.NONZERO_ANALOG) then
		m:PlaySoundIfNoFlag(Sounds.MARIO_HAHA, MarioFlags.MARIO_SOUND_PLAYED)
	end

	commonLandingAction(m, Animations.TRIPLE_JUMP_LAND)
	return false
end)

DEF_ACTION(Action.BACKFLIP_LAND, function(m: Mario)
	if not m.Input:Has(InputFlags.Z_DOWN) then
		m.Input:Remove(InputFlags.A_PRESSED)
	end

	if commonLandingCancels(m, sBackflipLandAction, m.SetJumpingAction) then
		return true
	end

	if not m.Input:Has(InputFlags.NONZERO_ANALOG) then
		m:PlaySoundIfNoFlag(Sounds.MARIO_HAHA, MarioFlags.MARIO_SOUND_PLAYED)
	end

	commonLandingAction(m, Animations.TRIPLE_JUMP_LAND)
	return false
end)

DEF_ACTION(Action.PUNCHING, function(m: Mario)
	if m.Input:Has(InputFlags.STOMPED) then
		return m:SetAction(Action.SHOCKWAVE_BOUNCE)
	end

	if m.Input:Has(InputFlags.NONZERO_ANALOG, InputFlags.A_PRESSED, InputFlags.OFF_FLOOR, InputFlags.ABOVE_SLIDE) then
		return m:CheckCommonActionExits()
	end

	if m.ActionState and m.Input:Has(InputFlags.A_DOWN) then
		return m:SetAction(Action.JUMP_KICK)
	end

	m.ActionState = 1

	if m.ActionArg == 0 then
		m.ActionTimer = 7
	end

	m:SetForwardVel(sPunchingForwardVelocities[m.ActionTimer + 1])

	if m.ActionTimer > 0 then
		m.ActionTimer -= 1
	end

	m:UpdatePunchSequence()
	m:PerformGroundStep()

	return false
end)
