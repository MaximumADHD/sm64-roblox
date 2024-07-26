--!strict

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local PhysicsService = game:GetService("PhysicsService")
local StarterCharacterScripts = StarterPlayer.StarterCharacterScripts

local hDesc = Instance.new("HumanoidDescription")
hDesc.HeightScale = 1.3
hDesc.WidthScale = 1.3
hDesc.DepthScale = 1.4
hDesc.HeadScale = 2

local character = Players:CreateHumanoidModelFromDescription(hDesc, Enum.HumanoidRigType.R15)
local bodyColors = character:FindFirstChildOfClass("BodyColors")
local animate = character:FindFirstChild("Animate")
local oldRoot = character.PrimaryPart

if animate then
	animate:Destroy()
end

if oldRoot then
	oldRoot:Destroy()
end

if bodyColors then
	bodyColors:Destroy()
end

local newRoot = script.HumanoidRootPart
newRoot.Parent = character :: any
newRoot.Anchored = false

local humanoid = assert(character:FindFirstChildOfClass("Humanoid"))
humanoid:BuildRigFromAttachments()

local dummyScripts = {
	"Animate",
	"Health",
	"Sound",
}

for _, dummy in dummyScripts do
	local stub = Instance.new("Hole", StarterCharacterScripts)
	stub.Name = dummy
end

for _, child in script:GetChildren() do
	child.Parent = StarterCharacterScripts

	if child:IsA("Script") then
		child.Disabled = false
	end
end

character.Name = "StarterCharacter"
character.PrimaryPart = newRoot
character.Parent = StarterPlayer

PhysicsService:RegisterCollisionGroup("Player")
PhysicsService:CollisionGroupSetCollidable("Default", "Player", false)

for _, player in Players:GetPlayers() do
	task.spawn(player.LoadCharacter, player)
end
