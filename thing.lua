--[[
	Made by ches (@FRAGBOMBBLITZ)
 	See Loader for docs

	Discord Server:
	https://discord.gg/Ud6zrfuhAK
]]


local ReanimationModule = {}
local ReanimationCharacter = nil

local InsertService = game:GetService("InsertService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")

local ReplicationTableData = {}
local ReplicationConnections = {}

local RefitBlacklist         = {}
local RefitLostCount         = 0
local RefitThreshold         = 4
local RefitInterval          = 1.2
local RefitEnabled           = true

local IsStudio = RunService:IsStudio()
local PlayerPing = not IsStudio and Stats.Network.ServerStatsItem["Data Ping"] or 0.30
local RespawnTime = not IsStudio and Players.RespawnTime or 0.5

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:FindFirstChildOfClass("Humanoid")

local function GetPlayerPing()
	return not IsStudio and PlayerPing:GetValue() / 2500 or 0
end

local function Notification(Title, Text, Duration)
	StarterGui:SetCore("SendNotification",{Title = Title or "", Text = Text or "", Duration = Duration or 5})
end

if not replicatesignal then
	Notification("REANIMITE", "Your executor does not support replicatesignal :(")
	return
end

local function GetAccessoryNameFromId(AssetId: number)
	local Model = not IsStudio and game:GetObjects("rbxassetid://"..AssetId)[1] or game:GetService("ReplicatedStorage").LoadAsset:InvokeServer(AssetId)
	local AccessoryName = IsStudio and Model:FindFirstChildOfClass("Accessory").Name or Model.Name

	Model:Destroy()
	return AccessoryName
end

local function GetAccessoryFromId(AssetId: number)
	if Character:FindFirstChild(AssetId) then print("test 444"); return Character:FindFirstChild(AssetId) end
	
	local HumanoidAccessories = Humanoid:GetAppliedDescription():GetAccessories(true)
	
	for _, AccessoryData in HumanoidAccessories do

		local Accessory = {
			Name = GetAccessoryNameFromId(AssetId),
			Id = AccessoryData["AssetId"]
		}
		 
		for _, AccessoryDescription in Humanoid.HumanoidDescription:GetChildren() do
			if AccessoryDescription:IsA("AccessoryDescription") then
				if AccessoryDescription.AssetId == Accessory.Id then
					return Character:FindFirstChild(Accessory.Name)
				end
			end
		end
	end  
end

local function GetAccessoryHandle(Value : string | number | BasePart)
	if typeof(Value) == "string" then
		
		local Accessory = Character:FindFirstChild(Value)
		return Accessory and Accessory.Handle or nil
		
	elseif typeof(Value) == "number" then
		
		print("get me id", Value)
		
		local Accessory = GetAccessoryFromId(Value)
		return Accessory and Accessory.Handle or nil
		
	elseif Value:IsA("BasePart") then
		
		return Value
	end
end

local function ValidateParts(Part0, Part1)
	local Part0IsValid = true
	local Part1IsValid = true

	if Part0.Parent == nil or Part0.Parent.Parent == nil or Character.Parent == nil then Part0IsValid = false end
	if Part1.Parent == nil or Part1.Parent.Parent == nil or Character.Parent == nil then Part1IsValid = false end

	return Part0IsValid, Part1IsValid
end

local function RoundTwo(Number: number)
	return math.floor(Number * 10 ^ 2) / 10 ^ 2
end

local function ReplicateAccessory(Part0: string | number | BasePart, Part1: BasePart, Transform: CFrame)
	if not Part0 or not Part1 then
		warn("ReplicationTable Entry")
	end
	
	local AccessoryHandle = GetAccessoryHandle(Part0)
	local AccessoryTransform = Transform or CFrame.identity
	local ReanimationHumanoid = ReanimationCharacter:FindFirstChildOfClass("Humanoid")

	if AccessoryHandle == nil then return end
	local AccessoryKey = AccessoryHandle.Parent
	if RefitBlacklist and AccessoryKey and not table.find(RefitBlacklist, AccessoryKey) then
		table.insert(RefitBlacklist, AccessoryKey)
	end
	for Index, Value in ReplicationConnections do
		   
		if Index == AccessoryKey then
			warn("already rep", AccessoryKey)
			return
		end	
	end	
	local function AttemptRefit()
    if not RefitEnabled then return end
    if not ReanimationCharacter or not ReanimationCharacter.Parent then return end

    local ReanimatedRoot = ReanimationCharacter:FindFirstChild("HumanoidRootPart")
    if not ReanimatedRoot then return end

    local Recovered = 0
    local AlreadyConnected = {}

    for accKey in pairs(ReplicationConnections) do
        AlreadyConnected[accKey] = true
    end

    local accessories = Humanoid and Humanoid:GetAccessories() or {}
    for _, acc in ipairs(accessories) do
        local handle = acc:FindFirstChild("Handle")
        if not handle or handle.Parent ~= acc then
            continue
        end

        if AlreadyConnected[acc] then
            continue
        end

        -- pick a random limb on the dummy
        local limbNames = {"Right Arm", "Left Arm", "Right Leg", "Left Leg", "Torso", "Head"}
        local limb = nil
        for i = 1, #limbNames do
            local try = ReanimationCharacter:FindFirstChild(limbNames[math.random(1, #limbNames)])
            if try then limb = try break end
        end
        limb = limb or ReanimatedRoot

        if limb then
            -- safety: clear stale connection if present
            if ReplicationConnections[acc] then
                ReplicationConnections[acc]:Disconnect()
                ReplicationConnections[acc] = nil
            end

            ReplicateAccessory(handle, limb, CFrame.new())
            Recovered = Recovered + 1
            print("[Refit] Recovered hat:", acc.Name)
        end
    end

    if Recovered > 0 then
        Notification("REANIMITE", "Refit recovered " .. Recovered .. " hats!", 3)
    end
end

	ReplicationConnections[AccessoryKey] = RunService.Heartbeat:Connect(function()
		local Part0Exists, Part1Exists = ValidateParts(AccessoryHandle, Part1)
		if not Part0Exists or not Part1Exists then ReplicationConnections[AccessoryKey]:Disconnect(); ReplicationConnections[AccessoryKey] = nil; pcall(function() warn("gone.",AccessoryHandle.Parent) end) return end

		local RootPartVelocity = ReanimationCharacter.HumanoidRootPart.Velocity
		local DirectionalVelocity = RootPartVelocity * math.clamp(ReanimationCharacter.Humanoid.WalkSpeed * 2, 16, 10000)
		
		local LinearVelocity = Vector3.new(DirectionalVelocity.X, 27 + math.sin(os.clock()), DirectionalVelocity.Z)
		local AngularVelocity = Part1.AssemblyAngularVelocity
		
		local AntisleepPosition = Vector3.zero

		if (ReanimationHumanoid.MoveDirection * Vector3.new(1,0,1)).Magnitude == 0 then
			AntisleepPosition = Vector3.new(0.015 * math.sin(os.clock() * 8), 0, 0.015 * math.cos(os.clock() * 8))
		end		

		AccessoryHandle.AssemblyLinearVelocity = LinearVelocity
		AccessoryHandle.AssemblyAngularVelocity = AngularVelocity

		AccessoryHandle.CFrame = (Part1.CFrame * AccessoryTransform) + AntisleepPosition
	end)
end

local function CreateDummy()	
	local function SanitizeDummy(Dummy)
		local function NoCollide(Part0, Part1)
			local NoCollisionConstraint = Instance.new("NoCollisionConstraint")
			NoCollisionConstraint.Name = Part1.Name
			NoCollisionConstraint.Parent = Part0
			NoCollisionConstraint.Part0 = Part0
			NoCollisionConstraint.Part1 = Part1
		end

		for _, Value in Dummy:GetDescendants() do
			if Value:IsA("Decal") or Value:IsA("ParticleEmitter") or Value:IsA("Fire") or Value:IsA("Smoke") or Value:IsA("Sparkles") then
				Value:Destroy()
			elseif Value:IsA("BasePart") then
				Value.Transparency = 1
			end
		end

		for _, Part0 in Character:GetChildren() do
			if Part0:IsA("BasePart") then
				for _, Part1 in Dummy:GetChildren() do
					if Part1:IsA("BasePart") then
						NoCollide(Part0, Part1)
					end
				end
			end
		end
	end

	local HumanoidDescription = Players:GetHumanoidDescriptionFromUserId(Player.UserId)
	local ReanimationDummy = Players:CreateHumanoidModelFromDescription(HumanoidDescription, Enum.HumanoidRigType.R6)
	SanitizeDummy(ReanimationDummy)

	ReanimationDummy.Parent = workspace
	ReanimationDummy:PivotTo(Character.Head.CFrame * CFrame.new(0,0,0))

	return ReanimationDummy
end

local function ReanimationVisualization()
	local VisualHighlight = Instance.new("Highlight")
	VisualHighlight.Parent = ReanimationCharacter
	VisualHighlight.FillTransparency = 1
	VisualHighlight.OutlineTransparency = 1

	local VisualProgressGui = Instance.new("BillboardGui")
	VisualProgressGui.Parent = ReanimationCharacter.Head
	VisualProgressGui.StudsOffset = Vector3.new(0,1.5,0)
	VisualProgressGui.Size = UDim2.new(4,0,0.05,0)
	VisualProgressGui.AlwaysOnTop = true
	VisualProgressGui.LightInfluence = 0

	local VisualProgressContainerFrame = Instance.new("Frame")
	VisualProgressContainerFrame.Parent = VisualProgressGui
	VisualProgressContainerFrame.BackgroundColor3 = Color3.fromRGB(35,35,35)
	VisualProgressContainerFrame.BackgroundTransparency = 0.7
	VisualProgressContainerFrame.Size = UDim2.new(1,0,1,0)

	local VisualProgressProgressFrame = VisualProgressContainerFrame:Clone()
	VisualProgressProgressFrame.Parent = VisualProgressContainerFrame
	VisualProgressProgressFrame.BackgroundColor3 = Color3.fromRGB(255,255,255)
	VisualProgressProgressFrame.BackgroundTransparency = 0.5
	VisualProgressProgressFrame.Size = UDim2.new(0,0,1,0)

	local VisualInbetweenDebounce = 0.5 + GetPlayerPing()

	local function CloneAccessory(EntryTable)
		local Part0 = EntryTable.Part0
		local Part1 = EntryTable.Part1
		local Transform = EntryTable.Transform or CFrame.identity

		local AccessoryHandle = GetAccessoryHandle(Part0)

		local AccessoryTransform = Transform or CFrame.identity

		if AccessoryHandle == nil then warn("Accessory not found", Part0) return end

		local ClonedHandle = AccessoryHandle:Clone()
		ClonedHandle.Parent = ReanimationCharacter
		ClonedHandle.Name = "ClonedHandle"..AccessoryHandle.Parent.Name
		ClonedHandle.Massless = true
		ClonedHandle.CanTouch = false
		ClonedHandle.CanQuery = false
		ClonedHandle.Transparency = 1
		ClonedHandle.AccessoryWeld:Destroy()
		ClonedHandle.CFrame = Part1.CFrame * Transform

		local AccessoryWeld = Instance.new("WeldConstraint")
		AccessoryWeld.Parent = ClonedHandle
		AccessoryWeld.Part0 = ClonedHandle
		AccessoryWeld.Part1 = Part1

		task.delay(RespawnTime + VisualInbetweenDebounce, function()
			ClonedHandle:Destroy()
		end)
	end	

	for Index, EntryTable in ReplicationTableData do
		if typeof(EntryTable) ~= "table" then continue end
		CloneAccessory(EntryTable)
	end

	if ReplicationTableData.NonEssentialAccessories then
		for _, Value in Humanoid:GetAccessories() do
			if ReanimationCharacter:FindFirstChild(Value.Name) and not ReanimationCharacter:FindFirstChild("ClonedHandle"..Value.Name) then
				CloneAccessory({Part0 = Value.Handle, Part1 = ReanimationCharacter:FindFirstChild(Value.Name).Handle})
			end	
		end
	end

	local FadeInTweenInfo = TweenInfo.new(RespawnTime + VisualInbetweenDebounce, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)
	TweenService:Create(VisualHighlight, FadeInTweenInfo, {OutlineTransparency = 0.5}):Play()
	TweenService:Create(VisualProgressProgressFrame, FadeInTweenInfo, {Size = UDim2.new(1,0,1,0)}):Play()

	for _, ClonedHandle in ReanimationCharacter:GetChildren() do
		if string.match(ClonedHandle.Name, "ClonedHandle") then
			TweenService:Create(ClonedHandle, FadeInTweenInfo, {Transparency = 0}):Play()
		end
	end

	Character.Head:FindFirstChildOfClass("Decal"):Destroy()
	for _, Value in Character:GetChildren() do
		if Value:IsA("BasePart") then
			Value.Transparency = 1
		elseif Value:IsA("Accessory") then
			Value.Handle.Transparency = 1
		end	
	end

	task.spawn(function()
		task.wait(RespawnTime + VisualInbetweenDebounce)

		for _, Value in Character:GetChildren() do
			if Value:IsA("Accessory") then
				Value.Handle.Transparency = 0
			end	
		end

		VisualHighlight.Parent = Character
		VisualHighlight.OutlineTransparency = 0
		TweenService:Create(VisualHighlight, TweenInfo.new(0.75), {OutlineTransparency = 1}):Play()

		VisualProgressProgressFrame.BackgroundTransparency = 0
		VisualProgressProgressFrame.BorderSizePixel = 0
		TweenService:Create(VisualProgressProgressFrame, TweenInfo.new(0.75), {BackgroundTransparency = 1}):Play()
		VisualProgressContainerFrame.BackgroundTransparency = 1

		task.delay(0.75, function()
			VisualProgressGui:Destroy()
			VisualHighlight:Destroy()
		end)
	end)
end

local function ReanimationRespawn()
	replicatesignal(Player.ConnectDiedSignalBackend)
	if not IsStudio then workspace.FallenPartsDestroyHeight = -500 end

	for _, Value in ReanimationCharacter:GetChildren() do
		if Value:IsA("BasePart") then
			Value.CanCollide = false
		end	
	end	
	for _, Value in ReanimationCharacter:FindFirstChildOfClass("Humanoid"):GetAccessories() do
		Value.Handle.CanCollide = true
	end	

	ReanimationCharacter:BreakJoints()
	ReanimationCharacter.Torso.AssemblyLinearVelocity = Vector3.new(math.random(-5,5),math.random(-5,5),math.random(-5,5))
	ReanimationCharacter.Torso.AssemblyAngularVelocity = Vector3.new(math.random(-5,5),math.random(-5,5),math.random(-5,5))

	task.wait(RespawnTime)

	ReanimationCharacter:Destroy()
	StarterGui:SetCore("ResetButtonCallback", true)
end	

local function ReanimationInitializeCharacter()
	Notification("REANIMITE", "Please wait "..RespawnTime.." second(s) to reanimate", RespawnTime)

	if not IsStudio then workspace.FallenPartsDestroyHeight = 0/0 end
	Character:PivotTo(CFrame.new(1000,1600,-1000))
	for _, Part in Character:GetDescendants() do if Part:IsA("BasePart") then Part.AssemblyLinearVelocity = Vector3.new(0,2255,0) end end

	local CameraCFrame = Camera.CFrame
	Player.Character = ReanimationCharacter
	Camera.CameraSubject = ReanimationCharacter:FindFirstChildOfClass("Humanoid")

	task.spawn(function()
		RunService.RenderStepped:Wait()
		Camera.CFrame = CameraCFrame
	end)	

	if not IsStudio then Player.SimulationRadius = 1000 end
end

local function ReanimationPermadeathCharacter()
	if IsStudio then
		task.wait(RespawnTime)
		Character:BreakJoints()
	else
		task.delay(RespawnTime + GetPlayerPing(), function()
			local CameraCFrame = Camera.CFrame
			RunService.RenderStepped:Wait()
			Camera.CFrame = CameraCFrame
		end)

		replicatesignal(Player.ConnectDiedSignalBackend)
		task.wait(RespawnTime + GetPlayerPing())

		Player.Character = Character
		if replicatesignal2 then replicatesignal2(Humanoid, "ServerBreakJoints") else replicatesignal(Humanoid.ServerBreakJoints) end
		Player.Character = ReanimationCharacter	
	end

	Player.ReplicationFocus = ReanimationCharacter.PrimaryPart
end

local function ReanimationHandleRespawning()
	Notification("REANIMITE", "Reanimated", 2)

	if not IsStudio then
		local RespawnEvent = Instance.new("BindableEvent")
		RespawnEvent.Event:Once(ReanimationRespawn)
		StarterGui:SetCore("ResetButtonCallback", RespawnEvent)
	end
end

local function ReplicateReplicationTable(ReplicationTable)	
	for Index, EntryTable in ReplicationTable do
		if typeof(EntryTable) ~= "table" then continue end

		if EntryTable.Part0 and EntryTable.Part1 then
				ReplicateAccessory(EntryTable.Part0, EntryTable.Part1, EntryTable.Transform)
		else
			warn("ReplicationTable Entry #"..Index.." has not defined Part0 or Part1")
		end	
	end
end

function ReanimationModule:CreateDummy()
	ReanimationCharacter = CreateDummy()

	return ReanimationCharacter
end

function ReanimationModule:Reanimate(ReplicationTable)
	ReplicationTableData = ReplicationTable

	ReanimationInitializeCharacter()
	ReanimationVisualization()
	ReanimationPermadeathCharacter()

	ReplicateReplicationTable(ReplicationTable)

	if ReplicationTable.NonEssentialAccessories then
		for _, Value in Humanoid:GetAccessories() do
			if ReanimationCharacter:FindFirstChild(Value.Name) then
				ReplicateAccessory(Value.Handle, ReanimationCharacter:FindFirstChild(Value.Name).Handle)
			end	
		end
	end

	ReanimationHandleRespawning()
end

local function RefitAccessories()
    if not RefitEnabled then return end

    local lostCount = 0

    -- Clean up dead entries (like Krypton does)
    for i = #RefitBlacklist, 1, -1 do
        local acc = RefitBlacklist[i]
        if not acc or not acc.Parent then
            table.remove(RefitBlacklist, i)
        else
            -- still exists but maybe desynced → count as potentially lost
            if acc.Handle and acc.Handle.Parent == nil then
                lostCount += 1
            end
        end
    end

    -- If too many lost → force re-align / re-claim
    if lostCount > RefitThreshold or #RefitBlacklist < TotalAccessories - RefitThreshold then
        Notification("REANIMITE", "Refitting accessories... (" .. lostCount .. " lost)", 3)

        -- Option A: Re-run accessory replication on visible hats
        for _, acc in Humanoid:GetAccessories() do
            local handle = acc:FindFirstChild("Handle")
            if handle and handle.Parent then
                -- Try to re-attach to a random / nearest dummy limb (customize this)
                local targetPart = ReanimationCharacter:FindFirstChild("Right Arm") 
                    or ReanimationCharacter:FindFirstChild("RightHand") 
                    or ReanimationCharacter.HumanoidRootPart

                if targetPart then
                    ReplicateAccessory(handle, targetPart, CFrame.new())  -- or keep original offset if you store it
                end
            end
        end

        -- Option B: extreme — respawn dummy (risky, but Krypton sometimes does heavy resets)
        -- task.spawn(ReanimationRespawn)   -- uncomment only if desperate
    end
end

-- Improved refit routine: periodically scan the real character's accessories and re-replicate any surviving hats
local function AttemptRefit()
    if not RefitEnabled then return end
    if not ReanimationCharacter or not ReanimationCharacter.Parent then return end

    local ReanimatedRoot = ReanimationCharacter:FindFirstChild("HumanoidRootPart")
    if not ReanimatedRoot then return end

    local Recovered = 0
    local AlreadyConnected = {}

    for accKey in pairs(ReplicationConnections) do
        AlreadyConnected[accKey] = true
    end

    local accessories = Humanoid and Humanoid:GetAccessories() or {}
    for _, acc in ipairs(accessories) do
        local handle = acc:FindFirstChild("Handle")
        if not handle or handle.Parent ~= acc then
            continue
        end

        if AlreadyConnected[acc] then
            continue
        end

        -- pick a random limb on the dummy
        local limbNames = {"Right Arm", "Left Arm", "Right Leg", "Left Leg", "Torso", "Head"}
        local limb = nil
        for i = 1, #limbNames do
            local try = ReanimationCharacter:FindFirstChild(limbNames[math.random(1, #limbNames)])
            if try then limb = try break end
        end
        limb = limb or ReanimatedRoot

        if limb then
            -- safety: clear stale connection if present
            if ReplicationConnections[acc] then
                ReplicationConnections[acc]:Disconnect()
                ReplicationConnections[acc] = nil
            end

            ReplicateAccessory(handle, limb, CFrame.new())
            Recovered = Recovered + 1
            print("[Refit] Recovered hat:", acc.Name)
        end
    end

    if Recovered > 0 then
        Notification("REANIMITE", "Refit recovered " .. Recovered .. " hats!", 3)
    end
end

-- periodic loop
task.spawn(function()
    while RefitEnabled do
        task.wait(RefitInterval or 1.2)
        pcall(AttemptRefit)
    end
end)

return ReanimationModule



