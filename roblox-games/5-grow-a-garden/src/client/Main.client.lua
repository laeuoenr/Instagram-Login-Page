--[[
	GARDEN GROW - Client
	Platzieren in: StarterPlayer > StarterPlayerScripts (als LocalScript)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("GardenRemotes")
local config = remotes:WaitForChild("Config")
local seedInfo = remotes:WaitForChild("Seeds")
local restockAt = remotes:WaitForChild("RestockAt")

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

local gui = Instance.new("ScreenGui")
gui.Name = "GardenUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function style(obj, color)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 12)
	c.Parent = obj
	local s = Instance.new("UIStroke")
	s.Thickness = 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = Color3.fromRGB(30, 20, 10)
	s.Parent = obj
	obj.BackgroundColor3 = color
	if obj:IsA("TextLabel") or obj:IsA("TextButton") then
		obj.Font = Enum.Font.FredokaOne
		obj.TextScaled = true
		obj.TextColor3 = Color3.new(1, 1, 1)
	end
end

local function button(parent, text, color, position, size)
	local b = Instance.new("TextButton")
	style(b, color)
	b.Text = text
	b.Position = position
	b.Size = size
	b.Parent = parent
	return b
end

local function label(parent, text, position, size)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.3
	l.Text = text
	l.Position = position
	l.Size = size
	l.Parent = parent
	return l
end

---------------------------------------------------------------------
-- Oben: Geld + Korb
---------------------------------------------------------------------
local moneyLabel = Instance.new("TextLabel")
style(moneyLabel, Color3.fromRGB(60, 150, 60))
moneyLabel.AnchorPoint = Vector2.new(0.5, 0)
moneyLabel.Position = UDim2.new(0.5, 0, 0, 8)
moneyLabel.Size = UDim2.fromOffset(260, 50)
moneyLabel.Text = "$0"
moneyLabel.Parent = gui

local basketLabel = label(gui, "🧺 0 fruits", UDim2.new(0.5, -200, 0, 62), UDim2.fromOffset(260, 30))
local sellButton = button(gui, "💰 Sell", Color3.fromRGB(255, 170, 0), UDim2.new(0.5, 66, 0, 60), UDim2.fromOffset(110, 34))
sellButton.MouseButton1Click:Connect(function()
	remotes.Sell:FireServer()
end)

local notify = label(gui, "", UDim2.new(0.5, -240, 0, 100), UDim2.fromOffset(480, 34))
local notifyId = 0
local function showMessage(text)
	notifyId = notifyId + 1
	local myId = notifyId
	notify.Text = text
	task.delay(3.5, function()
		if myId == notifyId then
			notify.Text = ""
		end
	end)
end
remotes:WaitForChild("Notify").OnClientEvent:Connect(showMessage)

local function prompt(id, isPass)
	if id == 0 then
		showMessage("Shop is not set up yet.")
	elseif isPass then
		MarketplaceService:PromptGamePassPurchase(player, id)
	else
		MarketplaceService:PromptProductPurchase(player, id)
	end
end

---------------------------------------------------------------------
-- Samen-Shop
---------------------------------------------------------------------
local shopFrame = Instance.new("Frame")
style(shopFrame, Color3.fromRGB(70, 50, 35))
shopFrame.AnchorPoint = Vector2.new(0.5, 0.5)
shopFrame.Position = UDim2.fromScale(0.5, 0.5)
shopFrame.Size = UDim2.fromOffset(440, 400)
shopFrame.Visible = false
shopFrame.Parent = gui
label(shopFrame, "🌱 SEED SHOP", UDim2.fromOffset(0, 6), UDim2.new(1, 0, 0, 36))
local restockLabel = label(shopFrame, "", UDim2.fromOffset(0, 42), UDim2.new(1, 0, 0, 22))
restockLabel.TextColor3 = Color3.fromRGB(200, 255, 200)
local closeButton = button(shopFrame, "X", Color3.fromRGB(220, 60, 60), UDim2.new(1, -44, 0, 8), UDim2.fromOffset(36, 36))
closeButton.MouseButton1Click:Connect(function()
	shopFrame.Visible = false
end)

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(10, 70)
list.Size = UDim2.new(1, -20, 1, -80)
list.BackgroundTransparency = 1
list.ScrollBarThickness = 6
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = shopFrame
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local function seedColor(info)
	return info:GetAttribute("Color") or Color3.new(1, 1, 1)
end

for _, info in ipairs(seedInfo:GetChildren()) do
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -10, 0, 44)
	row.LayoutOrder = info:GetAttribute("Order") or 0
	style(row, Color3.fromRGB(95, 70, 50))
	row.Parent = list
	local nameLabel = label(row, info.Name .. (info:GetAttribute("Regrows") and " ♻" or ""), UDim2.fromOffset(8, 4), UDim2.new(0.45, 0, 1, -8))
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextColor3 = seedColor(info)
	local stockLabel = label(row, "", UDim2.new(0.45, 0, 0, 4), UDim2.new(0.2, 0, 1, -8))
	local buy = button(row, "$" .. formatNumber(info:GetAttribute("Cost") or 0), Color3.fromRGB(60, 170, 60), UDim2.new(0.67, 0, 0, 5), UDim2.new(0.31, 0, 1, -10))
	local function refreshStock()
		stockLabel.Text = "x" .. info.Value
		buy.BackgroundColor3 = info.Value > 0 and Color3.fromRGB(60, 170, 60) or Color3.fromRGB(110, 110, 110)
	end
	info.Changed:Connect(refreshStock)
	refreshStock()
	buy.MouseButton1Click:Connect(function()
		remotes.BuySeed:FireServer(info.Name)
	end)
end

task.spawn(function()
	while true do
		local remaining = math.max(0, restockAt.Value - os.time())
		restockLabel.Text = string.format("New seeds in %d:%02d", math.floor(remaining / 60), remaining % 60)
		task.wait(1)
	end
end)

remotes:WaitForChild("OpenShop").OnClientEvent:Connect(function()
	shopFrame.Visible = true
end)

---------------------------------------------------------------------
-- Seitenleiste
---------------------------------------------------------------------
local sideItems = {
	{ "🌱 Seeds", Color3.fromRGB(60, 170, 60), function() shopFrame.Visible = not shopFrame.Visible end },
	{ "💸 2x Sell", Color3.fromRGB(255, 150, 0), function() prompt(config.DOUBLE_SELL_PASS.Value, true) end },
	{ "🍀 Lucky", Color3.fromRGB(40, 190, 120), function() prompt(config.LUCKY_PASS.Value, true) end },
	{ "⚡ Grow All", Color3.fromRGB(0, 150, 255), function() prompt(config.INSTANT_GROW_PRODUCT.Value, false) end },
	{ "🔄 Restock", Color3.fromRGB(170, 80, 255), function() prompt(config.RESTOCK_PRODUCT.Value, false) end },
	{ "💰 Money", Color3.fromRGB(230, 180, 0), function() prompt(config.MONEY_PRODUCT.Value, false) end },
}
for i, item in ipairs(sideItems) do
	local b = button(gui, item[1], item[2], UDim2.new(0, 12, 0.25, (i - 1) * 54), UDim2.fromOffset(160, 46))
	b.MouseButton1Click:Connect(item[3])
end

---------------------------------------------------------------------
-- Hotbar mit eigenen Samen
---------------------------------------------------------------------
local hotbar = Instance.new("Frame")
hotbar.AnchorPoint = Vector2.new(0.5, 1)
hotbar.Position = UDim2.new(0.5, 0, 1, -12)
hotbar.Size = UDim2.new(0.9, 0, 0, 64)
hotbar.BackgroundTransparency = 1
hotbar.Parent = gui
local hotbarLayout = Instance.new("UIListLayout")
hotbarLayout.FillDirection = Enum.FillDirection.Horizontal
hotbarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
hotbarLayout.Padding = UDim.new(0, 6)
hotbarLayout.SortOrder = Enum.SortOrder.LayoutOrder
hotbarLayout.Parent = hotbar

local function refreshHotbar()
	for _, child in ipairs(hotbar:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local ok, seeds = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("Seeds") or "{}")
	end)
	if not ok or type(seeds) ~= "table" then
		return
	end
	local selected = player:GetAttribute("SelectedSeed")
	for name, count in pairs(seeds) do
		local info = seedInfo:FindFirstChild(name)
		local b = button(hotbar, name .. "\nx" .. count, Color3.fromRGB(90, 65, 45), UDim2.new(), UDim2.fromOffset(96, 60))
		b.LayoutOrder = info and info:GetAttribute("Order") or 99
		if info then
			b.TextColor3 = seedColor(info)
		end
		if name == selected then
			b.BackgroundColor3 = Color3.fromRGB(60, 170, 60)
		end
		b.MouseButton1Click:Connect(function()
			remotes.SelectSeed:FireServer(name)
		end)
	end
end

local function refreshStats()
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		moneyLabel.Text = "$" .. formatNumber(ls.Sheckles.Value)
	end
	basketLabel.Text = "🧺 " .. (player:GetAttribute("FruitCount") or 0) .. " fruits ($" .. formatNumber(player:GetAttribute("FruitValue") or 0) .. ")"
end

task.spawn(function()
	local ls = player:WaitForChild("leaderstats")
	ls:WaitForChild("Sheckles").Changed:Connect(refreshStats)
	refreshStats()
end)
player:GetAttributeChangedSignal("FruitCount"):Connect(refreshStats)
player:GetAttributeChangedSignal("FruitValue"):Connect(refreshStats)
player:GetAttributeChangedSignal("Seeds"):Connect(refreshHotbar)
player:GetAttributeChangedSignal("SelectedSeed"):Connect(refreshHotbar)
refreshStats()
refreshHotbar()
