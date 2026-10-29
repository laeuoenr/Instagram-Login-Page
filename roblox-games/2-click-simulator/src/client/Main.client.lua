--[[
	CLICK LEGENDS SIMULATOR - Client
	Platzieren in: StarterPlayer > StarterPlayerScripts (als LocalScript)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("ClickRemotes")
local config = remotes:WaitForChild("Config")
local petColors = remotes:WaitForChild("PetColors")

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
-- UI-Helfer
---------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "SimulatorUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 12)
	c.Parent = parent
end

local function stroke(parent)
	local s = Instance.new("UIStroke")
	s.Thickness = 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = Color3.fromRGB(20, 20, 30)
	s.Parent = parent
end

local function label(parent, text, position, size)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.Position = position
	l.Size = size
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.3
	l.Parent = parent
	return l
end

local function button(parent, text, color, position, size)
	local b = Instance.new("TextButton")
	b.Text = text
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = color
	b.Position = position
	b.Size = size
	corner(b)
	stroke(b)
	b.Parent = parent
	return b
end

local function panel(title)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(420, 360)
	frame.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
	frame.Visible = false
	corner(frame, 16)
	stroke(frame)
	frame.Parent = gui
	label(frame, title, UDim2.fromOffset(0, 8), UDim2.new(1, 0, 0, 36))
	local close = button(frame, "X", Color3.fromRGB(220, 60, 60), UDim2.new(1, -44, 0, 8), UDim2.fromOffset(36, 36))
	close.MouseButton1Click:Connect(function()
		frame.Visible = false
	end)
	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(12, 52)
	list.Size = UDim2.new(1, -24, 1, -64)
	list.BackgroundTransparency = 1
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	return frame, list
end

---------------------------------------------------------------------
-- Benachrichtigungen
---------------------------------------------------------------------
local notify = label(gui, "", UDim2.new(0.5, -230, 0, 110), UDim2.fromOffset(460, 36))
local notifyId = 0
local function showMessage(text)
	notifyId = notifyId + 1
	local myId = notifyId
	notify.Text = text
	notify.TextTransparency = 0
	task.delay(3, function()
		if myId == notifyId then
			notify.Text = ""
		end
	end)
end
remotes:WaitForChild("Notify").OnClientEvent:Connect(showMessage)

local function promptPass(id)
	if id == 0 then
		showMessage("Shop is not set up yet.")
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, id)
end

local function promptProduct(id)
	if id == 0 then
		showMessage("Shop is not set up yet.")
		return
	end
	MarketplaceService:PromptProductPurchase(player, id)
end

---------------------------------------------------------------------
-- Statistik oben
---------------------------------------------------------------------
local statsFrame = Instance.new("Frame")
statsFrame.AnchorPoint = Vector2.new(0.5, 0)
statsFrame.Position = UDim2.new(0.5, 0, 0, 8)
statsFrame.Size = UDim2.fromOffset(360, 92)
statsFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
statsFrame.BackgroundTransparency = 0.15
corner(statsFrame, 14)
stroke(statsFrame)
statsFrame.Parent = gui

local clicksLabel = label(statsFrame, "👆 0", UDim2.fromOffset(10, 4), UDim2.new(1, -20, 0, 46))
local infoLabel = label(statsFrame, "", UDim2.fromOffset(10, 52), UDim2.new(1, -20, 0, 32))
infoLabel.TextColor3 = Color3.fromRGB(255, 220, 120)

local function refreshStats()
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		return
	end
	clicksLabel.Text = "👆 " .. formatNumber(ls.Clicks.Value)
	infoLabel.Text = "+" .. formatNumber(player:GetAttribute("ClickValue") or 1) .. " per click   |   🌟 " .. ls.Rebirths.Value .. " Rebirths"
end

---------------------------------------------------------------------
-- Klick-Button
---------------------------------------------------------------------
local clickButton = button(gui, "CLICK!", Color3.fromRGB(80, 200, 90), UDim2.new(0.5, -110, 1, -150), UDim2.fromOffset(220, 120))
clickButton.TextColor3 = Color3.new(1, 1, 1)
local clickRemote = remotes:WaitForChild("Click")

local function floatingText(text)
	local t = label(gui, text, UDim2.new(0.5, math.random(-120, 120), 1, -170), UDim2.fromOffset(140, 36))
	t.TextColor3 = Color3.fromRGB(255, 255, 120)
	TweenService:Create(t, TweenInfo.new(0.8), { Position = t.Position - UDim2.fromOffset(0, 120), TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(0.8, function()
		t:Destroy()
	end)
end

clickButton.MouseButton1Click:Connect(function()
	clickRemote:FireServer()
	floatingText("+" .. formatNumber(player:GetAttribute("ClickValue") or 1))
	clickButton.Size = UDim2.fromOffset(200, 108)
	clickButton.Position = UDim2.new(0.5, -100, 1, -144)
	TweenService:Create(clickButton, TweenInfo.new(0.12, Enum.EasingStyle.Back), {
		Size = UDim2.fromOffset(220, 120),
		Position = UDim2.new(0.5, -110, 1, -150),
	}):Play()
end)

---------------------------------------------------------------------
-- Seitenleiste
---------------------------------------------------------------------
local rebirthButton = button(gui, "🌟 Rebirth", Color3.fromRGB(255, 170, 0), UDim2.new(0, 12, 0.35, 0), UDim2.fromOffset(180, 52))
rebirthButton.MouseButton1Click:Connect(function()
	remotes.Rebirth:FireServer()
end)

local autoButton = button(gui, "🤖 Auto: OFF", Color3.fromRGB(90, 90, 110), UDim2.new(0, 12, 0.35, 62), UDim2.fromOffset(180, 52))
autoButton.MouseButton1Click:Connect(function()
	if player:GetAttribute("AutoClicker") then
		remotes.ToggleAuto:FireServer()
	else
		promptPass(config.AUTO_CLICKER_PASS.Value)
	end
end)

local shopFrame, shopList = panel("🛒 SHOP")
local petsFrame, petsList = panel("🐾 YOUR PETS")

local shopButton = button(gui, "🛒 Shop", Color3.fromRGB(0, 160, 255), UDim2.new(0, 12, 0.35, 124), UDim2.fromOffset(180, 52))
shopButton.MouseButton1Click:Connect(function()
	petsFrame.Visible = false
	shopFrame.Visible = not shopFrame.Visible
end)

local petsButton = button(gui, "🐾 Pets", Color3.fromRGB(170, 80, 255), UDim2.new(0, 12, 0.35, 186), UDim2.fromOffset(180, 52))
petsButton.MouseButton1Click:Connect(function()
	shopFrame.Visible = false
	petsFrame.Visible = not petsFrame.Visible
end)

local SHOP_ITEMS = {
	{ text = "⚡ 2x Clicks (forever)", color = Color3.fromRGB(255, 120, 0), action = function() promptPass(config.DOUBLE_CLICKS_PASS.Value) end },
	{ text = "🤖 Auto Clicker", color = Color3.fromRGB(0, 170, 120), action = function() promptPass(config.AUTO_CLICKER_PASS.Value) end },
	{ text = "🍀 Lucky Eggs", color = Color3.fromRGB(60, 200, 60), action = function() promptPass(config.LUCKY_PASS.Value) end },
	{ text = "💰 Small Click Pack", color = Color3.fromRGB(230, 180, 0), action = function() promptProduct(config.SMALL_PACK_PRODUCT.Value) end },
	{ text = "💎 Huge Click Pack", color = Color3.fromRGB(0, 140, 255), action = function() promptProduct(config.BIG_PACK_PRODUCT.Value) end },
	{ text = "🌟 Instant Rebirth", color = Color3.fromRGB(200, 60, 255), action = function() promptProduct(config.INSTANT_REBIRTH_PRODUCT.Value) end },
}
for i, item in ipairs(SHOP_ITEMS) do
	local b = button(shopList, item.text, item.color, UDim2.new(), UDim2.new(1, -10, 0, 44))
	b.LayoutOrder = i
	b.MouseButton1Click:Connect(item.action)
end

local function refreshPets()
	for _, child in ipairs(petsList:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local ok, pets = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("Pets") or "[]")
	end)
	if not ok then
		return
	end
	for i, name in ipairs(pets) do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, -10, 0, 32)
		row.LayoutOrder = i
		row.Font = Enum.Font.FredokaOne
		row.TextScaled = true
		row.TextColor3 = Color3.new(1, 1, 1)
		local colorValue = petColors:FindFirstChild(name)
		row.BackgroundColor3 = colorValue and colorValue.Value or Color3.fromRGB(80, 80, 80)
		row.Text = (i <= 3 and "✅ " or "") .. name
		corner(row, 8)
		row.Parent = petsList
	end
end

---------------------------------------------------------------------
-- Ei-Animation
---------------------------------------------------------------------
local hatchFrame = Instance.new("Frame")
hatchFrame.AnchorPoint = Vector2.new(0.5, 0.5)
hatchFrame.Position = UDim2.fromScale(0.5, 0.45)
hatchFrame.Size = UDim2.fromOffset(320, 200)
hatchFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
hatchFrame.Visible = false
corner(hatchFrame, 20)
stroke(hatchFrame)
hatchFrame.Parent = gui
local hatchTitle = label(hatchFrame, "", UDim2.fromOffset(10, 10), UDim2.new(1, -20, 0, 40))
local hatchPet = label(hatchFrame, "", UDim2.fromOffset(10, 60), UDim2.new(1, -20, 0, 70))
local hatchMult = label(hatchFrame, "", UDim2.fromOffset(10, 140), UDim2.new(1, -20, 0, 40))
hatchMult.TextColor3 = Color3.fromRGB(120, 255, 120)

remotes:WaitForChild("HatchResult").OnClientEvent:Connect(function(petName, mult, eggName)
	hatchTitle.Text = eggName .. "..."
	hatchPet.Text = "🥚"
	hatchMult.Text = ""
	hatchFrame.Visible = true
	for _ = 1, 6 do
		hatchPet.Rotation = 15
		task.wait(0.08)
		hatchPet.Rotation = -15
		task.wait(0.08)
	end
	hatchPet.Rotation = 0
	hatchTitle.Text = "You hatched:"
	hatchPet.Text = petName
	local colorValue = petColors:FindFirstChild(petName)
	hatchPet.TextColor3 = colorValue and colorValue.Value or Color3.new(1, 1, 1)
	hatchMult.Text = "+" .. mult .. "x Multiplier"
	task.wait(2)
	hatchFrame.Visible = false
end)

---------------------------------------------------------------------
-- Attribute / Werte beobachten
---------------------------------------------------------------------
task.spawn(function()
	local ls = player:WaitForChild("leaderstats")
	ls:WaitForChild("Clicks").Changed:Connect(refreshStats)
	ls:WaitForChild("Rebirths").Changed:Connect(refreshStats)
	refreshStats()
end)

local function refreshButtons()
	local cost = player:GetAttribute("RebirthCost") or 0
	rebirthButton.Text = "🌟 Rebirth (" .. formatNumber(cost) .. ")"
	local on = player:GetAttribute("AutoOn")
	autoButton.Text = on and "🤖 Auto: ON" or "🤖 Auto: OFF"
	autoButton.BackgroundColor3 = on and Color3.fromRGB(0, 190, 100) or Color3.fromRGB(90, 90, 110)
end

player:GetAttributeChangedSignal("ClickValue"):Connect(refreshStats)
player:GetAttributeChangedSignal("RebirthCost"):Connect(refreshButtons)
player:GetAttributeChangedSignal("AutoOn"):Connect(refreshButtons)
player:GetAttributeChangedSignal("Pets"):Connect(refreshPets)
refreshButtons()
refreshPets()

---------------------------------------------------------------------
-- Pets folgen allen Spielern
---------------------------------------------------------------------
local petModels = {} -- [player] = { parts }

local function rebuildPets(target)
	if petModels[target] then
		for _, p in ipairs(petModels[target]) do
			p:Destroy()
		end
	end
	petModels[target] = {}
	local equipped = target:GetAttribute("EquippedPets") or ""
	for name in string.gmatch(equipped, "[^,]+") do
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(1.8, 1.8, 1.8)
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Material = Enum.Material.Neon
		local colorValue = petColors:FindFirstChild(name)
		p.Color = colorValue and colorValue.Value or Color3.new(1, 1, 1)
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(120, 24)
		bb.StudsOffset = Vector3.new(0, 1.8, 0)
		bb.MaxDistance = 60
		bb.Parent = p
		label(bb, name, UDim2.new(), UDim2.fromScale(1, 1))
		p.Parent = workspace
		table.insert(petModels[target], p)
	end
end

local function watchPlayer(target)
	target:GetAttributeChangedSignal("EquippedPets"):Connect(function()
		rebuildPets(target)
	end)
	rebuildPets(target)
end

for _, p in ipairs(Players:GetPlayers()) do
	watchPlayer(p)
end
Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(function(target)
	if petModels[target] then
		for _, p in ipairs(petModels[target]) do
			p:Destroy()
		end
		petModels[target] = nil
	end
end)

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for target, parts in pairs(petModels) do
		local character = target.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		for i, p in ipairs(parts) do
			if root then
				local angle = (i / #parts) * math.pi * 2 + t * 0.8
				local offset = Vector3.new(math.cos(angle) * 4, 0.5 + math.sin(t * 3 + i) * 0.5, math.sin(angle) * 4)
				p.CFrame = CFrame.new(root.Position + offset)
			else
				p.CFrame = CFrame.new(0, -500, 0)
			end
		end
	end
end)
