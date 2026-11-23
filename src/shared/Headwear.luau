local Headwear = {}

function Headwear.fit(character, accessory, role, engine)
	local head = character:FindFirstChild("Head")
	local handle = accessory:FindFirstChild("Handle")
	local name = role .. "Attachment"
	local socket = head and head:FindFirstChild(name)
	local mount = handle and handle:FindFirstChild(name)
	assert(head and socket and handle and mount, "WWMS headwear needs matching R6 scalp attachments")
	local part0Offset, part1Offset = socket.CFrame, mount.CFrame
	handle.Anchored, handle.CanCollide, handle.CanTouch, handle.CanQuery, handle.Massless = false, false, false, false, true

	local previous = handle:FindFirstChild("AccessoryWeld")
	if previous then previous:Destroy() end
	-- Pose before parenting so a client can immediately copy the visible rig.
	handle.CFrame = head.CFrame * part0Offset * part1Offset:Inverse()
	local weld = engine.Instance.new("Weld")
	weld.Name, weld.Part0, weld.Part1 = "AccessoryWeld", head, handle
	weld.C0, weld.C1, weld.Parent = part0Offset, part1Offset, handle
	accessory.Parent = character
end

return table.freeze(Headwear)
