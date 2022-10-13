--!strict

local PhysicsService = game:GetService("PhysicsService")
local StarterPlayer = game:GetService("StarterPlayer")
local Players = game:GetService("Players")

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

local newRoot = script.HumanoidRootPart:Clone()
newRoot.Parent = character :: any

local humanoid = assert(character:FindFirstChildOfClass("Humanoid"))
humanoid:BuildRigFromAttachments()

character.Name = "StarterCharacter"
character.PrimaryPart = newRoot
character.Parent = StarterPlayer

PhysicsService:CreateCollisionGroup("Player")
PhysicsService:CollisionGroupSetCollidable("Default", "Player", false)
