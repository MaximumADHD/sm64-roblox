-- This script was written (quite rigidly) for use in the provided RetargetAnimations.rbxl place.
-- KeyframeSequences are not provided as mentioned in the README, you'll have to extract them yourself :)

--!strict
local ServerStorage = game:GetService("ServerStorage")
local StarterCharacter = workspace.StarterCharacter

local MarioAnim = workspace.MarioAnim
local MarioBase = workspace.MarioBase
local Player = workspace.Player

local HIERARCHY: { [string]: { [string]: string }? } = {
	HumanoidRootPart = { LowerTorso = "Root" },

	LowerTorso = {
		UpperTorso = "Waist",
		LeftUpperLeg = "LeftHip",
		RightUpperLeg = "RightHip",
	},

	UpperTorso = {
		Head = "Neck",
		LeftUpperArm = "LeftShoulder",
		RightUpperArm = "RightShoulder",
	},

	LeftUpperArm = { LeftLowerArm = "LeftElbow" },
	LeftLowerArm = { LeftHand = "LeftWrist" },

	RightUpperArm = { RightLowerArm = "RightElbow" },
	RightLowerArm = { RightHand = "RightWrist" },

	LeftUpperLeg = { LeftLowerLeg = "LeftKnee" },
	LeftLowerLeg = { LeftFoot = "LeftAnkle" },

	RightUpperLeg = { RightLowerLeg = "RightKnee" },
	RightLowerLeg = { RightFoot = "RightAnkle" },
}

local BASE_KEYFRAME = ServerStorage.BASE_KEYFRAME

local statusHint = Instance.new("Hint")
local statusText = "%s [%d/%d]"
statusHint.Parent = workspace
statusHint.Name = "Status"

local function updateAnim()
	StarterCharacter.Humanoid.Animator:StepAnimations(0)
	Player.Humanoid.Animator:StepAnimations(0)
	task.wait()
end

local function clearAnims()
	for i, desc: Instance in pairs(workspace:GetDescendants()) do
		if desc:IsA("Bone") then
			desc.Transform = CFrame.identity
		elseif desc:IsA("Motor6D") then
			desc.Transform = CFrame.identity
		elseif desc:IsA("Animator") then
			task.defer(desc.StepAnimations, desc, 0)
		end
	end

	task.wait()
end

local function applyMotors(at: Instance)
	local name0 = if at:IsA("Keyframe") then "HumanoidRootPart" else at.Name
	local part0 = StarterCharacter:FindFirstChild(name0)
	local data = HIERARCHY[name0]

	if data and part0 and part0:IsA("BasePart") then
		for name1, motorName in data do
			local part1 = StarterCharacter:FindFirstChild(name1)

			if part1 and part1:IsA("BasePart") then
				local att: Attachment = part1:FindFirstChild(motorName .. "RigAttachment")
				local bone: Bone = MarioBase:FindFirstChild(motorName, true)

				local motor: Motor6D = part1:FindFirstChild(motorName)
				motor.Transform = att.WorldCFrame:ToObjectSpace(bone.TransformedWorldCFrame)

				local playerMotor = workspace.Player:FindFirstChild(motorName, true)
				local pose = at:FindFirstChild(name1)

				if playerMotor and playerMotor:IsA("Motor6D") then
					if motorName:find("Left") or motorName:find("Right") then
						playerMotor.Transform = motor.Transform.Rotation
					else
						playerMotor.Transform = motor.Transform
					end
				end

				updateAnim()

				if pose and pose:IsA("Pose") then
					if motorName:find("Left") or motorName:find("Right") then
						pose.CFrame = motor.Transform.Rotation
					else
						pose.CFrame = motor.Transform
					end

					applyMotors(pose)
				end
			end
		end
	end
end

local function remapKeyframe(keyframe: Keyframe): Keyframe
	clearAnims()

	for i, desc: Instance in pairs(keyframe:GetDescendants()) do
		if desc:IsA("Pose") then
			local bone: Instance? = MarioAnim:FindFirstChild(desc.Name, true)

			if bone and bone:IsA("Bone") then
				bone.Transform = desc.CFrame
			end
		end
	end

	for i, desc in MarioBase:GetDescendants() do
		if desc:IsA("Bone") then
			local anim = MarioAnim:FindFirstChild(desc.Name, true)

			if anim then
				local offset = desc.TransformedWorldCFrame:ToObjectSpace(anim.TransformedWorldCFrame)
				desc.Transform = offset
			end
		end
	end

	local newKeyframe = BASE_KEYFRAME:Clone()
	newKeyframe.Name = keyframe.Name
	newKeyframe.Time = keyframe.Time
	applyMotors(newKeyframe)

	return newKeyframe
end

local function remapKeyframeSequence(kfs: KeyframeSequence): KeyframeSequence
	local keyframes = kfs:GetKeyframes()
	clearAnims()

	local newKfs = kfs:Clone()
	newKfs:ClearAllChildren()

	for i, keyframe in keyframes do
		if keyframe:IsA("Keyframe") then
			local text = statusText:format(kfs.Name, i, #keyframes)
			statusHint.Text = text

			local newKeyframe = remapKeyframe(keyframe)
			newKeyframe.Parent = newKfs
		end
	end

	return newKfs
end

local animSaves = ServerStorage.AnimSaves:GetChildren()
local animSavesR15 = ServerStorage.AnimSaves_R15

table.sort(animSaves, function(a, b)
	return a.Name < b.Name
end)

for i, animSave in animSaves do
	if animSave:IsA("KeyframeSequence") then
		local kfs = remapKeyframeSequence(animSave)
		kfs.Parent = animSavesR15
	end
end

clearAnims()
statusHint:Destroy()
