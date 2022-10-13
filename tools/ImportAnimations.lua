local AvatarImportService = game:GetService("AvatarImportService")
local resume = Instance.new("BindableEvent")

for i, anim in pairs(game.ReplicatedFirst.SM64.Assets.Animations:GetChildren()) do
	local path = "C:/Users/clone/Desktop/MarioAnims/" .. anim.Name .. ".fbx"
	print("Importing", anim)

	task.defer(function()
		local success, err = pcall(function()
			AvatarImportService:ImportFBXAnimationFromFilePathUserMayChooseModel(path, workspace.Mario, function()
				local bin = game.ServerStorage.AnimSaves
				local old = bin:FindFirstChild(anim.Name)

				if old then
					old:Destroy()
				end

				local kfs = AvatarImportService:ImportLoadedFBXAnimation(false)
				kfs.Name = anim.Name
				kfs.Parent = bin

				resume:Fire()
			end)
		end)

		if not success then
			warn("ERROR IMPORTING", anim, err)
			resume:Fire()
		end
	end)

	resume.Event:Wait()
end
