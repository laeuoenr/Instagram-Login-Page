--[[
	DISASTER SURVIVAL - Server
	Platzieren in: ServerScriptService (als Script)
	Runden-basiert: Lobby -> Insel -> zufällige Katastrophe -> Überlebende bekommen Wins + Coins.
]]

local CONFIG = {
	DATASTORE = "DisasterSurvival_v1",
	INTERMISSION = 20,
	ROUND_TIME = 60,
	SURVIVE_COINS = 25,
	SURVIVE_WIN = 1,
	MAX_UPGRADE_LEVEL = 5,
	-- IDs aus dem Creator Dashboard (0 = deaktiviert)
	VIP_PASS = 0, -- doppelte Coins
	BALLOON_PASS = 0, -- weniger Schwerkraft (höher springen)
	SMALL_COINS_PRODUCT = 0, -- 500 Coins
	BIG_COINS_PRODUCT = 0, -- 3000 Coins
}

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")

local store = DataStoreService:GetDataStore(CONFIG.DATASTORE)
local rng = Random.new()

---------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "DisasterRemotes"
local function makeRemote(name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local NotifyRemote = makeRemote("Notify")
local UpgradeRemote = makeRemote("Upgrade")
local status = Instance.new("StringValue")
status.Name = "Status"
status.Value = "Loading..."
status.Parent = remotes
local shake = Instance.new("BoolValue")
shake.Name = "Shake"
shake.Parent = remotes
local configFolder = Instance.new("Configuration")
configFolder.Name = "Config"
configFolder.Parent = remotes
for _, key in ipairs({ "VIP_PASS", "BALLOON_PASS", "SMALL_COINS_PRODUCT", "BIG_COINS_PRODUCT", "MAX_UPGRADE_LEVEL" }) do
	local v = Instance.new("IntValue")
	v.Name = key
	v.Value = CONFIG[key]
	v.Parent = configFolder
end
remotes.Parent = ReplicatedStorage

---------------------------------------------------------------------
-- Welt: Lobby
---------------------------------------------------------------------
for _, name in ipairs({ "Baseplate", "SpawnLocation" }) do
	local existing = workspace:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
end

local function newPart(parent, cframe, size, color, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in pairs(props) do
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

local lobby = Instance.new("Folder")
lobby.Name = "Lobby"
lobby.Parent = workspace
local LOBBY_CENTER = Vector3.new(0, 80, -260)
newPart(lobby, CFrame.new(LOBBY_CENTER), Vector3.new(80, 2, 80), Color3.fromRGB(70, 75, 90), { Material = Enum.Material.Slate })
for _, side in ipairs({ { 0, -40, 80, 1 }, { 0, 40, 80, 1 }, { -40, 0, 1, 80 }, { 40, 0, 1, 80 } }) do
	newPart(lobby, CFrame.new(LOBBY_CENTER + Vector3.new(side[1], 4, side[2])), Vector3.new(side[3], 6, side[4]), Color3.fromRGB(50, 50, 60))
end
local lobbySpawn = Instance.new("SpawnLocation")
lobbySpawn.Anchored = true
lobbySpawn.Size = Vector3.new(12, 1, 12)
lobbySpawn.CFrame = CFrame.new(LOBBY_CENTER + Vector3.new(0, 1.5, 0))
lobbySpawn.Duration = 0
lobbySpawn.Neutral = true
lobbySpawn.Color = Color3.fromRGB(255, 200, 60)
lobbySpawn.Parent = lobby

-- Abgrund unter allem
local abyss = newPart(workspace, CFrame.new(0, -60, 0), Vector3.new(2048, 2, 2048), Color3.new(0, 0, 0), { Transparency = 1, CanCollide = false, Name = "Abyss" })
abyss.Touched:Connect(function(hit)
	local humanoid = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = 0
	elseif not hit.Anchored then
		hit:Destroy()
	end
end)

-- Meer (nur Optik)
newPart(workspace, CFrame.new(0, -8, 0), Vector3.new(2048, 1, 2048), Color3.fromRGB(40, 110, 200), {
	Material = Enum.Material.Glass, Transparency = 0.3, CanCollide = false, CanTouch = false, Name = "Ocean",
})

---------------------------------------------------------------------
-- Welt: Insel (wird jede Runde neu gebaut)
---------------------------------------------------------------------
local ISLAND_SIZE = 180
local arena

local function buildHouse(parent, origin, color)
	local wall = color
	local floor = Color3.fromRGB(150, 110, 80)
	local function at(x, y, z)
		return CFrame.new(origin + Vector3.new(x, y, z))
	end
	-- Böden
	newPart(parent, at(0, 0.5, 0), Vector3.new(20, 1, 20), floor, { Material = Enum.Material.WoodPlanks })
	newPart(parent, at(-2.5, 10.5, 0), Vector3.new(15, 1, 20), floor, { Material = Enum.Material.WoodPlanks })
	newPart(parent, at(0, 20.5, 0), Vector3.new(20, 1, 20), Color3.fromRGB(150, 60, 50), { Material = Enum.Material.Brick })
	-- Wände pro Stockwerk (vorne mit Türloch)
	for _, y in ipairs({ 5.5, 15.5 }) do
		newPart(parent, at(0, y, -9.5), Vector3.new(20, 9, 1), wall)
		newPart(parent, at(-9.5, y, 0), Vector3.new(1, 9, 18), wall)
		newPart(parent, at(9.5, y, 0), Vector3.new(1, 9, 18), wall)
		newPart(parent, at(-6.5, y, 9.5), Vector3.new(7, 9, 1), wall)
		newPart(parent, at(6.5, y, 9.5), Vector3.new(7, 9, 1), wall)
	end
	-- Leiter bis aufs Dach
	local truss = Instance.new("TrussPart")
	truss.Anchored = true
	truss.Size = Vector3.new(2, 22, 2)
	truss.CFrame = at(7.5, 11, 0)
	truss.Color = Color3.fromRGB(90, 70, 50)
	truss.Parent = parent
end

local function buildTree(parent, origin)
	newPart(parent, CFrame.new(origin + Vector3.new(0, 5, 0)), Vector3.new(2, 10, 2), Color3.fromRGB(110, 75, 45), { Material = Enum.Material.Wood })
	newPart(parent, CFrame.new(origin + Vector3.new(0, 12, 0)), Vector3.new(9, 9, 9), Color3.fromRGB(60, 160, 60), {
		Material = Enum.Material.Grass, Shape = Enum.PartType.Ball,
	})
end

local HOUSE_COLORS = {
	Color3.fromRGB(230, 220, 200), Color3.fromRGB(200, 220, 240), Color3.fromRGB(240, 200, 200),
	Color3.fromRGB(210, 240, 200), Color3.fromRGB(240, 230, 160),
}

local function buildArena()
	if arena then
		arena:Destroy()
	end
	arena = Instance.new("Folder")
	arena.Name = "Arena"
	arena.Parent = workspace
	local buildings = Instance.new("Folder")
	buildings.Name = "Buildings"
	buildings.Parent = arena

	newPart(arena, CFrame.new(0, -5, 0), Vector3.new(ISLAND_SIZE, 10, ISLAND_SIZE), Color3.fromRGB(90, 170, 80), { Material = Enum.Material.Grass, Name = "Ground" })

	local slots = {}
	for gx = -1, 1 do
		for gz = -1, 1 do
			table.insert(slots, Vector3.new(gx * 50, 0, gz * 50))
		end
	end
	for i = #slots, 2, -1 do
		local j = rng:NextInteger(1, i)
		slots[i], slots[j] = slots[j], slots[i]
	end
	for i = 1, 6 do
		local jitter = Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6))
		buildHouse(buildings, slots[i] + jitter, HOUSE_COLORS[rng:NextInteger(1, #HOUSE_COLORS)])
	end
	for i = 7, 9 do
		buildTree(buildings, slots[i] + Vector3.new(rng:NextNumber(-10, 10), 0, rng:NextNumber(-10, 10)))
	end
	for _ = 1, 10 do
		local edge = ISLAND_SIZE / 2 - 8
		buildTree(buildings, Vector3.new(rng:NextNumber(-edge, edge), 0, (rng:NextNumber() > 0.5 and 1 or -1) * edge))
	end
	return buildings
end

---------------------------------------------------------------------
-- Spielerdaten
---------------------------------------------------------------------
local sessionData = {}

local function loadData(player)
	local data, success
	for _ = 1, 3 do
		local ok, result = pcall(function()
			return store:GetAsync("u_" .. player.UserId)
		end)
		if ok then
			data, success = result, true
			break
		end
		task.wait(1)
	end
	data = data or {}
	return {
		coins = tonumber(data.coins) or 0,
		wins = tonumber(data.wins) or 0,
		health = tonumber(data.health) or 0,
		speed = tonumber(data.speed) or 0,
		loaded = success == true,
	}
end

local function saveData(player)
	local d = sessionData[player]
	if not d or not d.loaded then
		return
	end
	for _ = 1, 3 do
		local ok = pcall(function()
			store:SetAsync("u_" .. player.UserId, { coins = d.coins, wins = d.wins, health = d.health, speed = d.speed })
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

local function refresh(player)
	local d = sessionData[player]
	local ls = player:FindFirstChild("leaderstats")
	if d and ls then
		ls.Wins.Value = d.wins
		ls.Coins.Value = d.coins
		player:SetAttribute("HealthLevel", d.health)
		player:SetAttribute("SpeedLevel", d.speed)
	end
end

local function applyUpgrades(player, character, heal)
	local d = sessionData[player]
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not d or not humanoid or not root then
		return
	end
	humanoid.MaxHealth = 100 + d.health * 25
	if heal then
		humanoid.Health = humanoid.MaxHealth
	end
	humanoid.WalkSpeed = 16 + d.speed * 2
	if player:GetAttribute("Balloon") and not root:FindFirstChild("Balloon") then
		local att = Instance.new("Attachment")
		att.Parent = root
		local force = Instance.new("VectorForce")
		force.Name = "Balloon"
		force.Attachment0 = att
		force.RelativeTo = Enum.ActuatorRelativeTo.World
		force.ApplyAtCenterOfMass = true
		local mass = 0
		for _, p in ipairs(character:GetDescendants()) do
			if p:IsA("BasePart") then
				mass = mass + p:GetMass()
			end
		end
		force.Force = Vector3.new(0, mass * workspace.Gravity * 0.35, 0)
		force.Parent = root
	end
end

Players.PlayerAdded:Connect(function(player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	ls.Parent = player
	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Parent = ls
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = ls

	player:SetAttribute("VIP", ownsPass(player, CONFIG.VIP_PASS))
	player:SetAttribute("Balloon", ownsPass(player, CONFIG.BALLOON_PASS))

	local d = loadData(player)
	if not player.Parent then
		return
	end
	sessionData[player] = d
	refresh(player)
	if not d.loaded then
		NotifyRemote:FireClient(player, "⚠ Data could not be loaded - progress will not be saved this session.")
	end

	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart")
		task.wait(0.1)
		applyUpgrades(player, character, true)
	end)
	if player.Character then
		applyUpgrades(player, player.Character, true)
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

UpgradeRemote.OnServerEvent:Connect(function(player, which)
	local d = sessionData[player]
	if not d or (which ~= "health" and which ~= "speed") then
		return
	end
	local level = d[which]
	if level >= CONFIG.MAX_UPGRADE_LEVEL then
		NotifyRemote:FireClient(player, "Already maxed out!")
		return
	end
	local cost = 100 * (level + 1) * (level + 1)
	if d.coins < cost then
		NotifyRemote:FireClient(player, "You need " .. cost .. " coins!")
		return
	end
	d.coins = d.coins - cost
	d[which] = level + 1
	refresh(player)
	if player.Character then
		applyUpgrades(player, player.Character)
	end
	NotifyRemote:FireClient(player, "⬆ Upgrade bought!")
end)

---------------------------------------------------------------------
-- Katastrophen
---------------------------------------------------------------------
local alive = {} -- [player] = true während der Runde

local function aliveCharacters()
	local list = {}
	for player in pairs(alive) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and root and humanoid.Health > 0 then
			table.insert(list, { player = player, humanoid = humanoid, root = root })
		end
	end
	return list
end

local function randomIslandPoint(margin)
	local half = ISLAND_SIZE / 2 - (margin or 0)
	return Vector3.new(rng:NextNumber(-half, half), 0, rng:NextNumber(-half, half))
end

local function loosen(part, velocity)
	if part:IsA("BasePart") and part.Anchored and part.Name ~= "Ground" then
		part.Anchored = false
		if velocity then
			part.AssemblyLinearVelocity = velocity
		end
	end
end

local disasters = {}

local function risingLiquid(buildings, isLava, roundEnd)
	local liquid = newPart(arena, CFrame.new(0, -6, 0), Vector3.new(ISLAND_SIZE + 40, 12, ISLAND_SIZE + 40),
		isLava and Color3.fromRGB(255, 90, 0) or Color3.fromRGB(40, 120, 255), {
			Material = isLava and Enum.Material.Neon or Enum.Material.Glass,
			Transparency = isLava and 0.1 or 0.35,
			CanCollide = false,
			Name = isLava and "Lava" or "Flood",
		})
	local maxTop = isLava and 14 or 22
	local start = os.clock()
	local duration = CONFIG.ROUND_TIME * 0.7
	while os.clock() < roundEnd do
		local progress = math.clamp((os.clock() - start) / duration, 0, 1)
		local top = -1 + progress * (maxTop + 1)
		liquid.CFrame = CFrame.new(0, top - 6, 0)
		for _, c in ipairs(aliveCharacters()) do
			if c.root.Position.Y - 1.5 < top then
				c.humanoid:TakeDamage(isLava and 100 or 6)
			end
		end
		task.wait(0.5)
	end
end

function disasters.Flood(buildings, roundEnd)
	risingLiquid(buildings, false, roundEnd)
end

function disasters.Lava(buildings, roundEnd)
	risingLiquid(buildings, true, roundEnd)
end

function disasters.Meteors(buildings, roundEnd)
	while os.clock() < roundEnd do
		for _ = 1, 3 do
			local target = randomIslandPoint(0)
			local meteor = newPart(arena, CFrame.new(target + Vector3.new(rng:NextNumber(-30, 30), 160, rng:NextNumber(-30, 30))), Vector3.new(5, 5, 5),
				Color3.fromRGB(120, 60, 30), { Shape = Enum.PartType.Ball, Material = Enum.Material.Basalt, Anchored = false, Name = "Meteor" })
			local fire = Instance.new("Fire")
			fire.Size = 10
			fire.Parent = meteor
			meteor.AssemblyLinearVelocity = (target - meteor.Position).Unit * 120
			local exploded = false
			meteor.Touched:Connect(function(hit)
				if exploded or hit.Name == "Meteor" then
					return
				end
				exploded = true
				local explosion = Instance.new("Explosion")
				explosion.Position = meteor.Position
				explosion.BlastRadius = 12
				explosion.BlastPressure = 200000
				explosion.DestroyJointRadiusPercent = 0
				local damaged = {}
				explosion.Hit:Connect(function(part)
					local humanoid = part.Parent and part.Parent:FindFirstChildOfClass("Humanoid")
					if humanoid and not damaged[humanoid] then
						damaged[humanoid] = true
						humanoid:TakeDamage(45)
					elseif part:IsDescendantOf(buildings) then
						loosen(part)
					end
				end)
				explosion.Parent = workspace
				meteor:Destroy()
			end)
			Debris:AddItem(meteor, 8)
		end
		task.wait(1.2)
	end
end

function disasters.Tornado(buildings, roundEnd)
	local position = randomIslandPoint(30)
	local core = newPart(arena, CFrame.new(position + Vector3.new(0, 40, 0)), Vector3.new(80, 30, 30), Color3.fromRGB(120, 120, 120), {
		Shape = Enum.PartType.Cylinder, Transparency = 0.6, CanCollide = false, CanTouch = false, Material = Enum.Material.SmoothPlastic, Name = "Tornado",
	})
	local smoke = Instance.new("Smoke")
	smoke.Size = 20
	smoke.RiseVelocity = 25
	smoke.Color = Color3.fromRGB(100, 100, 100)
	smoke.Parent = core
	local target = randomIslandPoint(20)
	local angle = 0
	while os.clock() < roundEnd do
		if (Vector3.new(position.X, 0, position.Z) - target).Magnitude < 5 then
			target = randomIslandPoint(20)
		end
		position = position + (target - position).Unit * 1.2
		angle = angle + 0.5
		core.CFrame = CFrame.new(position.X, 40, position.Z) * CFrame.Angles(0, angle, math.pi / 2)
		for _, c in ipairs(aliveCharacters()) do
			local offset = Vector3.new(c.root.Position.X - position.X, 0, c.root.Position.Z - position.Z)
			if offset.Magnitude < 16 then
				local tangent = Vector3.new(-offset.Z, 0, offset.X).Unit
				c.root.AssemblyLinearVelocity = tangent * 60 + Vector3.new(0, 45, 0)
				c.humanoid:TakeDamage(4)
			end
		end
		for _, part in ipairs(buildings:GetDescendants()) do
			if part:IsA("BasePart") then
				local offset = Vector3.new(part.Position.X - position.X, 0, part.Position.Z - position.Z)
				if offset.Magnitude < 14 then
					loosen(part, Vector3.new(-offset.Z, 30, offset.X).Unit * 70)
				end
			end
		end
		task.wait(0.1)
	end
end

function disasters.Earthquake(buildings, roundEnd)
	shake.Value = true
	-- Wer drinnen bleibt, bekommt herabfallende Trümmer ab
	task.spawn(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { buildings }
		while os.clock() < roundEnd do
			for _, c in ipairs(aliveCharacters()) do
				if workspace:Raycast(c.root.Position, Vector3.new(0, 40, 0), params) then
					c.humanoid:TakeDamage(6)
				end
			end
			task.wait(0.6)
		end
	end)
	local parts = {}
	for _, part in ipairs(buildings:GetDescendants()) do
		if part:IsA("BasePart") then
			table.insert(parts, part)
		end
	end
	while os.clock() < roundEnd and #parts > 0 do
		for _ = 1, math.max(1, math.floor(#parts / 30)) do
			if #parts == 0 then
				break
			end
			local part = table.remove(parts, rng:NextInteger(1, #parts))
			loosen(part, Vector3.new(rng:NextNumber(-10, 10), rng:NextNumber(0, 15), rng:NextNumber(-10, 10)))
		end
		task.wait(0.6)
	end
	while os.clock() < roundEnd do
		task.wait(0.5)
	end
	shake.Value = false
end

function disasters.AcidRain(_, roundEnd)
	local cloud = newPart(arena, CFrame.new(0, 70, 0), Vector3.new(ISLAND_SIZE, 2, ISLAND_SIZE), Color3.fromRGB(80, 90, 70), {
		Transparency = 0.4, CanCollide = false, CanTouch = false, CanQuery = false, Name = "AcidCloud",
	})
	local rain = Instance.new("ParticleEmitter")
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.Color = ColorSequence.new(Color3.fromRGB(150, 255, 80))
	rain.Speed = NumberRange.new(60)
	rain.Lifetime = NumberRange.new(1.2)
	rain.Rate = 600
	rain.Size = NumberSequence.new(0.25)
	rain.Parent = cloud
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	while os.clock() < roundEnd do
		for _, c in ipairs(aliveCharacters()) do
			params.FilterDescendantsInstances = { c.root.Parent, cloud }
			local hit = workspace:Raycast(c.root.Position, Vector3.new(0, 60, 0), params)
			if not hit then
				c.humanoid:TakeDamage(5)
			end
		end
		task.wait(0.5)
	end
end

local DISASTER_NAMES = { "Flood", "Lava", "Meteors", "Tornado", "Earthquake", "AcidRain" }
local DISASTER_TITLES = {
	Flood = "🌊 FLOOD! Get up high!",
	Lava = "🌋 LAVA RISING! Climb a roof!",
	Meteors = "☄ METEOR SHOWER! Take cover!",
	Tornado = "🌪 TORNADO! Run away!",
	Earthquake = "🫨 EARTHQUAKE! Get out of the buildings!",
	AcidRain = "☣ ACID RAIN! Stay under a roof!",
}

---------------------------------------------------------------------
-- Runden-Schleife
---------------------------------------------------------------------
local function countdown(prefix, seconds)
	for t = seconds, 1, -1 do
		status.Value = prefix .. " " .. t
		task.wait(1)
	end
end

local function rewardSurvivors()
	local names = {}
	for player in pairs(alive) do
		local d = sessionData[player]
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if d and humanoid and humanoid.Health > 0 then
			local coins = CONFIG.SURVIVE_COINS * (player:GetAttribute("VIP") and 2 or 1)
			d.coins = d.coins + coins
			d.wins = d.wins + CONFIG.SURVIVE_WIN
			refresh(player)
			NotifyRemote:FireClient(player, "🏆 You survived! +" .. coins .. " coins")
			table.insert(names, player.DisplayName)
		end
	end
	return names
end

buildArena()
task.spawn(function()
	while true do
		if #Players:GetPlayers() == 0 then
			status.Value = "Waiting for players..."
			task.wait(2)
		else
			countdown("⏳ Intermission:", CONFIG.INTERMISSION)
			local buildings = buildArena()
			local disasterName = DISASTER_NAMES[rng:NextInteger(1, #DISASTER_NAMES)]

			alive = {}
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.Health > 0 then
					alive[player] = true
					character:PivotTo(CFrame.new(randomIslandPoint(15) + Vector3.new(0, 5, 0)))
					humanoid.Died:Connect(function()
						alive[player] = nil
					end)
				end
			end

			status.Value = "👀 Get ready... a disaster is coming!"
			task.wait(8)
			local oldClock = Lighting.ClockTime
			Lighting.ClockTime = (disasterName == "AcidRain" or disasterName == "Tornado") and 18.5 or oldClock
			local roundEnd = os.clock() + CONFIG.ROUND_TIME
			task.spawn(function()
				local ok, err = pcall(disasters[disasterName], buildings, roundEnd)
				if not ok then
					warn("Disaster error:", err)
				end
			end)
			while os.clock() < roundEnd do
				local remaining = math.ceil(roundEnd - os.clock())
				local count = 0
				for _ in pairs(alive) do
					count = count + 1
				end
				status.Value = DISASTER_TITLES[disasterName] .. "  " .. remaining .. "s  |  " .. count .. " alive"
				task.wait(0.5)
			end
			task.wait(0.6)
			shake.Value = false
			Lighting.ClockTime = oldClock

			local survivors = rewardSurvivors()
			if #survivors > 0 then
				status.Value = "🏆 Survivors: " .. table.concat(survivors, ", ")
			else
				status.Value = "💀 Nobody survived!"
			end
			for player in pairs(alive) do
				if player.Parent then
					player:LoadCharacter()
				end
			end
			alive = {}
			task.wait(5)
		end
	end
end)

---------------------------------------------------------------------
-- Käufe
---------------------------------------------------------------------
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased then
		return
	end
	if passId == CONFIG.VIP_PASS then
		player:SetAttribute("VIP", true)
	elseif passId == CONFIG.BALLOON_PASS then
		player:SetAttribute("Balloon", true)
		if player.Character then
			applyUpgrades(player, player.Character)
		end
	else
		return
	end
	NotifyRemote:FireClient(player, "🎉 Thanks for your purchase!")
end)

MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local d = player and sessionData[player]
	if not d then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local amount
	if receipt.ProductId == CONFIG.SMALL_COINS_PRODUCT then
		amount = 500
	elseif receipt.ProductId == CONFIG.BIG_COINS_PRODUCT then
		amount = 3000
	else
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	d.coins = d.coins + amount
	refresh(player)
	NotifyRemote:FireClient(player, "🎉 +" .. amount .. " coins!")
	task.spawn(saveData, player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
