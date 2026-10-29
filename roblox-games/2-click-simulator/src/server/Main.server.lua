--[[
	CLICK LEGENDS SIMULATOR - Server
	Platzieren in: ServerScriptService (als Script)
	Klicken -> Clicks sammeln -> Eier öffnen (Pets = Multiplikator) -> Rebirth (dauerhafter Bonus)
]]

local CONFIG = {
	DATASTORE = "ClickLegends_v1",
	LEADERBOARD_STORE = "ClickLegends_TopRebirths_v1",
	MAX_CLICKS_PER_SECOND = 15, -- Anti-Cheat für Autoclicker-Programme
	AUTO_CLICKS_PER_SECOND = 6, -- Auto-Clicker Gamepass
	EQUIPPED_PETS = 3,
	MAX_PETS = 50,
	-- IDs aus dem Creator Dashboard (0 = deaktiviert)
	DOUBLE_CLICKS_PASS = 0,
	AUTO_CLICKER_PASS = 0,
	LUCKY_PASS = 0,
	SMALL_PACK_PRODUCT = 0, -- gibt 2.000 x Multiplikator
	BIG_PACK_PRODUCT = 0, -- gibt 25.000 x Multiplikator
	INSTANT_REBIRTH_PRODUCT = 0,
}

local EGGS = {
	{
		name = "Basic Egg", cost = 100, color = Color3.fromRGB(240, 240, 240),
		pets = {
			{ name = "Dog", mult = 1.2, weight = 50 },
			{ name = "Cat", mult = 1.4, weight = 30 },
			{ name = "Bunny", mult = 1.8, weight = 15 },
			{ name = "Fox", mult = 2.5, weight = 5 },
		},
	},
	{
		name = "Rare Egg", cost = 5000, color = Color3.fromRGB(80, 160, 255),
		pets = {
			{ name = "Panda", mult = 4, weight = 50 },
			{ name = "Tiger", mult = 6, weight = 30 },
			{ name = "Unicorn", mult = 9, weight = 15 },
			{ name = "Dragon", mult = 15, weight = 5 },
		},
	},
	{
		name = "Legendary Egg", cost = 250000, color = Color3.fromRGB(255, 190, 40),
		pets = {
			{ name = "Phoenix", mult = 30, weight = 55 },
			{ name = "Kraken", mult = 50, weight = 30 },
			{ name = "Angel", mult = 80, weight = 12 },
			{ name = "Galaxy Cat", mult = 200, weight = 3 },
		},
	},
	{
		name = "Mythic Egg", cost = 25000000, color = Color3.fromRGB(200, 60, 255),
		pets = {
			{ name = "Void Dragon", mult = 500, weight = 60 },
			{ name = "Rainbow Dragon", mult = 1000, weight = 35 },
			{ name = "Huge Golden Cat", mult = 5000, weight = 5 },
		},
	},
}

local PET_INFO = {} -- [name] = { mult, color, egg }
for _, egg in ipairs(EGGS) do
	for _, pet in ipairs(egg.pets) do
		PET_INFO[pet.name] = { mult = pet.mult, color = egg.color, egg = egg.name }
	end
end

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local store = DataStoreService:GetDataStore(CONFIG.DATASTORE)
local topStore = DataStoreService:GetOrderedDataStore(CONFIG.LEADERBOARD_STORE)

---------------------------------------------------------------------
-- Remotes & geteilte Konfiguration
---------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "ClickRemotes"

local function makeRemote(name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end

local ClickRemote = makeRemote("Click")
local RebirthRemote = makeRemote("Rebirth")
local ToggleAutoRemote = makeRemote("ToggleAuto")
local HatchResultRemote = makeRemote("HatchResult")
local NotifyRemote = makeRemote("Notify")

local configFolder = Instance.new("Configuration")
configFolder.Name = "Config"
configFolder.Parent = remotes
for _, key in ipairs({ "DOUBLE_CLICKS_PASS", "AUTO_CLICKER_PASS", "LUCKY_PASS", "SMALL_PACK_PRODUCT", "BIG_PACK_PRODUCT", "INSTANT_REBIRTH_PRODUCT" }) do
	local v = Instance.new("IntValue")
	v.Name = key
	v.Value = CONFIG[key]
	v.Parent = configFolder
end
-- Pet-Farben für den Client
local petColors = Instance.new("Folder")
petColors.Name = "PetColors"
petColors.Parent = remotes
for name, info in pairs(PET_INFO) do
	local c = Instance.new("Color3Value")
	c.Name = name
	c.Value = info.color
	c.Parent = petColors
end
remotes.Parent = ReplicatedStorage -- erst jetzt, damit der Client alles auf einmal bekommt

---------------------------------------------------------------------
-- Formeln
---------------------------------------------------------------------
local function rebirthCost(rebirths)
	return math.floor(1000 * (rebirths + 1) ^ 1.8)
end

local function formatNumber(n)
	local suffixes = { "", "K", "M", "B", "T", "Qd", "Qn" }
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
-- Spielerdaten
---------------------------------------------------------------------
local sessionData = {}

local function sortPets(pets)
	table.sort(pets, function(a, b)
		return (PET_INFO[a] and PET_INFO[a].mult or 0) > (PET_INFO[b] and PET_INFO[b].mult or 0)
	end)
end

local function petMultiplier(d)
	local total = 1
	for i = 1, math.min(CONFIG.EQUIPPED_PETS, #d.pets) do
		local info = PET_INFO[d.pets[i]]
		if info then
			total = total + info.mult
		end
	end
	return total
end

local function clickValue(player)
	local d = sessionData[player]
	if not d then
		return 0
	end
	local value = (1 + d.rebirths) * petMultiplier(d)
	if player:GetAttribute("DoubleClicks") then
		value = value * 2
	end
	return value
end

local function refresh(player)
	local d = sessionData[player]
	local ls = player:FindFirstChild("leaderstats")
	if not d or not ls then
		return
	end
	ls.Clicks.Value = math.floor(d.clicks)
	ls.Rebirths.Value = d.rebirths
	player:SetAttribute("ClickValue", clickValue(player))
	player:SetAttribute("RebirthCost", rebirthCost(d.rebirths))
	player:SetAttribute("Pets", HttpService:JSONEncode(d.pets))
	local equipped = {}
	for i = 1, math.min(CONFIG.EQUIPPED_PETS, #d.pets) do
		equipped[i] = d.pets[i]
	end
	player:SetAttribute("EquippedPets", table.concat(equipped, ","))
end

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
	local pets = {}
	for _, name in ipairs(data.pets or {}) do
		if PET_INFO[name] then
			table.insert(pets, name)
		end
	end
	sortPets(pets)
	return {
		clicks = tonumber(data.clicks) or 0,
		rebirths = tonumber(data.rebirths) or 0,
		pets = pets,
		loaded = success == true,
		clickWindow = 0,
		clickCount = 0,
	}
end

local function saveData(player)
	local d = sessionData[player]
	if not d or not d.loaded then
		return
	end
	for _ = 1, 3 do
		local ok = pcall(function()
			store:SetAsync("u_" .. player.UserId, { clicks = d.clicks, rebirths = d.rebirths, pets = d.pets })
		end)
		if ok then
			break
		end
		task.wait(1)
	end
	pcall(function()
		topStore:SetAsync("u_" .. player.UserId, d.rebirths)
	end)
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

Players.PlayerAdded:Connect(function(player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	ls.Parent = player
	local clicks = Instance.new("NumberValue")
	clicks.Name = "Clicks"
	clicks.Parent = ls
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = ls

	player:SetAttribute("DoubleClicks", ownsPass(player, CONFIG.DOUBLE_CLICKS_PASS))
	player:SetAttribute("AutoClicker", ownsPass(player, CONFIG.AUTO_CLICKER_PASS))
	player:SetAttribute("Lucky", ownsPass(player, CONFIG.LUCKY_PASS))
	player:SetAttribute("AutoOn", false)

	sessionData[player] = loadData(player)
	if not player.Parent then
		sessionData[player] = nil
		return
	end
	if not sessionData[player].loaded then
		NotifyRemote:FireClient(player, "⚠ Data could not be loaded - progress will not be saved this session.")
	end
	refresh(player)
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
-- Klicken
---------------------------------------------------------------------
local function addClicks(player, amount)
	local d = sessionData[player]
	if d then
		d.clicks = d.clicks + amount
		local ls = player:FindFirstChild("leaderstats")
		if ls then
			ls.Clicks.Value = math.floor(d.clicks)
		end
	end
end

ClickRemote.OnServerEvent:Connect(function(player)
	local d = sessionData[player]
	if not d then
		return
	end
	local now = os.clock()
	if now - d.clickWindow >= 1 then
		d.clickWindow = now
		d.clickCount = 0
	end
	d.clickCount = d.clickCount + 1
	if d.clickCount > CONFIG.MAX_CLICKS_PER_SECOND then
		return
	end
	addClicks(player, clickValue(player))
end)

ToggleAutoRemote.OnServerEvent:Connect(function(player)
	if player:GetAttribute("AutoClicker") then
		player:SetAttribute("AutoOn", not player:GetAttribute("AutoOn"))
	end
end)

task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			if player:GetAttribute("AutoClicker") and player:GetAttribute("AutoOn") then
				addClicks(player, clickValue(player) * CONFIG.AUTO_CLICKS_PER_SECOND)
			end
		end
	end
end)

---------------------------------------------------------------------
-- Rebirth
---------------------------------------------------------------------
local function doRebirth(player, free)
	local d = sessionData[player]
	if not d then
		return false
	end
	local cost = rebirthCost(d.rebirths)
	if not free and d.clicks < cost then
		NotifyRemote:FireClient(player, "You need " .. formatNumber(cost) .. " clicks to rebirth!")
		return false
	end
	d.clicks = 0
	d.rebirths = d.rebirths + 1
	refresh(player)
	NotifyRemote:FireClient(player, "🌟 REBIRTH! You now earn x" .. (1 + d.rebirths) .. " clicks!")
	return true
end

RebirthRemote.OnServerEvent:Connect(function(player)
	doRebirth(player, false)
end)

---------------------------------------------------------------------
-- Eier
---------------------------------------------------------------------
local function rollPet(egg, lucky)
	local total = 0
	local weights = {}
	for i, pet in ipairs(egg.pets) do
		local w = pet.weight
		if lucky and i >= #egg.pets - 1 then
			w = w * 2.5
		end
		weights[i] = w
		total = total + w
	end
	local roll = math.random() * total
	for i, pet in ipairs(egg.pets) do
		roll = roll - weights[i]
		if roll <= 0 then
			return pet
		end
	end
	return egg.pets[#egg.pets]
end

local hatchCooldown = {}
local function hatch(player, egg)
	local d = sessionData[player]
	if not d or hatchCooldown[player] then
		return
	end
	if d.clicks < egg.cost then
		NotifyRemote:FireClient(player, "You need " .. formatNumber(egg.cost) .. " clicks!")
		return
	end
	hatchCooldown[player] = true
	task.delay(2.5, function()
		hatchCooldown[player] = nil
	end)
	d.clicks = d.clicks - egg.cost
	local pet = rollPet(egg, player:GetAttribute("Lucky"))
	table.insert(d.pets, pet.name)
	sortPets(d.pets)
	while #d.pets > CONFIG.MAX_PETS do
		table.remove(d.pets) -- schwächstes Pet fliegt raus
	end
	refresh(player)
	HatchResultRemote:FireClient(player, pet.name, pet.mult, egg.name)
end

---------------------------------------------------------------------
-- Welt
---------------------------------------------------------------------
local world = Instance.new("Folder")
world.Name = "SimulatorWorld"
world.Parent = workspace

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = world
	return p
end

local function billboard(adornee, text, color, height)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 70)
	gui.StudsOffset = Vector3.new(0, height or 6, 0)
	gui.Adornee = adornee
	gui.MaxDistance = 120
	gui.Parent = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Parent = gui
	return label
end

-- Boden-Deko
part({ Name = "Plaza", Size = Vector3.new(120, 1, 120), CFrame = CFrame.new(0, 0.5, 0), Color = Color3.fromRGB(120, 200, 120), Material = Enum.Material.Grass })

for i, egg in ipairs(EGGS) do
	local x = (i - (#EGGS + 1) / 2) * 22
	local base = part({
		Name = egg.name .. " Stand",
		Size = Vector3.new(10, 2, 10),
		CFrame = CFrame.new(x, 2, -35),
		Color = Color3.fromRGB(60, 60, 70),
		Material = Enum.Material.Slate,
	})
	local eggPart = part({
		Name = egg.name,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(6, 6, 6),
		CFrame = CFrame.new(x, 7, -35),
		Color = egg.color,
		Material = Enum.Material.Neon,
	})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1, 1.3, 1)
	mesh.Parent = eggPart
	billboard(eggPart, egg.name .. "\n💰 " .. formatNumber(egg.cost), egg.color, 6)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Hatch"
	prompt.ObjectText = egg.name .. " (" .. formatNumber(egg.cost) .. ")"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 12
	prompt.Parent = base
	prompt.Triggered:Connect(function(player)
		hatch(player, egg)
	end)
end

-- Globale Bestenliste
local board = part({
	Name = "Leaderboard",
	Size = Vector3.new(16, 20, 1),
	CFrame = CFrame.new(45, 11, 0) * CFrame.Angles(0, math.rad(90), 0),
	Color = Color3.fromRGB(30, 30, 40),
})
local boardGui = Instance.new("SurfaceGui")
boardGui.Face = Enum.NormalId.Front
boardGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
boardGui.PixelsPerStud = 30
boardGui.Parent = board
local boardList = Instance.new("TextLabel")
boardList.Size = UDim2.fromScale(1, 1)
boardList.BackgroundTransparency = 1
boardList.TextColor3 = Color3.new(1, 1, 1)
boardList.Font = Enum.Font.FredokaOne
boardList.TextSize = 34
boardList.TextYAlignment = Enum.TextYAlignment.Top
boardList.Text = "🏆 TOP REBIRTHS 🏆\nloading..."
boardList.Parent = boardGui

local nameCache = {}
task.spawn(function()
	while true do
		local ok, pages = pcall(function()
			return topStore:GetSortedAsync(false, 10)
		end)
		if ok then
			local lines = { "🏆 TOP REBIRTHS 🏆", "" }
			for rank, entry in ipairs(pages:GetCurrentPage()) do
				local userId = tonumber(string.sub(entry.key, 3))
				local name = userId and nameCache[userId]
				if userId and not name then
					local okName, result = pcall(function()
						return Players:GetNameFromUserIdAsync(userId)
					end)
					name = okName and result or "?"
					nameCache[userId] = name
				end
				table.insert(lines, rank .. ". " .. tostring(name) .. " - " .. formatNumber(entry.value))
			end
			boardList.Text = table.concat(lines, "\n")
		end
		task.wait(90)
	end
end)

---------------------------------------------------------------------
-- Käufe
---------------------------------------------------------------------
local PASS_ATTRIBUTES = {}
PASS_ATTRIBUTES[CONFIG.DOUBLE_CLICKS_PASS] = "DoubleClicks"
PASS_ATTRIBUTES[CONFIG.AUTO_CLICKER_PASS] = "AutoClicker"
PASS_ATTRIBUTES[CONFIG.LUCKY_PASS] = "Lucky"
PASS_ATTRIBUTES[0] = nil

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	local attribute = PASS_ATTRIBUTES[passId]
	if purchased and attribute then
		player:SetAttribute(attribute, true)
		refresh(player)
		NotifyRemote:FireClient(player, "🎉 Thanks for your purchase!")
	end
end)

MarketplaceService.ProcessReceipt = function(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local d = player and sessionData[player]
	if not d then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local id = receipt.ProductId
	if id == CONFIG.SMALL_PACK_PRODUCT then
		addClicks(player, 2000 * clickValue(player))
	elseif id == CONFIG.BIG_PACK_PRODUCT then
		addClicks(player, 25000 * clickValue(player))
	elseif id == CONFIG.INSTANT_REBIRTH_PRODUCT then
		doRebirth(player, true)
	else
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	NotifyRemote:FireClient(player, "🎉 Thanks for your purchase!")
	task.spawn(saveData, player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
