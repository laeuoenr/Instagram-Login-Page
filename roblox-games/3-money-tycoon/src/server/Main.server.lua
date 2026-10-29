--[[
	MONEY TYCOON - Server
	Platzieren in: ServerScriptService (als Script)
	WICHTIG: In den Game Settings die Max. Spielerzahl auf 6 stellen (= Anzahl Grundstücke).
]]

local CONFIG = {
	DATASTORE = "MoneyTycoon_v1",
	START_CASH = 50,
	DROP_INTERVAL = 2,
	ORE_LIFETIME = 20,
	REBIRTH_BASE_COST = 1000000,
	-- IDs aus dem Creator Dashboard (0 = deaktiviert)
	DOUBLE_CASH_PASS = 0,
	AUTO_COLLECT_PASS = 0,
	SMALL_CASH_PRODUCT = 0, -- 10 Minuten Einkommen
	BIG_CASH_PRODUCT = 0, -- 60 Minuten Einkommen
}

-- Shop-Items. "requires" = muss vorher gekauft sein. "button" = Position des Kauf-Knopfs auf dem Grundstück.
local ITEMS = {
	{ id = "dropper1", name = "Dropper", cost = 50, kind = "dropper", value = 5, x = -22, button = Vector2.new(-24, 8) },
	{ id = "dropper2", name = "Dropper", cost = 175, kind = "dropper", value = 8, x = -17, requires = "dropper1", button = Vector2.new(-18, 8) },
	{ id = "walls", name = "Walls", cost = 300, kind = "walls", requires = "dropper1", button = Vector2.new(-24, 14) },
	{ id = "upgrader1", name = "Upgrader x2", cost = 600, kind = "upgrader", mult = 2, x = 18, requires = "dropper2", button = Vector2.new(-12, 8) },
	{ id = "dropper3", name = "Dropper", cost = 1000, kind = "dropper", value = 15, x = -12, requires = "upgrader1", button = Vector2.new(-6, 8) },
	{ id = "windows", name = "Windows", cost = 1500, kind = "windows", requires = "walls", button = Vector2.new(-18, 14) },
	{ id = "dropper4", name = "Dropper", cost = 2500, kind = "dropper", value = 25, x = -7, requires = "dropper3", button = Vector2.new(0, 8) },
	{ id = "lamps", name = "Lamps", cost = 4000, kind = "lamps", requires = "windows", button = Vector2.new(-12, 14) },
	{ id = "roof", name = "Roof", cost = 7500, kind = "roof", requires = "lamps", button = Vector2.new(-6, 14) },
	{ id = "mega", name = "Mega Dropper", cost = 12000, kind = "dropper", value = 80, x = -2, requires = "dropper4", button = Vector2.new(6, 8) },
	{ id = "upgrader2", name = "Upgrader x1.5", cost = 25000, kind = "upgrader", mult = 1.5, x = 22, requires = "mega", button = Vector2.new(12, 8) },
	{ id = "fountain", name = "Fountain", cost = 40000, kind = "fountain", requires = "roof", button = Vector2.new(0, 14) },
	{ id = "golden", name = "Golden Dropper", cost = 60000, kind = "dropper", value = 250, x = 3, requires = "upgrader2", button = Vector2.new(18, 8) },
	{ id = "diamond", name = "Diamond Dropper", cost = 175000, kind = "dropper", value = 800, x = 8, requires = "golden", button = Vector2.new(24, 8) },
	{ id = "tower", name = "Tower", cost = 400000, kind = "tower", requires = "fountain", button = Vector2.new(6, 14) },
	{ id = "rainbow", name = "Rainbow Dropper", cost = 1000000, kind = "dropper", value = 3000, x = 13, requires = "diamond", button = Vector2.new(24, 14) },
}
local ITEM_BY_ID = {}
for _, item in ipairs(ITEMS) do
	ITEM_BY_ID[item.id] = item
end

local DROPPER_COLORS = {
	dropper1 = Color3.fromRGB(160, 160, 160), dropper2 = Color3.fromRGB(160, 160, 160),
	dropper3 = Color3.fromRGB(120, 120, 200), dropper4 = Color3.fromRGB(120, 200, 120),
	mega = Color3.fromRGB(255, 120, 0), golden = Color3.fromRGB(255, 215, 0),
	diamond = Color3.fromRGB(120, 230, 255), rainbow = Color3.fromRGB(255, 80, 200),
}

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local store = DataStoreService:GetDataStore(CONFIG.DATASTORE)

---------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "TycoonRemotes"
local function makeRemote(name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local NotifyRemote = makeRemote("Notify")
local RebirthRemote = makeRemote("Rebirth")
local configFolder = Instance.new("Configuration")
configFolder.Name = "Config"
configFolder.Parent = remotes
for _, key in ipairs({ "DOUBLE_CASH_PASS", "AUTO_COLLECT_PASS", "SMALL_CASH_PRODUCT", "BIG_CASH_PRODUCT" }) do
	local v = Instance.new("IntValue")
	v.Name = key
	v.Value = CONFIG[key]
	v.Parent = configFolder
end
remotes.Parent = ReplicatedStorage

local function formatNumber(n)
	local suffixes = { "", "K", "M", "B", "T", "Qd" }
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

local function rebirthCost(rebirths)
	return CONFIG.REBIRTH_BASE_COST * (rebirths + 1)
end

---------------------------------------------------------------------
-- Bau-Helfer
---------------------------------------------------------------------
local defaultSpawn = workspace:FindFirstChild("SpawnLocation")
if defaultSpawn then
	defaultSpawn:Destroy()
end

local tycoonsFolder = Instance.new("Folder")
tycoonsFolder.Name = "Tycoons"
tycoonsFolder.Parent = workspace

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

local function billboard(parent, text, offset, color)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(180, 50)
	gui.StudsOffset = offset or Vector3.new(0, 3, 0)
	gui.MaxDistance = 80
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.Parent = gui
	return label
end

local function playerFromHit(hit)
	local model = hit:FindFirstAncestorOfClass("Model")
	if not model then
		return nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return Players:GetPlayerFromCharacter(model)
end

---------------------------------------------------------------------
-- Grundstücke
---------------------------------------------------------------------
local plots = {}
local sessionData = {}

local PLOT_POSITIONS = {
	CFrame.new(-90, 0, -70), CFrame.new(0, 0, -70), CFrame.new(90, 0, -70),
	CFrame.new(-90, 0, 70) * CFrame.Angles(0, math.pi, 0),
	CFrame.new(0, 0, 70) * CFrame.Angles(0, math.pi, 0),
	CFrame.new(90, 0, 70) * CFrame.Angles(0, math.pi, 0),
}

local function plotCF(plot, x, y, z)
	return plot.cframe * CFrame.new(x, y, z)
end

local function getCash(player)
	local d = sessionData[player]
	return d and d.cash or 0
end

local function setCash(player, value)
	local d = sessionData[player]
	if not d then
		return
	end
	d.cash = value
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		ls.Cash.Value = math.floor(value)
	end
end

local function cashMultiplier(player)
	local d = sessionData[player]
	local mult = 1 + (d and d.rebirths or 0) * 0.5
	if player:GetAttribute("DoubleCash") then
		mult = mult * 2
	end
	return mult
end

local function updateCollectLabel(plot)
	plot.collectLabel.Text = "💰 Collect $" .. formatNumber(plot.pending)
end

local buildItem -- vorwärts deklariert
local refreshButtons

local function spawnOre(plot, item)
	if not plot.owner then
		return
	end
	local ore = Instance.new("Part")
	ore.Name = "Ore"
	ore.Size = Vector3.new(1.2, 1.2, 1.2)
	ore.Color = DROPPER_COLORS[item.id] or Color3.new(1, 1, 1)
	ore.Material = (item.value >= 250) and Enum.Material.Neon or Enum.Material.SmoothPlastic
	ore.CFrame = plotCF(plot, item.x, 5.5, -15)
	ore:SetAttribute("Value", item.value)
	ore:SetAttribute("Plot", plot.index)
	ore.Parent = plot.oreFolder
	ore:SetNetworkOwner(nil)
	Debris:AddItem(ore, CONFIG.ORE_LIFETIME)
end

local builders = {}

function builders.dropper(plot, item, folder)
	local color = DROPPER_COLORS[item.id] or Color3.new(0.6, 0.6, 0.6)
	newPart(folder, plotCF(plot, item.x, 8, -15), Vector3.new(3.5, 3, 3.5), color, { Material = Enum.Material.Metal })
	newPart(folder, plotCF(plot, item.x, 6.25, -15), Vector3.new(1.8, 0.5, 1.8), Color3.fromRGB(30, 30, 30))
	newPart(folder, plotCF(plot, item.x, 5.5, -18.5), Vector3.new(0.6, 9, 0.6), Color3.fromRGB(60, 60, 60))
	task.spawn(function()
		while folder.Parent do
			spawnOre(plot, item)
			task.wait(CONFIG.DROP_INTERVAL)
		end
	end)
end

function builders.upgrader(plot, item, folder)
	local frameColor = Color3.fromRGB(80, 80, 90)
	newPart(folder, plotCF(plot, item.x, 3.5, -18.75), Vector3.new(1, 5, 1), frameColor)
	newPart(folder, plotCF(plot, item.x, 3.5, -11.25), Vector3.new(1, 5, 1), frameColor)
	newPart(folder, plotCF(plot, item.x, 6.5, -15), Vector3.new(1, 1, 8.5), frameColor)
	local beam = newPart(folder, plotCF(plot, item.x, 3.5, -15), Vector3.new(0.6, 5, 6.5), Color3.fromRGB(0, 255, 160), {
		Material = Enum.Material.Neon,
		Transparency = 0.4,
		CanCollide = false,
	})
	local tag = "Up_" .. item.id
	beam.Touched:Connect(function(hit)
		if hit.Name == "Ore" and not hit:GetAttribute(tag) then
			hit:SetAttribute(tag, true)
			hit:SetAttribute("Value", (hit:GetAttribute("Value") or 0) * item.mult)
		end
	end)
end

function builders.walls(plot, _, folder)
	local color = Color3.fromRGB(230, 225, 210)
	newPart(folder, plotCF(plot, 0, 6, -29.5), Vector3.new(60, 12, 1), color)
	newPart(folder, plotCF(plot, -29.5, 6, 0), Vector3.new(1, 12, 60), color)
	newPart(folder, plotCF(plot, 29.5, 6, 0), Vector3.new(1, 12, 60), color)
	newPart(folder, plotCF(plot, -18, 6, 29.5), Vector3.new(24, 12, 1), color)
	newPart(folder, plotCF(plot, 18, 6, 29.5), Vector3.new(24, 12, 1), color)
end

function builders.windows(plot, _, folder)
	local glass = Color3.fromRGB(150, 210, 255)
	local props = { Material = Enum.Material.Glass, Transparency = 0.4 }
	newPart(folder, plotCF(plot, 0, 7, -29.6), Vector3.new(40, 4, 1.2), glass, props)
	newPart(folder, plotCF(plot, -29.6, 7, 0), Vector3.new(1.2, 4, 40), glass, props)
	newPart(folder, plotCF(plot, 29.6, 7, 0), Vector3.new(1.2, 4, 40), glass, props)
end

function builders.lamps(plot, _, folder)
	for _, pos in ipairs({ Vector2.new(-26, -26), Vector2.new(26, -26), Vector2.new(-26, 26), Vector2.new(26, 26) }) do
		newPart(folder, plotCF(plot, pos.X, 4, pos.Y), Vector3.new(0.6, 8, 0.6), Color3.fromRGB(40, 40, 40))
		local bulb = newPart(folder, plotCF(plot, pos.X, 8.5, pos.Y), Vector3.new(1.5, 1.5, 1.5), Color3.fromRGB(255, 240, 180), {
			Material = Enum.Material.Neon,
			Shape = Enum.PartType.Ball,
		})
		local light = Instance.new("PointLight")
		light.Range = 20
		light.Brightness = 2
		light.Parent = bulb
	end
end

function builders.roof(plot, _, folder)
	newPart(folder, plotCF(plot, 0, 12.5, 0), Vector3.new(61, 1, 61), Color3.fromRGB(150, 60, 50), { Material = Enum.Material.Brick })
end

function builders.fountain(plot, _, folder)
	newPart(folder, plotCF(plot, -15, 0.5, 22) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(1, 8, 8), Color3.fromRGB(200, 200, 210), {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Marble,
	})
	newPart(folder, plotCF(plot, -15, 1.05, 22) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(0.2, 7, 7), Color3.fromRGB(60, 150, 255), {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Glass,
		Transparency = 0.3,
	})
	local spout = newPart(folder, plotCF(plot, -15, 2.5, 22), Vector3.new(1, 3, 1), Color3.fromRGB(200, 200, 210), { Material = Enum.Material.Marble })
	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(Color3.fromRGB(120, 190, 255))
	particles.Speed = NumberRange.new(8, 10)
	particles.SpreadAngle = Vector2.new(15, 15)
	particles.Acceleration = Vector3.new(0, -25, 0)
	particles.Lifetime = NumberRange.new(0.8, 1)
	particles.Rate = 40
	particles.Size = NumberSequence.new(0.3)
	particles.Parent = spout
end

function builders.tower(plot, _, folder)
	local color = Color3.fromRGB(240, 200, 80)
	newPart(folder, plotCF(plot, 22, 20, 20), Vector3.new(6, 40, 6), color, { Material = Enum.Material.Marble })
	newPart(folder, plotCF(plot, 22, 41, 20), Vector3.new(8, 2, 8), Color3.fromRGB(255, 215, 0), { Material = Enum.Material.Neon })
	billboard(folder:FindFirstChildWhichIsA("BasePart") or folder, "👑 " .. (plot.owner and plot.owner.Name or ""), Vector3.new(0, 24, 0), Color3.fromRGB(255, 215, 0))
end

function buildItem(plot, item)
	local folder = Instance.new("Folder")
	folder.Name = item.id
	folder.Parent = plot.itemsFolder
	builders[item.kind](plot, item, folder)
end

local function clearPlot(plot)
	plot.itemsFolder:ClearAllChildren()
	plot.buttonsFolder:ClearAllChildren()
	plot.oreFolder:ClearAllChildren()
	plot.pending = 0
	updateCollectLabel(plot)
end

local function tryBuy(player, plot, item)
	local d = sessionData[player]
	if not d or plot.owner ~= player or d.purchased[item.id] then
		return
	end
	if d.cash < item.cost then
		NotifyRemote:FireClient(player, "Not enough cash! Need $" .. formatNumber(item.cost))
		return
	end
	setCash(player, d.cash - item.cost)
	d.purchased[item.id] = true
	buildItem(plot, item)
	refreshButtons(plot)
end

function refreshButtons(plot)
	plot.buttonsFolder:ClearAllChildren()
	local owner = plot.owner
	local d = owner and sessionData[owner]
	if not d then
		return
	end
	for _, item in ipairs(ITEMS) do
		local available = not d.purchased[item.id] and (not item.requires or d.purchased[item.requires])
		if available then
			local btn = newPart(plot.buttonsFolder, plotCF(plot, item.button.X, 0.6, item.button.Y), Vector3.new(4, 0.4, 4), Color3.fromRGB(60, 220, 90), {
				Material = Enum.Material.Neon,
			})
			billboard(btn, item.name .. "\n$" .. formatNumber(item.cost), Vector3.new(0, 3, 0))
			local busy = false
			btn.Touched:Connect(function(hit)
				if busy or playerFromHit(hit) ~= owner then
					return
				end
				busy = true
				tryBuy(owner, plot, item)
				task.wait(0.5)
				busy = false
			end)
		end
	end
end

local function collect(plot)
	local owner = plot.owner
	if owner and plot.pending > 0 then
		setCash(owner, getCash(owner) + plot.pending)
		plot.pending = 0
		updateCollectLabel(plot)
	end
end

for index, cf in ipairs(PLOT_POSITIONS) do
	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model.Parent = tycoonsFolder
	local plot = { index = index, cframe = cf, model = model, owner = nil, pending = 0 }
	plots[index] = plot

	newPart(model, plotCF(plot, 0, 0.25, 0), Vector3.new(60, 0.5, 60), Color3.fromRGB(110, 110, 120), { Material = Enum.Material.Concrete })

	plot.itemsFolder = Instance.new("Folder")
	plot.itemsFolder.Name = "Items"
	plot.itemsFolder.Parent = model
	plot.buttonsFolder = Instance.new("Folder")
	plot.buttonsFolder.Name = "Buttons"
	plot.buttonsFolder.Parent = model
	plot.oreFolder = Instance.new("Folder")
	plot.oreFolder.Name = "Ore"
	plot.oreFolder.Parent = model

	-- Förderband
	local conveyor = newPart(model, plotCF(plot, 0, 1, -15), Vector3.new(50, 1, 6), Color3.fromRGB(40, 40, 40), { Material = Enum.Material.DiamondPlate })
	conveyor.AssemblyLinearVelocity = plot.cframe.RightVector * 8
	newPart(model, plotCF(plot, 0, 2, -18.25), Vector3.new(50, 2, 0.5), Color3.fromRGB(255, 200, 0))
	newPart(model, plotCF(plot, 0, 2, -11.75), Vector3.new(50, 2, 0.5), Color3.fromRGB(255, 200, 0))

	-- Sammler am Ende des Bands
	local collector = newPart(model, plotCF(plot, 27, 2, -15), Vector3.new(4, 3, 8), Color3.fromRGB(255, 80, 80), { Material = Enum.Material.Neon })
	billboard(collector, "SELL", Vector3.new(0, 3, 0))
	collector.Touched:Connect(function(hit)
		if hit.Name ~= "Ore" or hit:GetAttribute("Plot") ~= index or hit:GetAttribute("Sold") then
			return
		end
		hit:SetAttribute("Sold", true)
		local owner = plot.owner
		local value = (hit:GetAttribute("Value") or 0) * (owner and cashMultiplier(owner) or 1)
		hit:Destroy()
		if owner and owner:GetAttribute("AutoCollect") then
			setCash(owner, getCash(owner) + value)
		else
			plot.pending = plot.pending + value
			updateCollectLabel(plot)
		end
	end)

	-- Einsammel-Platte
	local pad = newPart(model, plotCF(plot, 24, 0.6, 0), Vector3.new(6, 0.4, 6), Color3.fromRGB(255, 215, 0), { Material = Enum.Material.Neon })
	plot.collectLabel = billboard(pad, "", Vector3.new(0, 4, 0), Color3.fromRGB(255, 230, 120))
	updateCollectLabel(plot)
	pad.Touched:Connect(function(hit)
		if plot.owner and playerFromHit(hit) == plot.owner then
			collect(plot)
		end
	end)

	-- Spawn + Schild
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = plotCF(plot, 0, 0.5, 24)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = model
	plot.spawn = spawn

	local sign = newPart(model, plotCF(plot, 0, 6, 31), Vector3.new(16, 4, 1), Color3.fromRGB(30, 30, 40))
	plot.signLabel = billboard(sign, "🏠 Free Plot", Vector3.new(0, 0, 0))
	plot.signLabel.Parent.Size = UDim2.fromOffset(260, 60)
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
	local purchased = {}
	for _, id in ipairs(data.purchased or {}) do
		if ITEM_BY_ID[id] then
			purchased[id] = true
		end
	end
	return {
		cash = tonumber(data.cash) or CONFIG.START_CASH,
		rebirths = tonumber(data.rebirths) or 0,
		purchased = purchased,
		loaded = success == true,
	}
end

local function saveData(player)
	local d = sessionData[player]
	if not d or not d.loaded then
		return
	end
	local list = {}
	for id in pairs(d.purchased) do
		table.insert(list, id)
	end
	for _ = 1, 3 do
		local ok = pcall(function()
			store:SetAsync("u_" .. player.UserId, { cash = d.cash, rebirths = d.rebirths, purchased = list })
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

local function plotOf(player)
	for _, plot in ipairs(plots) do
		if plot.owner == player then
			return plot
		end
	end
	return nil
end

local function rebuildPlot(plot)
	clearPlot(plot)
	local d = plot.owner and sessionData[plot.owner]
	if not d then
		return
	end
	for _, item in ipairs(ITEMS) do
		if d.purchased[item.id] then
			buildItem(plot, item)
		end
	end
	refreshButtons(plot)
end

-- Ungefähres Einkommen pro Sekunde (für Cash-Pakete)
local function incomePerSecond(player)
	local d = sessionData[player]
	if not d then
		return 0
	end
	local base, mult = 0, 1
	for _, item in ipairs(ITEMS) do
		if d.purchased[item.id] then
			if item.kind == "dropper" then
				base = base + item.value
			elseif item.kind == "upgrader" then
				mult = mult * item.mult
			end
		end
	end
	return math.max(5, base * mult * cashMultiplier(player) / CONFIG.DROP_INTERVAL)
end

Players.PlayerAdded:Connect(function(player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	ls.Parent = player
	local cash = Instance.new("NumberValue")
	cash.Name = "Cash"
	cash.Parent = ls
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = ls

	player:SetAttribute("DoubleCash", ownsPass(player, CONFIG.DOUBLE_CASH_PASS))
	player:SetAttribute("AutoCollect", ownsPass(player, CONFIG.AUTO_COLLECT_PASS))

	local d = loadData(player)
	if not player.Parent then
		return
	end
	sessionData[player] = d
	setCash(player, d.cash)
	rebirths.Value = d.rebirths
	player:SetAttribute("RebirthCost", rebirthCost(d.rebirths))
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
		NotifyRemote:FireClient(player, "All plots are taken - please join another server!")
		return
	end
	free.owner = player
	free.signLabel.Text = "🏠 " .. player.DisplayName .. "'s Tycoon"
	player.RespawnLocation = free.spawn
	rebuildPlot(free)
	if player.Character then
		player.Character:PivotTo(free.spawn.CFrame + Vector3.new(0, 4, 0))
	end
end)

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
	local plot = plotOf(player)
	if plot then
		plot.owner = nil
		clearPlot(plot)
		plot.signLabel.Text = "🏠 Free Plot"
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
-- Rebirth
---------------------------------------------------------------------
RebirthRemote.OnServerEvent:Connect(function(player)
	local d = sessionData[player]
	local plot = plotOf(player)
	if not d or not plot then
		return
	end
	local cost = rebirthCost(d.rebirths)
	if d.cash < cost then
		NotifyRemote:FireClient(player, "You need $" .. formatNumber(cost) .. " to rebirth!")
		return
	end
	d.rebirths = d.rebirths + 1
	d.purchased = {}
	setCash(player, CONFIG.START_CASH)
	player.leaderstats.Rebirths.Value = d.rebirths
	player:SetAttribute("RebirthCost", rebirthCost(d.rebirths))
	rebuildPlot(plot)
	NotifyRemote:FireClient(player, "🌟 REBIRTH! Permanent cash bonus: +" .. (d.rebirths * 50) .. "%")
	task.spawn(saveData, player)
end)

---------------------------------------------------------------------
-- Käufe
---------------------------------------------------------------------
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased then
		return
	end
	if passId == CONFIG.DOUBLE_CASH_PASS then
		player:SetAttribute("DoubleCash", true)
	elseif passId == CONFIG.AUTO_COLLECT_PASS then
		player:SetAttribute("AutoCollect", true)
		local plot = plotOf(player)
		if plot then
			collect(plot)
		end
	else
		return
	end
	NotifyRemote:FireClient(player, "🎉 Thanks for your purchase!")
end)

MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player or not sessionData[player] then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local amount
	if receipt.ProductId == CONFIG.SMALL_CASH_PRODUCT then
		amount = incomePerSecond(player) * 600
	elseif receipt.ProductId == CONFIG.BIG_CASH_PRODUCT then
		amount = incomePerSecond(player) * 3600
	else
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	setCash(player, getCash(player) + amount)
	NotifyRemote:FireClient(player, "🎉 +$" .. formatNumber(amount) .. "!")
	task.spawn(saveData, player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
