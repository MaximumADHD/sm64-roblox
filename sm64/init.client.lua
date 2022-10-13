--!strict

local Players = game:GetService("Players") :: Players
local RunService = game:GetService("RunService") :: RunService
local StarterGui = game:GetService("StarterGui") :: StarterGui
local TweenService = game:GetService("TweenService") :: TweenService
local UserInputService = game:GetService("UserInputService") :: UserInputService
local ReplicatedStorage = game:GetService("ReplicatedStorage") :: ReplicatedStorage
local ContextActionService = game:GetService("ContextActionService") :: ContextActionService

local Sounds = require(script.Sounds)
local Enums = require(script.Enums)
local Mario = require(script.Mario)
local Types = require(script.Types)
local Util = require(script.Util)

local Action = Enums.Action
local Buttons = Enums.Buttons
local InputFlags = Enums.InputFlags
local ParticleFlags = Enums.ParticleFlags

type InputType = Enum.UserInputType | Enum.KeyCode
type Controller = Types.Controller
type Mario = Mario.Class

local player: Player = assert(Players.LocalPlayer)
local STEP_RATE = 30

local PARTICLE_CLASSES = {
	Fire = true,
	Smoke = true,
	Sparkles = true,
	ParticleEmitter = true,
}

local FLIP = CFrame.Angles(0, math.pi, 0)

-------------------------------------------------------------------------------------------------------------------------------------------------
-- Input Driver
-------------------------------------------------------------------------------------------------------------------------------------------------

local MATH_TAU = math.pi * 2
local BUTTON_FEED: { Enum.UserInputState } = {}
local BUTTON_A = "BTN_" .. Buttons.A_BUTTON

local function toStrictNumber(str: string): number
	local result = tonumber(str)
	return assert(result, "Invalid number!")
end

local function processAction(id: string, state: Enum.UserInputState)
	if id == "MarioDebug" then
		if state == Enum.UserInputState.Begin then
			local isDebug = not script.Util:GetAttribute("Debug")
			local character = player.Character

			local rootPart = if character then character.PrimaryPart else nil

			if rootPart then
				local action = rootPart:FindFirstChild("Action")

				if action and action:IsA("BillboardGui") then
					action.Enabled = isDebug
				end
			end

			script.Util:SetAttribute("Debug", isDebug)
		end
	else
		local button = toStrictNumber(id:sub(5))
		BUTTON_FEED[button] = state
	end
end

local function bindInput(button: number, label: string, ...: InputType)
	local id = "BTN_" .. button
	ContextActionService:BindAction(id, processAction, true, ...)

	if UserInputService.TouchEnabled then
		ContextActionService:SetTitle(id, label)
	end
end

local function updateCollisions()
	for i, player in Players:GetPlayers() do
		assert(player:IsA("Player"))

		local rootPart = if player.Character then player.Character.PrimaryPart else nil

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

local function updateController(controller: Controller, humanoid: Humanoid)
	local moveDir = humanoid.MoveDirection
	local pos = Vector2.new(moveDir.X, -moveDir.Z)
	local len = math.min(1, pos.Magnitude)

	controller.StickMag = len * 64
	controller.StickX = pos.X * 64
	controller.StickY = pos.Y * 64

	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	controller.ButtonPressed:Clear()

	if humanoid.Jump then
		BUTTON_FEED[Buttons.A_BUTTON] = Enum.UserInputState.Begin
		humanoid.Jump = false
	elseif controller.ButtonDown:Has(Buttons.A_BUTTON) then
		BUTTON_FEED[Buttons.A_BUTTON] = Enum.UserInputState.End
	end

	for button, state in pairs(BUTTON_FEED) do
		if state == Enum.UserInputState.Begin then
			controller.ButtonDown:Add(button)
			controller.ButtonPressed:Add(button)
		elseif state == Enum.UserInputState.End then
			controller.ButtonDown:Remove(button)
		end
	end

	table.clear(BUTTON_FEED)
end

ContextActionService:BindAction("MarioDebug", processAction, false, Enum.KeyCode.P)
bindInput(Buttons.B_BUTTON, "B", Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonX)
bindInput(Buttons.Z_TRIG, "Z", Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL2)

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Network Dispatch
-------------------------------------------------------------------------------------------------------------------------------------------------------------

local Commands = {}

local lazyNetwork = ReplicatedStorage:WaitForChild("LazyNetwork")
assert(lazyNetwork:IsA("RemoteEvent"), "bad lazyNetwork!")

function Commands.PlaySound(player: Player, name: string)
	local sound: Sound? = Sounds[name]
	local character = player.Character

	local rootPart = if character then character.PrimaryPart else nil

	if rootPart and sound then
		local oldSound: Instance? = rootPart:FindFirstChild(name)

		if oldSound and oldSound:IsA("Sound") and name:find("MARIO") then
			oldSound.TimePosition = 0
		else
			local newSound: Sound = sound:Clone()
			newSound.Parent = rootPart
			newSound:Play()

			newSound.Ended:Connect(function()
				newSound:Destroy()
			end)
		end
	end
end

function Commands.SetParticle(player: Player, name: string, set: boolean)
	local character = player.Character

	local rootPart = if character then character.PrimaryPart else nil

	if rootPart then
		local particles = rootPart:FindFirstChild("Particles")

		local inst = if particles then particles:FindFirstChild(name) else nil

		if inst and PARTICLE_CLASSES[inst.ClassName] then
			local particle = inst :: ParticleEmitter
			local emit = particle:GetAttribute("Emit")

			if typeof(emit) == "number" then
				particle:Emit(emit)
			elseif set ~= nil then
				particle.Enabled = set
			end
		end
	end
end

function Commands.SetAngle(player: Player, angle: Vector3int16)
	local character = player.Character

	local waist = if character then character:FindFirstChild("Waist", true) else nil

	if waist and waist:IsA("Motor6D") then
		local props = { C1 = Util.ToRotation(-angle) + waist.C1.Position }
		local tween = TweenService:Create(waist, TweenInfo.new(0.1), props)
		tween:Play()
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
local lastAngle: Vector3int16?

local mario: Mario = Mario.new()
local controller = mario.Controller

local enumMap = {}
local goalCF: CFrame
local activeTrack: AnimationTrack?
local peakSpeed = 0

local reset = Instance.new("BindableEvent")
reset.Archivable = false
reset.Parent = script
reset.Name = "Reset"

while not player.Character do
	player.CharacterAdded:Wait()
end

local character = assert(player.Character)
local pivot = character:GetPivot().Position
mario.Position = Util.ToSM64(pivot)

local function onReset()
	local roblox = Vector3.yAxis * 100
	local sm64 = Util.ToSM64(roblox)
	local char = player.Character

	if char then
		local reset = char:FindFirstChild("Reset")
		local cf = CFrame.new(roblox)

		if reset and reset:IsA("RemoteEvent") then
			reset:FireServer()
		end

		char:PivotTo(cf)
	end

	mario.SlideVelX = 0
	mario.SlideVelZ = 0
	mario.ForwardVel = 0
	mario.IntendedYaw = 0

	mario.Position = sm64
	mario.Velocity = Vector3.zero
	mario.FaceAngle = Vector3int16.new()

	mario:SetAction(Action.SPAWN_SPIN_AIRBORNE)
end

local function update()
	local character = player.Character

	if not character then
		return
	end

	local now = os.clock()
	local gfxRot = CFrame.identity

	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil

	local simSpeed = tonumber(script:GetAttribute("TimeScale") or nil) or 1
	local frames = math.floor((now - lastUpdate) * (STEP_RATE * simSpeed))

	if frames > 0 and humanoid then
		lastUpdate = now
		updateCollisions()

		for i = 1, math.min(4, frames) do
			updateController(mario.Controller, humanoid)
			mario:ExecuteAction()
		end

		local pos = Util.ToRoblox(mario.Position)
		local rot = Util.ToRotation(mario.FaceAngle)

		gfxRot = Util.ToRotation(mario.GfxAngle)
		goalCF = CFrame.new(pos) * FLIP * gfxRot
	end

	local interp = math.min(1, simSpeed / 2)

	if character and goalCF then
		local cf = character:GetPivot()
		local rootPart = character.PrimaryPart
		local animator = character:FindFirstChildWhichIsA("Animator", true)

		if animator and (mario.AnimDirty or mario.AnimReset) and mario.AnimFrame >= 0 then
			local anim = mario.AnimCurrent
			local animSpeed = 0.1 / simSpeed

			if activeTrack and (activeTrack.Animation ~= anim or mario.AnimReset) then
				activeTrack:Stop(animSpeed)
				activeTrack = nil
			end

			if not activeTrack and anim then
				local track = animator:LoadAnimation(anim)
				track:Play(animSpeed, 1, 0)
				activeTrack = track
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
			local action = rootPart:FindFirstChild("Action")
			local particles = rootPart:FindFirstChild("Particles")
			local alignPos = rootPart:FindFirstChildOfClass("AlignPosition")
			local alignCF = rootPart:FindFirstChildOfClass("AlignOrientation")
			local throw = mario.ThrowMatrix

			if throw then
				local pos = Util.ToRoblox(throw.Position)
				goalCF = throw.Rotation * FLIP + pos
			end

			if alignCF then
				cf = cf:Lerp(goalCF, interp)
				alignCF.CFrame = cf.Rotation
			end

			local debugLabel = if action then action:FindFirstChildOfClass("TextLabel") else nil

			if debugLabel then
				local actionId = mario.Action()

				local anim = if activeTrack then activeTrack.Animation else nil

				local animName = if anim then anim.Name else nil

				local debugText = "Action: "
					.. Enums.GetName(Action, actionId)
					.. "\n"
					.. "Animation: "
					.. tostring(animName)
					.. "\n"
					.. "ForwardVel: "
					.. string.format("%.2f", mario.ForwardVel)

				debugLabel.Text = debugText
			end

			if alignPos then
				alignPos.Position = cf.Position
			end

			local bodyState = mario.BodyState
			local action = mario.Action()

			if action ~= Action.BUTT_SLIDE and action ~= Action.WALKING then
				bodyState.TorsoAngle *= 0
			end

			local ang = bodyState.TorsoAngle

			if ang ~= lastAngle then
				networkDispatch("SetAngle", ang)
				lastAngle = ang
			end

			if particles then
				for name, flag in pairs(ParticleFlags) do
					local inst = particles:FindFirstChild(name)

					if inst and PARTICLE_CLASSES[inst.ClassName] then
						local name = inst.Name
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

while task.wait(1) do
	local success = pcall(function()
		return StarterGui:SetCore("ResetButtonCallback", reset)
	end)

	if success then
		break
	end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
