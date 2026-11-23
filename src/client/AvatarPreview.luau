local AvatarPreview = {}

function AvatarPreview.clone(source, parent)
	if not source or not source.PrimaryPart then return nil end
	local archivable = source.Archivable
	source.Archivable = true
	local copy = source:Clone()
	source.Archivable = archivable
	for _, object in copy:GetDescendants() do
		if object:IsA("BasePart") then
			object.Anchored, object.CanCollide, object.CanTouch, object.CanQuery = true, false, false, false
			object.LocalTransparencyModifier = 0
		elseif object:IsA("BaseScript") or object:IsA("BillboardGui") or object:IsA("Highlight") or object:IsA("Tool") then
			object:Destroy()
		elseif object:IsA("Humanoid") then
			object.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			object.EvaluateStateMachine = false
		end
	end
	copy:RemoveTag("WWMSShopper")
	copy:PivotTo(CFrame.new())
	copy.Parent = parent
	return copy
end

return AvatarPreview
