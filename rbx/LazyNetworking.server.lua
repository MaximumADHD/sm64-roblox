--!strict
local Validators: { [string]: (Player, ...any) -> boolean } = {}
type Echo = () -> ()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local PhysicsService = game:GetService("PhysicsService")
local Sounds = require(ReplicatedFirst.SM64.Sounds)

local lazy = Instance.new("RemoteEvent")
lazy.Parent = ReplicatedStorage
lazy.Name = "LazyNetwork"

function Validators.PlaySound(player: Player, name: string)
	local sound: Instance? = Sounds[name]

	if sound and sound:IsA("Sound") then
		return true
	end

	return false
end

function Validators.SetParticle(player: Player, name: string, set: boolean?)
	if typeof(name) ~= "string" then
		return false
	end

	local character = player.Character
	
	-- stylua: ignore
	local rootPart = if character
		then character.PrimaryPart
		else nil

	if rootPart then
		local particles = rootPart:FindFirstChild("Particles")
		
		-- stylua: ignore
		local particle = if particles
			then particles:FindFirstChild(name)
			else nil

		if particle then
			return true
		end
	end

	return false
end

function Validators.SetAngle(player: Player, angle: Vector3int16)
	return typeof(angle) == "Vector3int16"
end

local function onNetworkReceive(player: Player, cmd: string, ...)
	local validate = Validators[cmd]

	if validate and validate(player, ...) then
		lazy:FireAllClients(player, cmd, ...)
	end
end

lazy.OnServerEvent:Connect(onNetworkReceive)
