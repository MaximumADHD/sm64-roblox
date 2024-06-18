--!strict
local Players = game:GetService("Players")

local character: Instance = assert(script.Parent)
assert(character:IsA("Model"), "Not a character")

local player = Players:GetPlayerFromCharacter(character)
assert(player, "No player!")

local userId = player.UserId
local hDesc: HumanoidDescription?

local metalPointers = {} :: {
	[MeshPart]: {
		Metal: SurfaceAppearance?,
	},
}

local function updateMetal(part: MeshPart)
	local isMetal = character:GetAttribute("Metal")
	local ptr = metalPointers[part]

	if ptr == nil then
		ptr = {}
		metalPointers[part] = ptr
	end

	if isMetal and not ptr.Metal then
		local surface = script.METAL_MARIO:Clone()
		surface.Parent = part
		ptr.Metal = surface
	elseif ptr.Metal and not isMetal then
		ptr.Metal:Destroy()
		ptr.Metal = nil
	end
end

local function onMetalChanged()
	for meshPart in metalPointers do
		updateMetal(meshPart)
	end
end

local function onDescendantAdded(desc: Instance)
	if desc:IsA("BasePart") then
		if desc.CollisionGroup ~= "Player" then
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

		if desc:IsA("MeshPart") then
			updateMetal(desc)
		end
	end
end

local function onDescendantRemoving(desc: Instance)
	if desc:IsA("MeshPart") then
		metalPointers[desc] = nil
	end
end

local metalListener = character:GetAttributeChangedSignal("Metal")
metalListener:Connect(onMetalChanged)

for i, desc in character:GetDescendants() do
	task.spawn(onDescendantAdded, desc)
end

character:SetAttribute("TimeScale", 1)
character.DescendantAdded:Connect(onDescendantAdded)
character.DescendantRemoving:Connect(onDescendantRemoving)

local function reload()
	character:ScaleTo(1)

	task.spawn(function()
		for i = 1, 5 do
			character:PivotTo(CFrame.new(0, 100, 0))
			task.wait()
		end
	end)

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
		-- changed to 1 cuz i didnt like it SORRY :()
		hDesc.HeadScale = 1
		hDesc.WidthScale = 1
		hDesc.DepthScale = 1
		hDesc.HeightScale = 1
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
