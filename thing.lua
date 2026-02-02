local Settings = ...
	or { Collisions = false, Simulate_Physics_On_LocalPlayer_Only = false, ForceAllRigs = false, Only_Others = false }
-- ForceAllRigs is basically forcing the changes on all humanoids that it finds

--[[
	Originally Created by:
	'With love and lust from "V" / Ukiyo'

	Re-written & Optimized by:
	Deuces
]]

local function Load(Source, DebugName, ...)
	return loadstring(game:HttpGet(Source, true), DebugName)(...)
end

local SpringClass = Load(
	"https://raw.githubusercontent.com/megamiffidorjf2-collab/asdasdasdadasdadsadasd/refs/heads/main/Spring.lua",
	"Spring"
)
local FemaleRig = Load(
	"https://raw.githubusercontent.com/megamiffidorjf2-collab/asdasdasdadasdadsadasd/refs/heads/main/FemaleRig.luau",
	"FemaleRig",
	Settings.Collisions
)
local finder, globalcontainer =
	Load("https://raw.githubusercontent.com/lua-u/SomeHub/main/UniversalMethodFinder.luau", "UniversalMethodFinder")

finder({
	protgui = '(...):find("protect") and (...):find("gui") and not (...):find("un")',
})

local function RandomString()
	local randomarray = {}
	for i = 1, math.random(10, 20) do
		randomarray[i] = string.char(math.random(32, 126))
	end
	return table.concat(randomarray)
end
local function Protect(instance)
	instance.Name = RandomString()
	for _, desc in ipairs(instance:GetDescendants()) do -- not sure if its worth to protgui (it also works on instances not just guis)  every descendant as in documentation it says it protects "instance and all it's children" not descendants however, but I would assume it does. You could always add it below for extra security and execution-lag :) (Deuces)
		desc.Name = RandomString()
	end

	if globalcontainer.protgui and not (is_sirhurt_closure or (syn and DrawingImmediate)) then --sirhurt is retarded
		globalcontainer.protgui(instance)
	end
end

local function Weld(p0, p1)
	local weld = Instance.new("Weld")

	weld.Part0 = p0
	weld.Part1 = p1
	weld.Parent = p0
	return weld
end

local function DressUp(Model, NewModel)
	local Shirt, Pants = Model:FindFirstChildOfClass("Shirt"), Model:FindFirstChildOfClass("Pants")
	Shirt = Shirt and Shirt.ShirtTemplate
	Pants = Pants and Pants.PantsTemplate

	for _, desc in ipairs(NewModel:GetDescendants()) do
		if desc:IsA("Decal") then
			desc.Texture = (desc.Name == "Shirt" and Shirt or desc.Name == "Pants" and Pants or "")
		end
	end
end

local function ApplyRig(Model, R6)
	local Parts = {}
	if R6 then
		Parts.Torso = "Torso"
		Parts.RightLeg = "Right Leg"
		Parts.LeftLeg = "Left Leg"
	else
		Parts.Torso = "UpperTorso"
		Parts.RightLeg = "RightUpperLeg"
		Parts.LeftLeg = "LeftUpperLeg"
	end
	Parts.Torso = Model:WaitForChild(Parts.Torso, math.huge)
	Parts.RightLeg = Model:WaitForChild(Parts.RightLeg, math.huge)
	Parts.LeftLeg = Model:WaitForChild(Parts.LeftLeg, math.huge)
	local NewModel = FemaleRig:Clone()
	local NewParts = {
		Torso = NewModel.T.Torso,
		RightLeg = NewModel.R["Right Leg"],
		LeftLeg = NewModel.L["Left Leg"],
	}

	NewParts.Torso.Color = Parts.Torso.Color
	NewParts.Torso.Part.BRSTVisual.Color = Parts.Torso.Color

	NewParts.Torso.Model.RightCHK.Color = Parts.RightLeg.Color

	NewParts.Torso.Model.LeftCHK.Color = Parts.LeftLeg.Color
	if R6 then
		NewParts.RightLeg.Color = Parts.RightLeg.Color
		NewParts.LeftLeg.Color = Parts.LeftLeg.Color
	else
		NewParts.RightLeg = nil
		NewParts.LeftLeg = nil
	end
	DressUp(Model, NewModel)

	-- added stuff. (Ukiyo)
	Model.ChildAdded:Connect(function(child)
		if child:IsA("Clothing") then
			DressUp(Model, NewModel)
		end
	end)

	for name, part in next, NewParts do
		Weld(part, Parts[name])
		Parts[name].Transparency = 1
	end
	NewParts.BJJ = NewParts.Torso.BUJ.BJJ
	NewParts.BJ = NewParts.Torso.BTJ.BJ
	Protect(NewModel)
	NewModel.Parent = Model
	return NewParts
end

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

while not LocalPlayer do
	Players.ChildAdded:Wait()
	LocalPlayer = Players.LocalPlayer
end

local function JigglePhysics(NewParts) -- I've no idea what is happening here (Deuces)
	local Torso = NewParts.Torso

	local A = NewParts.BJ
	local SJ = NewParts.BJJ

	local OGC0 = SJ.C0
	local OGC02 = A.C0
	local OGY = Torso.Position.Y

	local BRSTSpring = SpringClass.new()
	BRSTSpring.Target = 5
	BRSTSpring.Speed = 10
	BRSTSpring.Damper = 0.2

	local BTTSpring = SpringClass.new()
	BTTSpring.Target = 3
	BTTSpring.Speed = 10
	BTTSpring.Damper = 0.1

	RunService.Stepped:Connect(function(_, deltatime)
		if LocalPlayer and LocalPlayer.Character and workspace.CurrentCamera then
			local Camera = workspace.CurrentCamera
			local HRP = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

			if HRP and (HRP.Position - Camera.CFrame.Position).Magnitude < 50 then
				local CURRY = Torso.Position.Y
				local Calculated = OGY - CURRY
				OGY = CURRY
				BRSTSpring:TimeSkip(deltatime)
				BRSTSpring:Impulse(Calculated)

				BTTSpring:TimeSkip(deltatime)
				BTTSpring:Impulse(Calculated)

				SJ.C0 = OGC0
					* CFrame.new(0, -0.02 * (BRSTSpring.Velocity / 10), 0)
					* CFrame.Angles(-10 * math.rad(BRSTSpring.Velocity), 0, 0)
				A.C0 = OGC02
					* CFrame.new(0, -0.05 * (BTTSpring.Velocity / 10), 0)
					* CFrame.Angles(2 * math.rad(BTTSpring.Velocity), 0, 0)
			end
		end
	end)
end

local function VerifyRigAndApply(instance, ApplyPhysics)
	task.spawn(function()
		if instance:IsA("Model") then
			local Player
			if Settings.Only_Others then
				Player = Players:GetPlayerFromCharacter(instance)
				if Player == LocalPlayer then
					return
				end
			end
			if ApplyPhysics == nil then
				ApplyPhysics = true
			end
			task.delay(30, task.cancel, coroutine.running()) -- time out the whole thing after 30 seconds (Deuces)
			local Humanoid
			repeat
				Humanoid = instance:FindFirstChildWhichIsA("Humanoid")
				if not Humanoid then
					task.wait()
				end
			until Humanoid

			if not Settings.ForceAllRigs and instance:FindFirstChild("CustomRig") then -- maybe use findfirstdescendant instead just to be sure? (Deuces)
				return
			end -- we dont need floating tiddies again (Ukiyo)
			local NewParts = ApplyRig(instance, Humanoid.RigType == Enum.HumanoidRigType.R6)

			if ApplyPhysics then
				if Settings.Simulate_Physics_On_LocalPlayer_Only then
					if not Player then
						Player = Players:GetPlayerFromCharacter(instance)
					end
					if not Player or Player ~= LocalPlayer then
						return
					end
				end
				JigglePhysics(NewParts)
			end
		end
	end)
end

while game.GameId == 0 do
	task.wait()
end

if game.GameId == 1359573625 then -- dw (Deuces)
	local LiveFolder = workspace:WaitForChild("Live", math.huge)
	LiveFolder.ChildAdded:Connect(VerifyRigAndApply)

	for _, child in ipairs(LiveFolder:GetChildren()) do
		VerifyRigAndApply(child)
	end

	local NPCFolder = workspace:WaitForChild("NPCs", math.huge)
	NPCFolder.ChildAdded:Connect(VerifyRigAndApply)

	for _, child in ipairs(NPCFolder:GetChildren()) do
		VerifyRigAndApply(child, false)
	end
else -- other games (Deuces)
	workspace.DescendantAdded:Connect(VerifyRigAndApply)

	for _, child in ipairs(workspace:GetDescendants()) do
		VerifyRigAndApply(child)
	end
end
