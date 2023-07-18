--!strict

local Flags = require(script.Flags)
export type Flags = Flags.Class

export type Controller = {
	RawStickX: number,
	RawStickY: number,

	StickX: number,
	StickY: number,
	StickMag: number,

	ButtonDown: Flags,
	ButtonPressed: Flags,
}

export type BodyState = {
	Action: number,
	CapState: Flags,
	EyeState: number,
	HandState: Flags,
	WingFlutter: boolean,
	ModelState: Flags,
	GrabPos: number,
	PunchType: number,
	PunchTimer: number,
	TorsoAngle: Vector3int16,
	HeadAngle: Vector3int16,
	HeldObjLastPos: Vector3,
}

export type MarioState = {
	Input: Flags,
	Flags: Flags,

	Action: Flags,
	PrevAction: Flags,
	ParticleFlags: Flags,
	HitboxHeight: number,
	TerrainType: number,
	HeldObj: Instance?,

	ActionState: number,
	ActionTimer: number,
	ActionArg: number,

	IntendedMag: number,
	IntendedYaw: number,
	InvincTimer: number,

	FramesSinceA: number,
	FramesSinceB: number,

	WallKickTimer: number,
	DoubleJumpTimer: number,

	FaceAngle: Vector3int16,
	AngleVel: Vector3int16,
	ThrowMatrix: CFrame?,

	GfxAngle: Vector3int16,
	GfxPos: Vector3,

	SlideYaw: number,
	TwirlYaw: number,

	Position: Vector3,
	Velocity: Vector3,

	ForwardVel: number,
	SlideVelX: number,
	SlideVelZ: number,

	Wall: RaycastResult?,
	Ceil: RaycastResult?,
	Floor: RaycastResult?,

	CeilHeight: number,
	FloorHeight: number,
	FloorAngle: number,
	WaterLevel: number,

	BodyState: BodyState,
	Controller: Controller,

	Health: number,
	HurtCounter: number,
	HealCounter: number,
	SquishTimer: number,

	CapTimer: number,
	BurnTimer: number,
	PeakHeight: number,
	SteepJumpYaw: number,
	WalkingPitch: number,
	QuicksandDepth: number,
	LongJumpIsSlow: boolean,

	AnimCurrent: Animation?,
	AnimFrameCount: number,

	AnimAccel: number,
	AnimAccelAssist: number,

	AnimFrame: number,
	AnimDirty: boolean,
	AnimReset: boolean,
	AnimSetFrame: number,
	AnimSkipInterp: number,
}

return table.freeze({
	Flags = Flags,
})
