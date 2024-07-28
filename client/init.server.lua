--!strict
local Core = script.Parent

if Core:GetAttribute("HotLoading") then
	task.wait(3)
end

for i, desc in script:GetDescendants() do
	if desc:IsA("BaseScript") then
		desc.Enabled = true
	end
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local Shared = require(Core.Shared)
local Sounds = Shared.Sounds

local Enums = require(script.Enums)
local Mario = require(script.Mario)
local Types = require(script.Types)
local Util = require(script.Util)

local Action = Enums.Action
local Buttons = Enums.Buttons
local MarioFlags = Enums.MarioFlags
local ParticleFlags = Enums.ParticleFlags

local SurfaceClass = Enums.SurfaceClass

type InputType = Enum.UserInputType | Enum.KeyCode
type Controller = Types.Controller
type Mario = Mario.Class

local player: Player = assert(Players.LocalPlayer)
local mario: Mario = Mario.new()

local STEP_RATE = 30
local NULL_TEXT = `<font color="#FF0000">NULL</font>`
local FLIP = CFrame.Angles(0, math.pi, 0)

local debugStats = Instance.new("BoolValue")
debugStats.Name = "DebugStats"
debugStats.Archivable = false
debugStats.Parent = game

local PARTICLE_CLASSES = {
	Fire = true,
	Smoke = true,
	Sparkles = true,
	ParticleEmitter = true,
}

local AUTO_STATS = {
	"Position",
	"Velocity",
	"AnimFrame",
	"FaceAngle",

	"ActionState",
	"ActionTimer",
	"ActionArg",

	"ForwardVel",
	"SlideVelX",
	"SlideVelZ",

	"CeilHeight",
	"FloorHeight",
	"WaterLevel",
	"QuicksandDepth",
}

local ControlModule: {
	GetMoveVector: (self: any) -> Vector3,
}

while not ControlModule do
	local inst = player:FindFirstChild("ControlModule", true)

	if inst then
		ControlModule = (require :: any)(inst)
	end

	task.wait(0.1)
end

-------------------------------------------------------------------------------------------------------------------------------------------------
-- Input Driver
-------------------------------------------------------------------------------------------------------------------------------------------------

-- NOTE: I had to replace the default BindAction via KeyCode and UserInputType
-- BindAction forces some mappings (such as R2 mapping to MouseButton1) which you
-- can't turn off otherwise.

local BUTTON_FEED = {}
local BUTTON_BINDS = {}
local TAS_INPUT_OVERRIDE = false

local function toStrictNumber(str: string): number
	local result = tonumber(str)
	return assert(result, "Invalid number!")
end

local function processAction(id: string, state: Enum.UserInputState, input: InputObject)
	if id == "MarioDebug" and Core:GetAttribute("DebugToggle") then
		if state == Enum.UserInputState.Begin then
			local character = player.Character

			if character then
				local isDebug = not character:GetAttribute("Debug")
				character:SetAttribute("Debug", isDebug)
			end
		end
	elseif id == "TASInputForceToggle" then
		if state == Enum.UserInputState.Begin then
			TAS_INPUT_OVERRIDE = not TAS_INPUT_OVERRIDE
			print(`<- TAS input override {TAS_INPUT_OVERRIDE and "ON" or "OFF"} ->`)
		end
	else
		local button = toStrictNumber(id:sub(5))
		BUTTON_FEED[button] = state
	end
end

local function processInput(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then
		return
	end
	if BUTTON_BINDS[input.UserInputType] ~= nil then
		processAction(BUTTON_BINDS[input.UserInputType], input.UserInputState, input)
	end
	if BUTTON_BINDS[input.KeyCode] ~= nil then
		processAction(BUTTON_BINDS[input.KeyCode], input.UserInputState, input)
	end
end

UserInputService.InputBegan:Connect(processInput)
UserInputService.InputChanged:Connect(processInput)
UserInputService.InputEnded:Connect(processInput)

local function bindInput(button: number, label: string, ...: InputType)
	local id = "BTN_" .. button

	if UserInputService.TouchEnabled then
		ContextActionService:BindAction(id, processAction, true)
		ContextActionService:SetTitle(id, label)
	end

	for i, input in { ... } do
		BUTTON_BINDS[input] = id
	end
end

local function updateCollisions()
	for i, player in Players:GetPlayers() do
		-- stylua: ignore
		local character = player.Character
		local rootPart = character and character.PrimaryPart

		if rootPart then
			local parts = rootPart:GetConnectedParts(true)

			for i, part in parts do
				if part:IsA("BasePart") then
					part.CanCollide = false
				end
			end
		end
	end
end

local function updateController(controller: Controller, humanoid: Humanoid?)
	if not humanoid then
		return
	end

	local moveDir = ControlModule:GetMoveVector()
	local pos = Vector2.new(moveDir.X, -moveDir.Z)
	local mag = 0

	if pos.Magnitude > 0 then
		if pos.Magnitude > 1 then
			pos = pos.Unit
		end

		mag = pos.Magnitude
	end

	controller.StickMag = mag * 64
	controller.StickX = pos.X * 64
	controller.StickY = pos.Y * 64

	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	controller.ButtonPressed:Clear()

	if humanoid.Jump then
		BUTTON_FEED[Buttons.A_BUTTON] = Enum.UserInputState.Begin
	elseif controller.ButtonDown:Has(Buttons.A_BUTTON) then
		BUTTON_FEED[Buttons.A_BUTTON] = Enum.UserInputState.End
	end

	local lastButtonValue = controller.ButtonDown()

	for button, state in pairs(BUTTON_FEED) do
		if state == Enum.UserInputState.Begin then
			controller.ButtonDown:Add(button)
		elseif state == Enum.UserInputState.End then
			controller.ButtonDown:Remove(button)
		end
	end

	table.clear(BUTTON_FEED)

	local buttonValue = controller.ButtonDown()
	controller.ButtonPressed:Set(buttonValue)
	controller.ButtonPressed:Band(bit32.bxor(buttonValue, lastButtonValue))

	local character = humanoid.Parent
	if
		((character and character:GetAttribute("TAS")) or Core:GetAttribute("ToolAssistedInput"))
		and not TAS_INPUT_OVERRIDE
	then
		if not mario.Action:Has(Enums.ActionFlags.SWIMMING, Enums.ActionFlags.HANGING) then
			if
				controller.ButtonDown:Has(Buttons.A_BUTTON)
				and not (controller.ButtonDown:Has(Buttons.B_BUTTON) or controller.ButtonPressed:Has(Buttons.Z_TRIG))
			then
				controller.ButtonPressed:Set(Buttons.A_BUTTON)
			end
		end
	end
end

ContextActionService:BindAction("MarioDebug", processAction, false, Enum.KeyCode.P)
ContextActionService:BindAction("TASInputForceToggle", processAction, false, Enum.KeyCode.RightControl)
bindInput(Buttons.B_BUTTON, "B", Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonX)
bindInput(
	Buttons.Z_TRIG,
	"Z",
	Enum.KeyCode.LeftShift,
	Enum.KeyCode.RightShift,
	Enum.KeyCode.ButtonL2,
	Enum.KeyCode.ButtonR2
)

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Network Dispatch
-------------------------------------------------------------------------------------------------------------------------------------------------------------

local Commands = {}
local soundDecay = {}

local lazyNetwork = ReplicatedStorage:WaitForChild("LazyNetwork")
assert(lazyNetwork:IsA("RemoteEvent"), "bad lazyNetwork!")

local function stepDecay(sound: Sound)
	local decay = soundDecay[sound]

	if decay then
		task.cancel(decay)
	end

	soundDecay[sound] = task.delay(0.1, function()
		sound:Stop()
		sound:Destroy()
		soundDecay[sound] = nil
	end)

	sound.Playing = true
end

function Commands.PlaySound(player: Player, name: string)
	local sound: Sound? = Sounds[name]
	local character = player.Character
	local rootPart = character and character.PrimaryPart

	if rootPart and sound then
		local oldSound: Instance? = rootPart:FindFirstChild(name)
		local canPlay = true

		if oldSound and oldSound:IsA("Sound") then
			canPlay = false

			if name:sub(1, 6) == "MOVING" or sound:GetAttribute("Decay") then
				-- Keep decaying audio alive.
				stepDecay(oldSound)
			elseif name:sub(1, 5) == "MARIO" then
				-- Restart mario sound if a 30hz interval passed.
				local now = os.clock()
				local lastPlay = oldSound:GetAttribute("LastPlay") or 0

				if now - lastPlay >= 2 / STEP_RATE then
					oldSound.TimePosition = 0
					oldSound:SetAttribute("LastPlay", now)
				end
			else
				-- Allow stacking.
				canPlay = true
			end
		end

		if canPlay then
			local newSound: Sound = sound:Clone()
			newSound.Parent = rootPart
			newSound:Play()

			if name:find("MOVING") then
				-- Audio will decay if PlaySound isn't continuously called.
				stepDecay(newSound)
			end

			newSound.Ended:Connect(function()
				newSound:Destroy()
			end)

			newSound:SetAttribute("LastPlay", os.clock())
		end
	end
end

function Commands.SetParticle(player: Player, name: string, set: boolean)
	local character = player.Character
	local rootPart = character and character.PrimaryPart

	if rootPart then
		local particles = rootPart:FindFirstChild("Particles")
		local inst = particles and particles:FindFirstChild(name, true)

		if inst and PARTICLE_CLASSES[inst.ClassName] then
			local particle = inst :: ParticleEmitter
			local emit = particle:GetAttribute("Emit")

			if typeof(emit) == "number" then
				particle:Emit(emit)
			elseif set ~= nil then
				particle.Enabled = set
			end
		else
			warn("particle not found:", name)
		end
	end
end

function Commands.SetTorsoAngle(player: Player, angle: Vector3int16)
	local character = player.Character
	local waist = character and character:FindFirstChild("Waist", true)

	if waist and waist:IsA("Motor6D") then
		local props = { C1 = Util.ToRotation(-angle) + waist.C1.Position }
		local tween = TweenService:Create(waist, TweenInfo.new(0.1), props)
		tween:Play()
	end
end

function Commands.SetHeadAngle(player: Player, angle: Vector3int16)
	local character = player.Character
	local neck = character and character:FindFirstChild("Neck", true)

	if neck and neck:IsA("Motor6D") then
		local props = { C1 = Util.ToRotation(-angle) + neck.C1.Position }
		local tween = TweenService:Create(neck, TweenInfo.new(0.1), props)
		tween:Play()
	end
end

function Commands.SetHealth(player: Player, health: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
	local health = math.max(health, 0.01)

	if humanoid then
		humanoid.MaxHealth = 8
		humanoid.Health = health
	end
end

function Commands.SetCamera(player: Player, cf: CFrame?)
	local camera = workspace.CurrentCamera

	if cf ~= nil then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = cf
	else
		camera.CameraType = Enum.CameraType.Custom
	end
end

local function processCommand(player: Player, cmd: string, ...: any)
	local command = Commands[cmd]

	if command then
		task.spawn(command, player, ...)
	else
		warn("Unknown Command:", cmd, ...)
	end
end

local function networkDispatch(cmd: string, ...: any)
	lazyNetwork:FireServer(cmd, ...)
	processCommand(player, cmd, ...)
end

local function onNetworkReceive(target: Player, cmd: string, ...: any)
	if target ~= player then
		processCommand(target, cmd, ...)
	end
end

lazyNetwork.OnClientEvent:Connect(onNetworkReceive)

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Mario Driver
-------------------------------------------------------------------------------------------------------------------------------------------------------------

local lastUpdate = os.clock()
local lastHeadAngle: Vector3int16?
local lastTorsoAngle: Vector3int16?
local lastHealth: number?

local activeScale = 1
local subframe = 0 -- 30hz subframe
local emptyId = ""

local goalCF: CFrame
local prevCF: CFrame
local activeTrack: AnimationTrack?

local reset = Instance.new("BindableEvent")
reset.Archivable = false
reset.Parent = script
reset.Name = "Reset"

-- To not reach the 256 tracks limit warning
local loadedAnims: { [string]: AnimationTrack } = {}

if RunService:IsStudio() then
	local dummySequence = Instance.new("KeyframeSequence")
	local provider = game:GetService("KeyframeSequenceProvider")
	emptyId = provider:RegisterKeyframeSequence(dummySequence)
end

while not player.Character do
	player.CharacterAdded:Wait()
end

local character = assert(player.Character)
local pivot = character:GetPivot()
mario.Position = Util.ToSM64(pivot.Position)

goalCF = pivot
prevCF = pivot

local function setDebugStat(key: string, value: any)
	if typeof(value) == "Vector3" then
		value = string.format("%.3f, %.3f, %.3f", value.X, value.Y, value.Z)
	elseif typeof(value) == "Vector3int16" then
		value = string.format("%i, %i, %i", value.X, value.Y, value.Z)
	elseif type(value) == "number" then
		if math.abs(value) == math.huge then
			local sign = math.sign(value) == -1 and "-" or ""
			value = `{sign}∞`
		else
			value = string.format("%.3f", value)
		end
	end

	debugStats:SetAttribute(key, value)
end

local function onReset()
	local roblox = Vector3.yAxis * 100
	local sm64 = Util.ToSM64(roblox)
	local char = player.Character

	if char then
		local reset = char:FindFirstChild("Reset")

		local cf = CFrame.new(roblox)
		char:PivotTo(cf)

		goalCF = cf
		prevCF = cf

		if reset and reset:IsA("RemoteEvent") then
			reset:FireServer()
		end
	end

	mario.SlideVelX = 0
	mario.SlideVelZ = 0
	mario.ForwardVel = 0
	mario.IntendedYaw = 0

	mario.HealCounter = 0
	mario.HurtCounter = 0
	mario.Health = 0x880
	mario.SquishTimer = 0

	mario.QuicksandDepth = 0

	mario.Position = sm64
	mario.Velocity = Vector3.zero
	mario.FaceAngle = Vector3int16.new()

	mario:SetAction(Action.SPAWN_SPIN_AIRBORNE)
end

local function getWaterLevel(pos: Vector3)
	local terrain = workspace.Terrain
	local voxelPos = terrain:WorldToCellPreferSolid(pos)

	local voxelRegion = Region3.new(voxelPos * 4, (voxelPos + Vector3.one + (Vector3.yAxis * 3)) * 4)
	voxelRegion = voxelRegion:ExpandToGrid(4)

	local materials, occupancies = terrain:ReadVoxels(voxelRegion, 4)
	local size: Vector3 = occupancies.Size
	local waterLevel = -11000

	for y = 1, size.Y do
		local occupancy = occupancies[1][y][1]
		local material = materials[1][y][1]

		if occupancy >= 0.9 and material == Enum.Material.Water then
			local top = ((voxelPos.Y * 4) + (4 * y + 2))
			waterLevel = math.max(waterLevel, top / Util.Scale)
		end
	end

	return waterLevel
end

local function update(dt: number)
	local character = player.Character

	if not character then
		return
	end

	local now = os.clock()
	local dt = math.min(dt, 0.1)
	local gfxRot = CFrame.identity
	local scale = character:GetScale()

	if scale ~= activeScale then
		local marioPos = Util.ToRoblox(mario.Position)
		Util.Scale = scale / 20 -- HACK! Should this be instanced?

		mario.Position = Util.ToSM64(marioPos)
		activeScale = scale
	end

	-- Disabled for now because this causes parallel universes to break.
	-- TODO: Find a better way to do two-way syncing between these values.

	-- local pos = character:GetPivot().Position
	-- local dist = (Util.ToRoblox(mario.Position) - pos).Magnitude

	-- if dist > (scale * 20)  then
	-- 	mario.Position = Util.ToSM64(pos)
	-- end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local simSpeed = tonumber(character:GetAttribute("TimeScale") or nil) or 1

	local robloxPos = Util.ToRoblox(mario.Position)
	mario.WaterLevel = getWaterLevel(robloxPos)
	Util.DebugWater(mario.WaterLevel)
	Util.DebugCollisionFaces(mario.Wall, mario.Ceil, mario.Floor)

	subframe += (now - lastUpdate) * (STEP_RATE * simSpeed)
	lastUpdate = now

	if character:GetAttribute("WingCap") or Core:GetAttribute("WingCap") then
		mario.Flags:Add(MarioFlags.WING_CAP)
	else
		mario.Flags:Remove(MarioFlags.WING_CAP)
	end

	if character:GetAttribute("Metal") then
		mario.Flags:Add(MarioFlags.METAL_CAP)
	else
		mario.Flags:Remove(MarioFlags.METAL_CAP)
	end

	subframe = math.min(subframe, 4) -- Prevent execution runoff

	while subframe >= 1 do
		subframe -= 1
		updateCollisions()

		updateController(mario.Controller, humanoid)
		mario:ExecuteAction()

		local gfxPosOffset = Util.ToRoblox(mario.GfxPos)
		local gfxPos = Util.ToRoblox(mario.Position) + gfxPosOffset
		gfxRot = Util.ToRotation(mario.GfxAngle)

		if humanoid then
			humanoid.CameraOffset = humanoid.CameraOffset:Lerp(-gfxPosOffset, dt * 16)
		end

		mario.GfxPos = Vector3.zero
		mario.GfxAngle = Vector3int16.new()

		prevCF = goalCF
		goalCF = CFrame.new(gfxPos) * FLIP * gfxRot
	end

	if character and goalCF then
		local cf = character:GetPivot()
		local rootPart = character.PrimaryPart
		local animator = character:FindFirstChildWhichIsA("Animator", true)

		if animator and (mario.AnimDirty or mario.AnimReset) and mario.AnimFrame >= 0 then
			local anim = mario.AnimCurrent
			local animSpeed = 0.1 / simSpeed

			if activeTrack and (activeTrack.Animation ~= anim or mario.AnimReset) then
				if tostring(activeTrack.Animation) == "TURNING_PART1" then
					if anim and anim.Name == "TURNING_PART2" then
						mario.AnimSkipInterp = 2
						animSpeed *= 2
					end
				end

				activeTrack:Stop(animSpeed)
				activeTrack = nil
			end

			if not activeTrack and anim then
				if anim.AnimationId == "" then
					if RunService:IsStudio() then
						warn("!! FIXME: Empty AnimationId for", anim.Name, "will break in live games!")
					end

					anim.AnimationId = emptyId
				end

				local track = loadedAnims[anim.Name] or animator:LoadAnimation(anim)
				track:Play(animSpeed, 1, 0)
				activeTrack = track

				if loadedAnims[anim.Name] == nil then
					loadedAnims[anim.Name] = track
				end
			end

			if activeTrack then
				local speed = mario.AnimAccel / 0x10000

				if speed > 0 then
					activeTrack:AdjustSpeed(speed * simSpeed)
				else
					activeTrack:AdjustSpeed(simSpeed)
				end
			end

			mario.AnimDirty = false
			mario.AnimReset = false
		end

		if activeTrack and mario.AnimSetFrame > -1 then
			activeTrack.TimePosition = mario.AnimSetFrame / STEP_RATE
			mario.AnimSetFrame = -1
		end

		if rootPart then
			local particles = rootPart:FindFirstChild("Particles")
			local alignPos = rootPart:FindFirstChildOfClass("AlignPosition")
			local alignCF = rootPart:FindFirstChildOfClass("AlignOrientation")

			local actionId = mario.Action()
			local throw = mario.ThrowMatrix

			local health = bit32.rshift(mario.Health, 8)

			if throw then
				local throwPos = Util.ToRoblox(throw.Position)
				goalCF = throw.Rotation * FLIP + throwPos
			end

			if alignCF then
				local nextCF = prevCF:Lerp(goalCF, subframe)

				-- stylua: ignore
				cf = if mario.AnimSkipInterp > 0
					then cf.Rotation + nextCF.Position
					else nextCF

				alignCF.CFrame = cf.Rotation
			end

			local isDebug = character:GetAttribute("Debug")
			local limits = character:GetAttribute("EmulateLimits")

			script.Util:SetAttribute("Debug", isDebug)
			debugStats.Value = isDebug

			if limits ~= nil then
				Core:SetAttribute("TruncateBounds", limits)
			end

			if isDebug then
				local animName = activeTrack and tostring(activeTrack.Animation)
				setDebugStat("Animation", animName)

				local actionName = Enums.GetName(Action, actionId)
				setDebugStat("Action", actionName)

				local wall = mario.Wall
				setDebugStat("Wall", wall and wall.Instance.Name or NULL_TEXT)

				local floor = mario.Floor
				local floorType = floor and ` (SurfaceClass.{Enums.GetName(SurfaceClass, mario:GetFloorType())})` or ""
				setDebugStat("Floor", floor and floor.Instance.Name .. floorType or NULL_TEXT)

				local ceil = mario.Ceil
				local ceilType = ceil and ` (SurfaceClass.{Enums.GetName(SurfaceClass, mario:GetCeilType())})` or ""
				setDebugStat("Ceiling", ceil and ceil.Instance.Name .. ceilType or NULL_TEXT)

				setDebugStat(
					"Health",
					`{health} ({string.format("0x%X", mario.Health)}, {mario.Health}) (INC {mario.HealCounter} | DEC {mario.HurtCounter})`
				)

				setDebugStat("SquishTimer", mario.SquishTimer)
			end

			for _, name in AUTO_STATS do
				local value = rawget(mario :: any, name)
				setDebugStat(name, value)
			end

			if alignPos then
				alignPos.Position = cf.Position
			end

			local bodyState = mario.BodyState
			local headAngle = bodyState.HeadAngle
			local torsoAngle = bodyState.TorsoAngle

			if actionId ~= Action.BUTT_SLIDE and actionId ~= Action.WALKING then
				bodyState.TorsoAngle *= 0
			end

			if torsoAngle ~= lastTorsoAngle then
				networkDispatch("SetTorsoAngle", torsoAngle)
				lastTorsoAngle = torsoAngle
			end

			if headAngle ~= lastHeadAngle then
				networkDispatch("SetHeadAngle", headAngle)
				lastHeadAngle = headAngle
			end

			if health ~= lastHealth then
				networkDispatch("SetHealth", health)
				lastHealth = health
			end

			if particles then
				for name, flag in pairs(ParticleFlags) do
					local inst = particles:FindFirstChild(name, true)

					if inst and PARTICLE_CLASSES[inst.ClassName] then
						local particle = inst :: ParticleEmitter
						local emit = particle:GetAttribute("Emit")
						local hasFlag = mario.ParticleFlags:Has(flag)

						if emit then
							if hasFlag then
								networkDispatch("SetParticle", name)
							end
						elseif particle.Enabled ~= hasFlag then
							networkDispatch("SetParticle", name, hasFlag)
						end
					end
				end
			end

			for name: string, sound: Sound in pairs(Sounds) do
				local looped = false

				if sound:IsA("Sound") then
					if sound.TimeLength == 0 then
						continue
					end

					looped = sound.Looped
				end

				if sound:GetAttribute("Play") then
					networkDispatch("PlaySound", sound.Name)

					if not looped then
						sound:SetAttribute("Play", false)
					end
				elseif looped then
					sound:Stop()
				end
			end

			character:PivotTo(cf)
		end
	end
end

reset.Event:Connect(onReset)
RunService.Heartbeat:Connect(update)
shared.LocalMario = mario

while task.wait(1) do
	local success = pcall(function()
		return StarterGui:SetCore("ResetButtonCallback", reset)
	end)

	if success then
		break
	end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
