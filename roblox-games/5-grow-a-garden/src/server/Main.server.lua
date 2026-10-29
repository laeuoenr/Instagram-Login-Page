--[[
	GARDEN GROW - Server
	Platzieren in: ServerScriptService (als Script)
	WICHTIG: In den Game Settings die Max. Spielerzahl auf 6 stellen (= Anzahl Gärten).
	Samen kaufen -> pflanzen -> wächst (auch offline!) -> ernten (Mutationen!) -> verkaufen.
]]

local CONFIG = {
	DATASTORE = "GardenGrow_v1",
	START_MONEY = 20,
	RESTOCK_SECONDS = 300,
	MAX_FRUITS = 300,
	-- IDs aus dem Creator Dashboard (0 = deaktiviert)
	DOUBLE_SELL_PASS = 0,
	LUCKY_PASS = 0, -- doppelte Mutations-Chance
	INSTANT_GROW_PRODUCT = 0, -- alle Pflanzen sofort fertig
	RESTOCK_PRODUCT = 0, -- Shop für den ganzen Server sofort auffüllen
	MONEY_PRODUCT = 0, -- 10 Minuten Garten-Ertrag
}

-- grow/regrow in Sekunden. regrow = nil -> Pflanze verschwindet nach der Ernte
local SEEDS = {
	{ name = "Carrot", cost = 10, value = 18, grow = 30, chance = 1, stock = { 5, 20 }, color = Color3.fromRGB(255, 140, 30) },
	{ name = "Strawberry", cost = 50, value = 20, grow = 60, regrow = 40, chance = 1, stock = { 3, 12 }, color = Color3.fromRGB(230, 40, 60) },
	{ name = "Blueberry", cost = 400, value = 45, grow = 90, regrow = 50, chance = 0.8, stock = { 2, 8 }, color = Color3.fromRGB(60, 80, 230) },
	{ name = "Tomato", cost = 800, value = 70, grow = 120, regrow = 60, chance = 0.7, stock = { 1, 6 }, color = Color3.fromRGB(240, 50, 40) },
	{ name = "Corn", cost = 1300, value = 130, grow = 150, regrow = 80, chance = 0.6, stock = { 1, 5 }, color = Color3.fromRGB(250, 220, 60) },
	{ name = "Watermelon", cost = 2500, value = 900, grow = 240, chance = 0.4, stock = { 1, 4 }, color = Color3.fromRGB(60, 170, 60) },
	{ name = "Pumpkin", cost = 3000, value = 1200, grow = 300, chance = 0.35, stock = { 1, 3 }, color = Color3.fromRGB(255, 120, 0) },
	{ name = "Dragon Fruit", cost = 50000, value = 2500, grow = 480, regrow = 240, chance = 0.15, stock = { 1, 2 }, color = Color3.fromRGB(255, 60, 170) },
	{ name = "Mango", cost = 100000, value = 4000, grow = 600, regrow = 300, chance = 0.1, stock = { 1, 2 }, color = Color3.fromRGB(255, 190, 40) },
	{ name = "Golden Apple", cost = 1000000, value = 20000, grow = 900, regrow = 400, chance = 0.03, stock = { 1, 1 }, color = Color3.fromRGB(255, 215, 0) },
}
local SEED_BY_NAME = {}
for i, seed in ipairs(SEEDS) do
	seed.order = i
	SEED_BY_NAME[seed.name] = seed
end

local MUTATIONS = {
	{ name = "Rainbow", mult = 50, chance = 0.003 },
	{ name = "Gold", mult = 20, chance = 0.02 },
	{ name = "Shiny", mult = 3, chance = 0.08 },
}

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local store = DataStoreService:GetDataStore(CONFIG.DATASTORE)
local rng = Random.new()

---------------------------------------------------------------------
-- Remotes & geteilte Infos
---------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "GardenRemotes"
local function makeRemote(name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local NotifyRemote = makeRemote("Notify")
local BuySeedRemote = makeRemote("BuySeed")
local SelectSeedRemote = makeRemote("SelectSeed")
local OpenShopRemote = makeRemote("OpenShop")
local SellRemote = makeRemote("Sell")

local configFolder = Instance.new("Configuration")
configFolder.Name = "Config"
configFolder.Parent = remotes
for _, key in ipairs({ "DOUBLE_SELL_PASS", "LUCKY_PASS", "INSTANT_GROW_PRODUCT", "RESTOCK_PRODUCT", "MONEY_PRODUCT" }) do
	local v = Instance.new("IntValue")
	v.Name = key
	v.Value = CONFIG[key]
	v.Parent = configFolder
end

local seedInfo = Instance.new("Folder")
seedInfo.Name = "Seeds"
seedInfo.Parent = remotes
local stockValues = {}
for _, seed in ipairs(SEEDS) do
	local info = Instance.new("IntValue") -- Value = aktueller Bestand im Shop
	info.Name = seed.name
	info:SetAttribute("Cost", seed.cost)
	info:SetAttribute("Order", seed.order)
	info:SetAttribute("Color", seed.color)
	info:SetAttribute("Regrows", seed.regrow ~= nil)
	info.Parent = seedInfo
	stockValues[seed.name] = info
end
local restockAt = Instance.new("IntValue")
restockAt.Name = "RestockAt"
restockAt.Parent = remotes
remotes.Parent = ReplicatedStorage

local function formatNumber(n)
	local suffixes = { "", "K", "M", "B", "T" }
	local i = 1
	while n >= 1000 and i < #suffixes do
		n = n / 1000
		i = i + 1
	end
	if i == 1 then
		return tostring(math.floor(n))
	end
	return string.format("%.1f%s", n, suffixes[i])
end

---------------------------------------------------------------------
-- Shop-Bestand
---------------------------------------------------------------------
local function restock()
	for _, seed in ipairs(SEEDS) do
		if rng:NextNumber() <= seed.chance then
			stockValues[seed.name].Value = rng:NextInteger(seed.stock[1], seed.stock[2])
		else
			stockValues[seed.name].Value = 0
		end
	end
	restockAt.Value = os.time() + CONFIG.RESTOCK_SECONDS
end
restock()
task.spawn(function()
	while true do
		task.wait(1)
		if os.time() >= restockAt.Value then
			restock()
			NotifyRemote:FireAllClients("🌱 The seed shop has been restocked!")
		end
	end
end)

---------------------------------------------------------------------
-- Welt
---------------------------------------------------------------------
local defaultSpawn = workspace:FindFirstChild("SpawnLocation")
if defaultSpawn then
	defaultSpawn:Destroy()
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

local function billboard(parent, text, offset, size)
	local gui = Instance.new("BillboardGui")
	gui.Size = size or UDim2.fromOffset(160, 44)
	gui.StudsOffset = offset or Vector3.new(0, 3, 0)
	gui.MaxDistance = 70
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.Parent = gui
	return label
end

local world = Instance.new("Folder")
world.Name = "GardenWorld"
world.Parent = workspace

-- Markt in der Mitte
local function stand(position, color, title)
	local counter = newPart(world, CFrame.new(position + Vector3.new(0, 1.5, 0)), Vector3.new(14, 3, 6), Color3.fromRGB(140, 95, 60), { Material = Enum.Material.WoodPlanks })
	newPart(world, CFrame.new(position + Vector3.new(-6.5, 5, 0)), Vector3.new(1, 10, 1), Color3.fromRGB(110, 75, 45))
	newPart(world, CFrame.new(position + Vector3.new(6.5, 5, 0)), Vector3.new(1, 10, 1), Color3.fromRGB(110, 75, 45))
	local roof = newPart(world, CFrame.new(position + Vector3.new(0, 10.5, 0)), Vector3.new(16, 1, 8), color)
	billboard(roof, title, Vector3.new(0, 3, 0), UDim2.fromOffset(240, 60))
	local prompt = Instance.new("ProximityPrompt")
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter
	return prompt
end

local seedPrompt = stand(Vector3.new(-14, 0, 0), Color3.fromRGB(80, 200, 90), "🌱 SEED SHOP")
seedPrompt.ActionText = "Open Shop"
seedPrompt.ObjectText = "Seeds"
local sellPrompt = stand(Vector3.new(14, 0, 0), Color3.fromRGB(255, 190, 40), "💰 SELL FRUITS")
sellPrompt.ActionText = "Sell All"
sellPrompt.ObjectText = "Fruits"

local hubSpawn = Instance.new("SpawnLocation")
hubSpawn.Anchored = true
hubSpawn.Size = Vector3.new(8, 1, 8)
hubSpawn.CFrame = CFrame.new(0, 0.5, 12)
hubSpawn.Neutral = true
hubSpawn.Duration = 0
hubSpawn.Transparency = 1
hubSpawn.CanCollide = false
hubSpawn.Parent = world

-- Gärten
local TILE_COLS, TILE_ROWS = 6, 4
local TILE_SIZE, TILE_STEP = 6, 7.5
local PLOT_POSITIONS = {
	CFrame.new(-60, 0, -60), CFrame.new(0, 0, -60), CFrame.new(60, 0, -60),
	CFrame.new(-60, 0, 60) * CFrame.Angles(0, math.pi, 0),
	CFrame.new(0, 0, 60) * CFrame.Angles(0, math.pi, 0),
	CFrame.new(60, 0, 60) * CFrame.Angles(0, math.pi, 0),
}

local plots = {}
local sessionData = {}

local function plotOf(player)
	for _, plot in ipairs(plots) do
		if plot.owner == player then
			return plot
		end
	end
	return nil
end

local handleTile -- vorwärts deklariert

for index, cf in ipairs(PLOT_POSITIONS) do
	local model = Instance.new("Model")
	model.Name = "Garden" .. index
	model.Parent = world
	local plot = { index = index, cframe = cf, tiles = {}, owner = nil }
	plots[index] = plot

	newPart(model, cf * CFrame.new(0, 0.25, 0), Vector3.new(52, 0.5, 40), Color3.fromRGB(100, 180, 80), { Material = Enum.Material.Grass })
	-- Zaun
	for _, f in ipairs({ { 0, -20, 52, 0.5 }, { -26, 0, 0.5, 40 }, { 26, 0, 0.5, 40 }, { -16, 20, 20, 0.5 }, { 16, 20, 20, 0.5 } }) do
		newPart(model, cf * CFrame.new(f[1], 1.5, f[2]), Vector3.new(f[3], 2.5, f[4]), Color3.fromRGB(240, 240, 230))
	end

	for r = 0, TILE_ROWS - 1 do
		for c = 0, TILE_COLS - 1 do
			local x = (c - (TILE_COLS - 1) / 2) * TILE_STEP
			local z = (r - (TILE_ROWS - 1) / 2) * TILE_STEP - 2
			local soil = newPart(model, cf * CFrame.new(x, 0.6, z), Vector3.new(TILE_SIZE, 0.4, TILE_SIZE), Color3.fromRGB(110, 70, 40), {
				Material = Enum.Material.Ground,
			})
			local tileIndex = #plot.tiles + 1
			local prompt = Instance.new("ProximityPrompt")
			prompt.MaxActivationDistance = 8
			prompt.HoldDuration = 0
			prompt.RequiresLineOfSight = false
			prompt.Enabled = false
			prompt.Parent = soil
			local label = billboard(soil, "", Vector3.new(0, 4, 0), UDim2.fromOffset(110, 36))
			label.Parent.Enabled = false
			local plant = Instance.new("Folder")
			plant.Name = "Plant"
			plant.Parent = soil
			local tile = { soil = soil, prompt = prompt, label = label, plant = plant, shown = nil }
			plot.tiles[tileIndex] = tile
			prompt.Triggered:Connect(function(player)
				handleTile(player, plot, tileIndex)
			end)
		end
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = cf * CFrame.new(0, 0.5, 16)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = model
	plot.spawn = spawn

	local sign = newPart(model, cf * CFrame.new(0, 4, 21), Vector3.new(12, 3, 0.5), Color3.fromRGB(140, 95, 60), { Material = Enum.Material.WoodPlanks })
	plot.signLabel = billboard(sign, "🌻 Free Garden", Vector3.new(0, 2, 0), UDim2.fromOffset(240, 50))
end

---------------------------------------------------------------------
-- Spielerdaten
---------------------------------------------------------------------
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
	local seeds = {}
	for name, count in pairs(data.seeds or { Carrot = 3 }) do
		if SEED_BY_NAME[name] and tonumber(count) then
			seeds[name] = tonumber(count)
		end
	end
	local tiles = {}
	for key, tile in pairs(data.tiles or {}) do
		local i = tonumber(key)
		if i and i >= 1 and i <= TILE_COLS * TILE_ROWS and type(tile) == "table" and SEED_BY_NAME[tile.s] then
			tiles[i] = { s = tile.s, start = tonumber(tile.start) or os.time(), ready = tonumber(tile.ready) or os.time() }
		end
	end
	local fruits = {}
	for _, f in ipairs(data.fruits or {}) do
		if type(f) == "table" and SEED_BY_NAME[f.n] then
			table.insert(fruits, { n = f.n, m = f.m, v = tonumber(f.v) or 0 })
		end
	end
	return {
		money = tonumber(data.money) or CONFIG.START_MONEY,
		seeds = seeds,
		tiles = tiles,
		fruits = fruits,
		loaded = success == true,
	}
end

local function saveData(player)
	local d = sessionData[player]
	if not d or not d.loaded then
		return
	end
	local tiles = {}
	for i, tile in pairs(d.tiles) do
		tiles[tostring(i)] = tile
	end
	for _ = 1, 3 do
		local ok = pcall(function()
			store:SetAsync("u_" .. player.UserId, { money = d.money, seeds = d.seeds, tiles = tiles, fruits = d.fruits })
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

local function sellMultiplier(player)
	return player:GetAttribute("DoubleSell") and 2 or 1
end

local function refresh(player)
	local d = sessionData[player]
	local ls = player:FindFirstChild("leaderstats")
	if not d or not ls then
		return
	end
	ls.Sheckles.Value = math.floor(d.money)
	local total = 0
	for _, f in ipairs(d.fruits) do
		total = total + f.v
	end
	player:SetAttribute("FruitCount", #d.fruits)
	player:SetAttribute("FruitValue", math.floor(total * sellMultiplier(player)))
	player:SetAttribute("Seeds", HttpService:JSONEncode(d.seeds))
	local selected = player:GetAttribute("SelectedSeed")
	if selected and not d.seeds[selected] then
		player:SetAttribute("SelectedSeed", nil)
	end
end

---------------------------------------------------------------------
-- Pflanzen-Darstellung
---------------------------------------------------------------------
local function renderTile(plot, tileIndex)
	local tile = plot.tiles[tileIndex]
	local d = plot.owner and sessionData[plot.owner]
	local data = d and d.tiles[tileIndex]
	local now = os.time()

	if not data then
		if tile.shown ~= "empty" then
			tile.plant:ClearAllChildren()
			tile.shown = "empty"
		end
		tile.label.Parent.Enabled = false
		tile.prompt.Enabled = plot.owner ~= nil
		tile.prompt.ActionText = "Plant"
		tile.prompt.ObjectText = "Empty soil"
		return
	end

	local seed = SEED_BY_NAME[data.s]
	local total = math.max(1, data.ready - data.start)
	local progress = math.clamp((now - data.start) / total, 0, 1)
	local ready = now >= data.ready
	local stage = ready and "ready" or tostring(math.floor(progress * 5))
	local key = data.s .. ":" .. stage

	if tile.shown ~= key then
		tile.shown = key
		tile.plant:ClearAllChildren()
		local base = tile.soil.CFrame
		local height = 0.6 + progress * 3
		newPart(tile.plant, base * CFrame.new(0, 0.2 + height / 2, 0), Vector3.new(0.5, height, 0.5), Color3.fromRGB(60, 160, 50), {
			CanCollide = false, CanQuery = false, CanTouch = false,
		})
		newPart(tile.plant, base * CFrame.new(0, 0.2 + height, 0), Vector3.new(1, 1, 1) * (1 + progress * 2), Color3.fromRGB(80, 190, 70), {
			Shape = Enum.PartType.Ball, Material = Enum.Material.Grass, CanCollide = false, CanQuery = false, CanTouch = false,
		})
		if ready then
			for i = 1, 3 do
				local angle = i * math.pi * 2 / 3
				newPart(tile.plant, base * CFrame.new(math.cos(angle) * 1.4, 0.2 + height + 0.3, math.sin(angle) * 1.4), Vector3.new(1.2, 1.2, 1.2), seed.color, {
					Shape = Enum.PartType.Ball, Material = Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false, CanTouch = false,
				})
			end
		end
	end

	tile.label.Parent.Enabled = true
	if ready then
		tile.label.Text = "✨ " .. seed.name .. " READY"
		tile.prompt.Enabled = true
		tile.prompt.ActionText = "Harvest"
		tile.prompt.ObjectText = seed.name
	else
		local remaining = data.ready - now
		local timeText = remaining >= 60 and (math.floor(remaining / 60) .. "m " .. (remaining % 60) .. "s") or (remaining .. "s")
		tile.label.Text = seed.name .. " " .. timeText
		tile.prompt.Enabled = false
	end
end

local function renderPlot(plot)
	for i = 1, #plot.tiles do
		renderTile(plot, i)
	end
end

task.spawn(function()
	while true do
		task.wait(1)
		for _, plot in ipairs(plots) do
			if plot.owner then
				renderPlot(plot)
			end
		end
	end
end)

---------------------------------------------------------------------
-- Pflanzen / Ernten / Verkaufen
---------------------------------------------------------------------
local function rollMutation(player)
	local luck = player:GetAttribute("Lucky") and 2 or 1
	for _, m in ipairs(MUTATIONS) do
		if rng:NextNumber() < m.chance * luck then
			return m
		end
	end
	return nil
end

function handleTile(player, plot, tileIndex)
	local d = sessionData[player]
	if not d or plot.owner ~= player then
		NotifyRemote:FireClient(player, "This is not your garden!")
		return
	end
	local data = d.tiles[tileIndex]
	local now = os.time()
	if not data then
		local seedName = player:GetAttribute("SelectedSeed")
		if not seedName or not d.seeds[seedName] then
			NotifyRemote:FireClient(player, "Select a seed in your hotbar first! 🌱")
			return
		end
		local seed = SEED_BY_NAME[seedName]
		d.seeds[seedName] = d.seeds[seedName] - 1
		if d.seeds[seedName] <= 0 then
			d.seeds[seedName] = nil
		end
		d.tiles[tileIndex] = { s = seedName, start = now, ready = now + seed.grow }
	elseif now >= data.ready then
		if #d.fruits >= CONFIG.MAX_FRUITS then
			NotifyRemote:FireClient(player, "Your basket is full! Sell your fruits first 💰")
			return
		end
		local seed = SEED_BY_NAME[data.s]
		local weight = rng:NextNumber(0.8, 1.6)
		local mutation = rollMutation(player)
		local value = math.floor(seed.value * weight * (mutation and mutation.mult or 1))
		table.insert(d.fruits, { n = seed.name, m = mutation and mutation.name or nil, v = value })
		if mutation then
			NotifyRemote:FireClient(player, "🌈 " .. mutation.name .. " " .. seed.name .. "! Worth $" .. formatNumber(value))
		end
		if seed.regrow then
			d.tiles[tileIndex] = { s = seed.name, start = now, ready = now + seed.regrow }
		else
			d.tiles[tileIndex] = nil
		end
	else
		return
	end
	refresh(player)
	renderTile(plot, tileIndex)
end

local function sellAll(player)
	local d = sessionData[player]
	if not d then
		return
	end
	if #d.fruits == 0 then
		NotifyRemote:FireClient(player, "You have no fruits to sell. Harvest some first!")
		return
	end
	local total = 0
	for _, f in ipairs(d.fruits) do
		total = total + f.v
	end
	total = math.floor(total * sellMultiplier(player))
	d.money = d.money + total
	d.fruits = {}
	refresh(player)
	NotifyRemote:FireClient(player, "💰 Sold for $" .. formatNumber(total) .. "!")
end

sellPrompt.Triggered:Connect(sellAll)
SellRemote.OnServerEvent:Connect(function(player)
	-- Verkaufen nur in der Nähe vom Stand
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and (root.Position - sellPrompt.Parent.Position).Magnitude < 25 then
		sellAll(player)
	else
		NotifyRemote:FireClient(player, "Walk to the 💰 SELL stand in the middle!")
	end
end)

seedPrompt.Triggered:Connect(function(player)
	OpenShopRemote:FireClient(player)
end)

BuySeedRemote.OnServerEvent:Connect(function(player, seedName)
	local d = sessionData[player]
	local seed = type(seedName) == "string" and SEED_BY_NAME[seedName]
	if not d or not seed then
		return
	end
	local stock = stockValues[seed.name]
	if stock.Value <= 0 then
		NotifyRemote:FireClient(player, seed.name .. " is out of stock!")
		return
	end
	if d.money < seed.cost then
		NotifyRemote:FireClient(player, "Not enough Sheckles!")
		return
	end
	stock.Value = stock.Value - 1
	d.money = d.money - seed.cost
	d.seeds[seed.name] = (d.seeds[seed.name] or 0) + 1
	player:SetAttribute("SelectedSeed", seed.name)
	refresh(player)
end)

SelectSeedRemote.OnServerEvent:Connect(function(player, seedName)
	local d = sessionData[player]
	if d and type(seedName) == "string" and d.seeds[seedName] then
		player:SetAttribute("SelectedSeed", seedName)
	end
end)

---------------------------------------------------------------------
-- Beitreten / Verlassen
---------------------------------------------------------------------
Players.PlayerAdded:Connect(function(player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	ls.Parent = player
	local money = Instance.new("NumberValue")
	money.Name = "Sheckles"
	money.Parent = ls

	player:SetAttribute("DoubleSell", ownsPass(player, CONFIG.DOUBLE_SELL_PASS))
	player:SetAttribute("Lucky", ownsPass(player, CONFIG.LUCKY_PASS))

	local d = loadData(player)
	if not player.Parent then
		return
	end
	-- Niemand soll festhängen: wer pleite ist und nichts hat, bekommt eine Karotte
	if d.money < 10 and next(d.seeds) == nil and next(d.tiles) == nil and #d.fruits == 0 then
		d.seeds.Carrot = 1
	end
	sessionData[player] = d
	refresh(player)
	if not d.loaded then
		NotifyRemote:FireClient(player, "⚠ Data could not be loaded - progress will not be saved this session.")
	end

	local free
	for _, plot in ipairs(plots) do
		if not plot.owner then
			free = plot
			break
		end
	end
	if not free then
		NotifyRemote:FireClient(player, "All gardens are taken - please join another server!")
		return
	end
	free.owner = player
	free.signLabel.Text = "🌻 " .. player.DisplayName .. "'s Garden"
	player.RespawnLocation = free.spawn
	renderPlot(free)
	if player.Character then
		player.Character:PivotTo(free.spawn.CFrame + Vector3.new(0, 4, 0))
	end
end)

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
	local plot = plotOf(player)
	if plot then
		plot.owner = nil
		plot.signLabel.Text = "🌻 Free Garden"
		renderPlot(plot) -- räumt die Beete ab und deaktiviert die Prompts
	end
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
-- Käufe
---------------------------------------------------------------------
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased then
		return
	end
	if passId == CONFIG.DOUBLE_SELL_PASS then
		player:SetAttribute("DoubleSell", true)
	elseif passId == CONFIG.LUCKY_PASS then
		player:SetAttribute("Lucky", true)
	else
		return
	end
	refresh(player)
	NotifyRemote:FireClient(player, "🎉 Thanks for your purchase!")
end)

-- Geschätzter Ertrag pro Sekunde (für das Geld-Paket)
local function gardenIncomePerSecond(d)
	local total = 0
	for _, tile in pairs(d.tiles) do
		local seed = SEED_BY_NAME[tile.s]
		total = total + seed.value * 1.2 / (seed.regrow or seed.grow)
	end
	return math.max(5, total)
end

MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local d = player and sessionData[player]
	if not d then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local id = receipt.ProductId
	if id == CONFIG.INSTANT_GROW_PRODUCT then
		local now = os.time()
		for _, tile in pairs(d.tiles) do
			tile.ready = math.min(tile.ready, now)
		end
		local plot = plotOf(player)
		if plot then
			renderPlot(plot)
		end
		NotifyRemote:FireClient(player, "⚡ All your plants are fully grown!")
	elseif id == CONFIG.RESTOCK_PRODUCT then
		restock()
		NotifyRemote:FireAllClients("🌱 " .. player.DisplayName .. " restocked the seed shop for everyone!")
	elseif id == CONFIG.MONEY_PRODUCT then
		local amount = math.floor(gardenIncomePerSecond(d) * 600)
		d.money = d.money + amount
		refresh(player)
		NotifyRemote:FireClient(player, "💰 +$" .. formatNumber(amount) .. "!")
	else
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	task.spawn(saveData, player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
