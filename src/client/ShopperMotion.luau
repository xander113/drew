local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AvatarPreview = require(script.Parent.AvatarPreview)
local Spacing = require(ReplicatedStorage:WaitForChild("CartCatcher").ShopperSpacing)

local ShopperMotion = {}
local TAG = "WWMSShopper"

function ShopperMotion.start()
	local actors = {}
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "WWMS Shopper Display", Workspace

	local function show(model)
		if not model:HasTag(TAG) or not model:IsDescendantOf(Workspace) or not model.PrimaryPart then return end
		local actor = actors[model]
		local display = AvatarPreview.clone(model, nil)
		if not display then return end
		display:PivotTo(if actor then actor.frame else model:GetPivot())
		if actor then
			actor.display:Destroy()
		else
			actor = { frame = model:GetPivot(), stride = 0, pace = 0 }
			actors[model] = actor
			actor.appearance = model.DescendantAdded:Connect(function(child)
				if child:IsA("Accessory") or child:IsA("Shirt") or child:IsA("Pants") or child:IsA("Decal") then task.defer(show, model) end
			end)
		end
		actor.display, actor.limbs = display, {}
		for _, limb in { "Left Arm", "Right Arm", "Left Leg", "Right Leg" } do
			local part = display:FindFirstChild(limb)
			if part then
				local phase = if limb == "Right Arm" or limb == "Left Leg" then 1 else -1
				table.insert(actor.limbs, { part = part, phase = phase, rest = actor.frame:ToObjectSpace(part.CFrame) })
			end
		end
		for _, piece in model:GetDescendants() do
			if piece:IsA("BasePart") then piece.LocalTransparencyModifier = 1 end
		end
		local position = actor.frame.Position
		if actor.position or Spacing.clear(position, position, actors, actor) then
			actor.position, display.Parent = position, folder
		end
	end

	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(model)
		-- The tag can arrive before the model's primary part.
		task.spawn(function()
			local root = model:WaitForChild("HumanoidRootPart", 5)
			if root then
				if model.PrimaryPart then show(model) else task.delay(.15, show, model) end
			end
		end)
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(model)
		local actor = actors[model]
		if actor then
			actor.appearance:Disconnect()
			actor.display:Destroy()
			actors[model] = nil
		end
	end)
	for _, model in CollectionService:GetTagged(TAG) do show(model) end

	RunService.RenderStepped:Connect(function(dt)
		local camera = Workspace.CurrentCamera
		if not camera then return end
		local weight = 1 - math.exp(-19 * dt)
		for model, actor in actors do
			if not model.PrimaryPart or not model.Parent then continue end
			local target = model:GetPivot()
			if not actor.position then
				if not Spacing.clear(target.Position, target.Position, actors, actor) then continue end
				actor.frame, actor.position, actor.display.Parent = target, target.Position, folder
			end
			if (target.Position - camera.CFrame.Position).Magnitude > 175 then
				if target ~= actor.frame and Spacing.clear(target.Position, target.Position, actors, actor) then
					actor.frame, actor.position = target, target.Position
					actor.display:PivotTo(target)
				end
				continue
			end
			local move = target.Position - actor.frame.Position
			local previous = actor.frame
			local nextFrame = if move.Magnitude > 16 then target else previous:Lerp(target, weight)
			if nextFrame.Position == actor.position or Spacing.clear(actor.position, nextFrame.Position, actors, actor) then
				actor.frame, actor.position = nextFrame, nextFrame.Position
			else
				actor.frame = CFrame.new(actor.position) * nextFrame.Rotation
			end
			local travel = (actor.frame.Position - previous.Position).Magnitude
			local pace = math.clamp(travel / math.max(dt * 6, .001), 0, 1)
			actor.pace += (pace - actor.pace) * weight
			actor.stride += travel * 2.15
			actor.display:PivotTo(actor.frame)
			local swing = math.sin(actor.stride) * actor.pace * .49
			for _, limb in actor.limbs do
				limb.part.CFrame = actor.frame * CFrame.new(limb.rest.Position + Vector3.new(0, .67, 0))
					* CFrame.Angles(swing * limb.phase, 0, 0) * CFrame.new(0, -.67, 0) * limb.rest.Rotation
			end
		end
	end)
end

return ShopperMotion
