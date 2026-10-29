--[[
	MEGA OBBY - Server
	Platzieren in: ServerScriptService (als Script)
	Baut die komplette Map selbst, speichert den Fortschritt, verarbeitet Käufe.
]]

local CONFIG = {
	STAGES = 60,
	DATASTORE = "MegaObby_v1",
	-- IDs aus dem Creator Dashboard eintragen (0 = deaktiviert)
	SKIP_STAGE_PRODUCT = 0, -- Developer Product
	SPEED_PASS = 0, -- Game Pass: +60% Laufgeschwindigkeit
	LOW_GRAVITY_PASS = 0, -- Game Pass: weniger Schwerkraft
	START_HEIGHT = 60,
}

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local store = DataStoreService:GetDataStore(CONFIG.DATASTORE)

---------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "ObbyRemotes"

local function makeRemote(name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end

local RespawnRemote = makeRemote("Respawn")
local NotifyRemote = makeRemote("Notify")

local configValues = Instance.new("Configuration")
configValues.Name = "Config"
configValues.Parent = remotes
for _, key in ipairs({ "SKIP_STAGE_PRODUCT", "SPEED_PASS", "LOW_GRAVITY_PASS", "STAGES" }) do
	local v = Instance.new("IntValue")
	v.Name = key
	v.Value = CONFIG[key]
	v.Parent = configValues
end
remotes.Parent = ReplicatedStorage -- erst jetzt, damit der Client alles auf einmal bekommt

---------------------------------------------------------------------
-- Map-Generierung
---------------------------------------------------------------------
-- Standard-Baseplate und -Spawn entfernen (sonst landet man nach dem Fallen darauf)
for _, name in ipairs({ "Baseplate", "SpawnLocation" }) do
	local existing = workspace:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
end

local map = Instance.new("Folder")
map.Name = "ObbyMap"
map.Parent = workspace

local checkpoints = {} -- [stageNumber] = Part
local killParts = {}
local blinkingParts = {}
local spinners = {}

local STAGE_COLORS = {
	Color3.fromRGB(255, 89, 94),
	Color3.fromRGB(255, 202, 58),
	Color3.fromRGB(138, 201, 38),
	Color3.fromRGB(25, 130, 196),
	Color3.fromRGB(106, 76, 147),
	Color3.fromRGB(255, 146, 76),
}

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = props.Parent or map
	return p
end

local function killPart(size, cframe)
	local p = part({
		Name = "Kill",
		Size = size,
		CFrame = cframe,
		Color = Color3.fromRGB(255, 40, 40),
		Material = Enum.Material.Neon,
	})
	table.insert(killParts, p)
	return p
end

-- Lava-Meer unter der ganzen Map
local lava = killPart(Vector3.new(2048, 2, 2048), CFrame.new(0, CONFIG.START_HEIGHT - 40, 1000))
lava.Name = "LavaSea"
lava.Color = Color3.fromRGB(255, 85, 0)

-- Startbereich
local spawnPad = Instance.new("SpawnLocation")
spawnPad.Anchored = true
spawnPad.Size = Vector3.new(24, 1, 24)
spawnPad.CFrame = CFrame.new(0, CONFIG.START_HEIGHT, 0)
spawnPad.Color = Color3.fromRGB(240, 240, 240)
spawnPad.Material = Enum.Material.SmoothPlastic
spawnPad.Duration = 0
spawnPad.Name = "Start"
spawnPad.Parent = map
checkpoints[0] = spawnPad

local cursor = Vector3.new(0, CONFIG.START_HEIGHT, 12) -- Oberkante-Mitte vom aktuellen Ende

local function addCheckpoint(stage)
	local color = STAGE_COLORS[(stage % #STAGE_COLORS) + 1]
	local cp = part({
		Name = "Checkpoint",
		Size = Vector3.new(12, 1, 12),
		CFrame = CFrame.new(cursor + Vector3.new(0, 0, 6)),
		Color = color,
	})
	cp:SetAttribute("Stage", stage)

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.Parent = cp
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = tostring(stage)
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = gui

	checkpoints[stage] = cp
	cursor = cursor + Vector3.new(0, 0, 12)
end

-- Hindernis-Typen. Jeder erhöht "cursor" bis zum Ende des Abschnitts.
local obstacles = {}

function obstacles.jumps(difficulty, color)
	local count = 4 + math.floor(difficulty * 3)
	local gap = 5 + difficulty * 4
	local size = math.max(3, 7 - difficulty * 3)
	for i = 1, count do
		local offsetX = (i % 2 == 0) and 3 or -3
		local y = cursor.Y + ((i % 3 == 0) and 2 or 0)
		cursor = Vector3.new(cursor.X, cursor.Y, cursor.Z + gap)
		part({ Size = Vector3.new(size, 1, size), CFrame = CFrame.new(cursor.X + offsetX * difficulty, y, cursor.Z), Color = color })
	end
	cursor = cursor + Vector3.new(0, 0, gap)
end

function obstacles.lavaWalk(difficulty, color)
	local length = 50
	local width = math.max(4, 10 - difficulty * 5)
	part({ Size = Vector3.new(width, 1, length), CFrame = CFrame.new(cursor + Vector3.new(0, 0, length / 2)), Color = color })
	local stripes = 3 + math.floor(difficulty * 4)
	for i = 1, stripes do
		local z = cursor.Z + i * (length / (stripes + 1))
		killPart(Vector3.new(width, 1.2, 2), CFrame.new(cursor.X, cursor.Y + 0.1, z))
	end
	cursor = cursor + Vector3.new(0, 0, length)
end

function obstacles.spinner(difficulty, color)
	local radius = 14
	local center = cursor + Vector3.new(0, 0, radius + 2)
	-- Zylinder-Achse ist X -> um Z drehen, damit eine flache Scheibe entsteht
	part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, radius * 2, radius * 2),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
	})
	local bar = killPart(Vector3.new(radius * 2, 1.5, 1.5), CFrame.new(center + Vector3.new(0, 1.5, 0)))
	table.insert(spinners, { part = bar, center = center + Vector3.new(0, 1.5, 0), speed = 1.2 + difficulty * 2.5, angle = 0 })
	if difficulty > 0.5 then
		local bar2 = killPart(Vector3.new(radius * 2, 1.5, 1.5), CFrame.new(center + Vector3.new(0, 4.5, 0)))
		table.insert(spinners, { part = bar2, center = center + Vector3.new(0, 4.5, 0), speed = -(1 + difficulty * 2), angle = math.pi / 2 })
	end
	cursor = cursor + Vector3.new(0, 0, radius * 2 + 4)
end

function obstacles.blink(difficulty, color)
	local count = 5 + math.floor(difficulty * 3)
	for i = 1, count do
		cursor = cursor + Vector3.new(0, 0, 8)
		local p = part({ Size = Vector3.new(6, 1, 6), CFrame = CFrame.new(cursor), Color = color, Material = Enum.Material.Glass })
		table.insert(blinkingParts, { part = p, offset = i * 0.7, period = math.max(1.6, 3.2 - difficulty * 1.6) })
	end
	cursor = cursor + Vector3.new(0, 0, 8)
end

function obstacles.climb(difficulty, color)
	local height = 14 + math.floor(difficulty * 10)
	part({ Size = Vector3.new(10, 1, 8), CFrame = CFrame.new(cursor + Vector3.new(0, 0, 4)), Color = color })
	local truss = Instance.new("TrussPart")
	truss.Anchored = true
	truss.Size = Vector3.new(2, height, 2)
	truss.CFrame = CFrame.new(cursor + Vector3.new(0, height / 2, 9))
	truss.Color = color
	truss.Parent = map
	cursor = cursor + Vector3.new(0, height, 10)
	part({ Size = Vector3.new(10, 1, 6), CFrame = CFrame.new(cursor + Vector3.new(0, 0, 3)), Color = color })
	cursor = cursor + Vector3.new(0, 0, 6)
end

function obstacles.beams(difficulty, color)
	local width = math.max(1, 3 - difficulty * 2)
	local count = 3 + math.floor(difficulty * 2)
	for i = 1, count do
		local angle = (i % 2 == 0) and 25 or -25
		local length = 18
		local rad = math.rad(angle)
		local dx = math.sin(rad) * length
		local dz = math.cos(rad) * length
		local center = cursor + Vector3.new(dx / 2, 0, dz / 2)
		part({
			Size = Vector3.new(width, 1, length + width),
			CFrame = CFrame.new(center) * CFrame.Angles(0, rad, 0),
			Color = color,
		})
		cursor = cursor + Vector3.new(dx, 0, dz)
	end
	local endX = cursor.X
	cursor = Vector3.new(0, cursor.Y, cursor.Z + 2)
	part({ Size = Vector3.new(math.abs(endX) + 8, 1, 4), CFrame = CFrame.new(endX / 2, cursor.Y, cursor.Z), Color = color })
end

function obstacles.stairs(difficulty, color)
	local steps = 6 + math.floor(difficulty * 4)
	for i = 1, steps do
		cursor = cursor + Vector3.new(0, 3, 7 + difficulty * 2)
		part({ Size = Vector3.new(5, 1, 3), CFrame = CFrame.new(cursor), Color = color })
		if difficulty > 0.3 then
			local side = (i % 2 == 0) and 1.5 or -1.5
			killPart(Vector3.new(1.5, 0.4, 3), CFrame.new(cursor + Vector3.new(side, 0.7, 0)))
		end
	end
	cursor = cursor + Vector3.new(0, 0, 5)
end

local ORDER = { "jumps", "lavaWalk", "blink", "stairs", "spinner", "beams", "climb" }

for stage = 1, CONFIG.STAGES do
	local difficulty = math.clamp((stage - 1) / (CONFIG.STAGES - 1), 0, 1)
	local color = STAGE_COLORS[(stage % #STAGE_COLORS) + 1]
	local kind = ORDER[((stage - 1) % #ORDER) + 1]
	-- Sicherer Übergang vom Checkpoint zum Hindernis
	part({ Size = Vector3.new(8, 1, 4), CFrame = CFrame.new(cursor + Vector3.new(0, 0, 2)), Color = color })
	cursor = cursor + Vector3.new(0, 0, 4)
	obstacles[kind](difficulty, color)
	addCheckpoint(stage)
end

-- Ziel
local winPad = part({
	Name = "WinPad",
	Size = Vector3.new(20, 1, 20),
	CFrame = CFrame.new(cursor + Vector3.new(0, 0, 14)),
	Color = Color3.fromRGB(255, 215, 0),
	Material = Enum.Material.Neon,
})
local winGui = Instance.new("BillboardGui")
winGui.Size = UDim2.fromOffset(300, 80)
winGui.StudsOffset = Vector3.new(0, 8, 0)
winGui.AlwaysOnTop = true
winGui.Parent = winPad
local winLabel = Instance.new("TextLabel")
winLabel.Size = UDim2.fromScale(1, 1)
winLabel.BackgroundTransparency = 1
winLabel.Text = "🏆 FINISH 🏆"
winLabel.TextScaled = true
winLabel.Font = Enum.Font.FredokaOne
winLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
winLabel.TextStrokeTransparency = 0
winLabel.Parent = winGui

-- Animationen
RunService.Heartbeat:Connect(function(dt)
	for _, s in ipairs(spinners) do
		s.angle = s.angle + s.speed * dt
		s.part.CFrame = CFrame.new(s.center) * CFrame.Angles(0, s.angle, 0)
	end
end)

task.spawn(function()
	while true do
		local t = os.clock()
		for _, b in ipairs(blinkingParts) do
			local phase = ((t + b.offset) % b.period) / b.period
			local visible = phase < 0.65
			b.part.CanCollide = visible
			b.part.Transparency = visible and 0 or 0.85
		end
		-- Per CFrame bewegte Teile lösen Touched nicht immer aus -> zusätzlich Überlappung prüfen
		for _, s in ipairs(spinners) do
			for _, hit in ipairs(workspace:GetPartsInPart(s.part)) do
				local humanoid = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.Health > 0 then
					humanoid.Health = 0
				end
			end
		end
		task.wait(0.1)
	end
end)

---------------------------------------------------------------------
-- Spielerdaten
---------------------------------------------------------------------
local sessionData = {} -- [player] = { stage, wins, loaded }

local function loadData(player)
	local data
	local success = false
	for _ = 1, 3 do
		local ok, result = pcall(function()
			return store:GetAsync("u_" .. player.UserId)
		end)
		if ok then
			data = result
			success = true
			break
		end
		task.wait(1)
	end
	data = data or {}
	return {
		stage = math.clamp(tonumber(data.stage) or 0, 0, CONFIG.STAGES),
		wins = tonumber(data.wins) or 0,
		loaded = success,
	}
end

local function saveData(player)
	local d = sessionData[player]
	if not d or not d.loaded then
		return
	end
	for _ = 1, 3 do
		local ok = pcall(function()
			store:SetAsync("u_" .. player.UserId, { stage = d.stage, wins = d.wins })
		end)
		if ok then
			return
		end
		task.wait(1)
	end
end

local function ownsPass(player, passId)
	if passId == 0 then
		return false
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	return ok and owns
end

local function applyPerks(player, character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return
	end
	if player:GetAttribute("SpeedPass") then
		humanoid.WalkSpeed = 26
	end
	if player:GetAttribute("LowGravityPass") and not root:FindFirstChild("LowGravity") then
		local attachment = Instance.new("Attachment")
		attachment.Name = "LowGravityAttachment"
		attachment.Parent = root
		local force = Instance.new("VectorForce")
		force.Name = "LowGravity"
		force.Attachment0 = attachment
		force.RelativeTo = Enum.ActuatorRelativeTo.World
		force.ApplyAtCenterOfMass = true
		local mass = 0
		for _, p in ipairs(character:GetDescendants()) do
			if p:IsA("BasePart") then
				mass = mass + p:GetMass()
			end
		end
		force.Force = Vector3.new(0, mass * workspace.Gravity * 0.4, 0)
		force.Parent = root
	end
end

local function teleportToCheckpoint(player)
	local d = sessionData[player]
	local character = player.Character
	if not d or not character then
		return
	end
	local cp = checkpoints[d.stage] or checkpoints[0]
	character:PivotTo(cp.CFrame + Vector3.new(0, 4, 0))
end

local function updateStats(player)
	local d = sessionData[player]
	local ls = player:FindFirstChild("leaderstats")
	if d and ls then
		ls.Stage.Value = d.stage
		ls.Wins.Value = d.wins
	end
end

Players.PlayerAdded:Connect(function(player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	ls.Parent = player
	local stage = Instance.new("IntValue")
	stage.Name = "Stage"
	stage.Parent = ls
	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Parent = ls

	sessionData[player] = loadData(player)
	if not player.Parent then
		return
	end
	if not sessionData[player].loaded then
		NotifyRemote:FireClient(player, "⚠ Progress could not be loaded - it will not be saved this session.")
	end
	updateStats(player)

	player:SetAttribute("SpeedPass", ownsPass(player, CONFIG.SPEED_PASS))
	player:SetAttribute("LowGravityPass", ownsPass(player, CONFIG.LOW_GRAVITY_PASS))

	local function onCharacter(character)
		character:WaitForChild("HumanoidRootPart")
		task.wait(0.1)
		teleportToCheckpoint(player)
		applyPerks(player, character)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
	sessionData[player] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(saveData, player)
	end
	task.wait(3)
end)

task.spawn(function()
	while true do
		task.wait(120)
		for _, player in ipairs(Players:GetPlayers()) do
			task.spawn(saveData, player)
		end
	end
end)

---------------------------------------------------------------------
-- Berührungen
---------------------------------------------------------------------
local function playerFromHit(hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return Players:GetPlayerFromCharacter(character), humanoid
end

for _, kp in ipairs(killParts) do
	kp.Touched:Connect(function(hit)
		local player, humanoid = playerFromHit(hit)
		if player and humanoid then
			humanoid.Health = 0
		end
	end)
end

for stage, cp in pairs(checkpoints) do
	if stage > 0 then
		cp.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			local d = player and sessionData[player]
			if d and stage == d.stage + 1 then
				d.stage = stage
				updateStats(player)
				NotifyRemote:FireClient(player, "✅ Stage " .. stage .. " reached!")
			end
		end)
	end
end

local winDebounce = {}
winPad.Touched:Connect(function(hit)
	local player = playerFromHit(hit)
	local d = player and sessionData[player]
	if not d or winDebounce[player] or d.stage < CONFIG.STAGES then
		return
	end
	winDebounce[player] = true
	d.wins = d.wins + 1
	d.stage = 0
	updateStats(player)
	NotifyRemote:FireClient(player, "🏆 YOU WON! Total wins: " .. d.wins .. " - starting over!")
	task.spawn(saveData, player)
	task.wait(2)
	teleportToCheckpoint(player)
	winDebounce[player] = nil
end)

RespawnRemote.OnServerEvent:Connect(function(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		teleportToCheckpoint(player)
	end
end)

---------------------------------------------------------------------
-- Käufe
---------------------------------------------------------------------
MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local d = player and sessionData[player]
	if not d then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if receipt.ProductId == CONFIG.SKIP_STAGE_PRODUCT then
		d.stage = math.min(d.stage + 1, CONFIG.STAGES)
		updateStats(player)
		teleportToCheckpoint(player)
		NotifyRemote:FireClient(player, "⏭ Stage skipped! Now on stage " .. d.stage)
		task.spawn(saveData, player)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased then
		return
	end
	if passId == CONFIG.SPEED_PASS then
		player:SetAttribute("SpeedPass", true)
	elseif passId == CONFIG.LOW_GRAVITY_PASS then
		player:SetAttribute("LowGravityPass", true)
	end
	if player.Character then
		applyPerks(player, player.Character)
	end
	NotifyRemote:FireClient(player, "🎉 Thanks for your purchase!")
end)
