--!strict
local Validators: { [string]: (Player, ...any) -> boolean } = {}
type Echo = () -> ()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Core = script.Parent.Parent

local Shared = require(Core.Shared)
local Sounds = Shared.Sounds

local lazy = Instance.new("RemoteEvent")
lazy.Parent = ReplicatedStorage
lazy.Name = "LazyNetwork"
lazy.Archivable = false

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
	local rootPart = character and character.PrimaryPart

	if rootPart then
		local particles = rootPart:FindFirstChild("Particles")
		local particle = particles and particles:FindFirstChild(name, true)

		if particle then
			return true
		end
	end

	return false
end

function Validators.SetTorsoAngle(player: Player, angle: Vector3int16)
	return typeof(angle) == "Vector3int16"
end

function Validators.SetHeadAngle(player: Player, angle: Vector3int16)
	return typeof(angle) == "Vector3int16"
end

function Validators.SetHealth(player: Player, health: number)
	return typeof(health) == "number" and (health > 0 and health < 8)
end

local function onNetworkReceive(player: Player, cmd: string, ...)
	local validate = Validators[cmd]

	if validate and validate(player, ...) then
		lazy:FireAllClients(player, cmd, ...)
	end
end

lazy.OnServerEvent:Connect(onNetworkReceive)
