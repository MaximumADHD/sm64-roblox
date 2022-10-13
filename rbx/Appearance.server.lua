--!strict
local Players = game:GetService("Players")

local character: any = script.Parent
local player = Players:GetPlayerFromCharacter(character)

if not player then
	return
end

local userId = player.UserId
local hDesc: HumanoidDescription?

local function patchCollision(desc: Instance)
	if desc:IsA("BasePart") and desc.CollisionGroupId ~= 1 then
		local canCollide = desc:GetPropertyChangedSignal("CanCollide")
		desc.CollisionGroup = "Player"
		desc.CanQuery = false
		desc.CanTouch = false
		desc.Massless = true

		canCollide:Connect(function()
			desc.CanCollide = false
		end)

		desc.CanCollide = false
	end
end

local function patchAllCollision()
	for i, desc in character:GetDescendants() do
		task.spawn(patchCollision, desc)
	end
end

task.spawn(patchAllCollision)
character.DescendantAdded:Connect(patchCollision)

local function reload()
	for retry = 1, 10 do
		local success, result = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(userId)
		end)

		if success then
			hDesc = result
			break
		else
			task.wait(retry / 2)
		end
	end

	if hDesc then
		hDesc.HeadScale = 1.8
		hDesc.WidthScale = 1.3
		hDesc.DepthScale = 1.4
		hDesc.HeightScale = 1.2
		hDesc.BodyTypeScale = 0
		hDesc.ProportionScale = 0
	else
		return
	end

	local humanoid = character:WaitForChild("Humanoid")
	assert(hDesc)

	if humanoid:IsA("Humanoid") then
		while not humanoid.RootPart do
			humanoid.Changed:Wait()
		end

		local rootPart = humanoid.RootPart
		assert(rootPart, "No HumanoidRootPart??")

		local particles = rootPart:FindFirstChild("Particles")
		humanoid:ApplyDescription(hDesc)

		if particles and particles:IsA("Attachment") then
			local floorDec = humanoid.HipHeight + (rootPart.Size.Y / 2)
			local pos = Vector3.new(0, -floorDec, 0)
			rootPart.PivotOffset = CFrame.new(pos)
			particles.Position = pos
		end
	end
end

local reset = Instance.new("RemoteEvent")
reset.Parent = character
reset.Name = "Reset"

reset.OnServerEvent:Connect(function(player)
	if player == Players:GetPlayerFromCharacter(character) then
		reload()
	end
end)

task.spawn(reload)
