return function(roblox, name, tint)
	local new, v, cf = roblox.Instance.new, roblox.Vector3.new, roblox.CFrame
	local rgb, enum = roblox.Color3.fromRGB, roblox.Enum
	local crew = tint or rgb(0, 99, 226)
	local skin = rgb(227, 171, 125)
	local model = new("Model")
	model.Name = name

	local function part(partName, size, at, color, collision)
		local object = new("Part")
		object.Name, object.Size, object.CFrame, object.Color = partName, size, cf.new(at), color
		object.TopSurface, object.BottomSurface = enum.SurfaceType.Smooth, enum.SurfaceType.Smooth
		object.CanCollide = collision
		object.Parent = model
		return object
	end

	local root = part("HumanoidRootPart", v(2, 2, 1), v(0, 3, 0), crew, false)
	root.Transparency, root.RootPriority = 1, 127
	model.PrimaryPart = root
	local torso = part("Torso", v(2, 2, 1), v(0, 3, 0), crew, true)
	local head = part("Head", v(2, 1, 1), v(0, 4.5, 0), skin, true)
	local leftArm = part("Left Arm", v(1, 2, 1), v(-1.5, 3, 0), skin, false)
	local rightArm = part("Right Arm", v(1, 2, 1), v(1.5, 3, 0), skin, false)
	local shoes = rgb(23, 49, 89)
	local leftLeg = part("Left Leg", v(1, 2, 1), v(-.5, 1, 0), shoes, false)
	local rightLeg = part("Right Leg", v(1, 2, 1), v(.5, 1, 0), shoes, false)
	local mesh = new("SpecialMesh")
	mesh.MeshType, mesh.Scale, mesh.Parent = enum.MeshType.Head, v(1.25, 1.25, 1.25), head
	local face = new("Decal")
	face.Name, face.Face, face.Texture = "face", enum.NormalId.Front, "rbxasset://textures/face.png"
	face.Parent = head
	local headAttachment = new("Attachment")
	headAttachment.Name, headAttachment.Position, headAttachment.Parent = "HatAttachment", v(0, .6, 0), head
	local hairAttachment = new("Attachment")
	hairAttachment.Name, hairAttachment.Position, hairAttachment.Parent = "HairAttachment", v(0, .6, 0), head
	local faceAttachment = new("Attachment")
	faceAttachment.Name, faceAttachment.Position, faceAttachment.Parent = "FaceFrontAttachment", v(0, 0, -.6), head

	local function joint(jointName, a, b, c0, c1)
		local motor = new("Motor6D")
		motor.Name, motor.Part0, motor.Part1 = jointName, a, b
		motor.C0, motor.C1, motor.Parent = c0, c1, a
	end
	local upright = cf.Angles(-math.pi / 2, 0, math.pi)
	local left = cf.Angles(0, -math.pi / 2, 0)
	local right = cf.Angles(0, math.pi / 2, 0)
	joint("RootJoint", root, torso, upright, upright)
	joint("Neck", torso, head, cf.new(0, 1, 0) * upright, cf.new(0, -.5, 0) * upright)
	joint("Left Shoulder", torso, leftArm, cf.new(-1, .5, 0) * left, cf.new(.5, .5, 0) * left)
	joint("Right Shoulder", torso, rightArm, cf.new(1, .5, 0) * right, cf.new(-.5, .5, 0) * right)
	joint("Left Hip", torso, leftLeg, cf.new(-1, -1, 0) * left, cf.new(-.5, 1, 0) * left)
	joint("Right Hip", torso, rightLeg, cf.new(1, -1, 0) * right, cf.new(.5, 1, 0) * right)

	local humanoid = new("Humanoid")
	humanoid.Name, humanoid.RigType, humanoid.HipHeight = "Humanoid", enum.HumanoidRigType.R6, 0
	humanoid.Parent = model
	local animator = new("Animator")
	animator.Parent = humanoid
	return model
end
