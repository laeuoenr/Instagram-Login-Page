--[[
	DISASTER SURVIVAL - Client
	Platzieren in: StarterPlayer > StarterPlayerScripts (als LocalScript)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("DisasterRemotes")
local config = remotes:WaitForChild("Config")
local status = remotes:WaitForChild("Status")
local shake = remotes:WaitForChild("Shake")

local gui = Instance.new("ScreenGui")
gui.Name = "DisasterUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function style(obj, color)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 12)
	c.Parent = obj
	local s = Instance.new("UIStroke")
	s.Thickness = 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = Color3.fromRGB(20, 20, 30)
	s.Parent = obj
	obj.BackgroundColor3 = color
	obj.Font = Enum.Font.FredokaOne
	obj.TextScaled = true
	obj.TextColor3 = Color3.new(1, 1, 1)
end

local function button(text, color, position, size)
	local b = Instance.new("TextButton")
	style(b, color)
	b.Text = text
	b.Position = position
	b.Size = size
	b.Parent = gui
	return b
end

-- Status oben
local statusLabel = Instance.new("TextLabel")
style(statusLabel, Color3.fromRGB(30, 30, 45))
statusLabel.BackgroundTransparency = 0.15
statusLabel.AnchorPoint = Vector2.new(0.5, 0)
statusLabel.Position = UDim2.new(0.5, 0, 0, 8)
statusLabel.Size = UDim2.new(0.6, 0, 0, 48)
statusLabel.Parent = gui
local function refreshStatus()
	statusLabel.Text = status.Value
end
status.Changed:Connect(refreshStatus)
refreshStatus()

local coinsLabel = Instance.new("TextLabel")
style(coinsLabel, Color3.fromRGB(200, 150, 0))
coinsLabel.Position = UDim2.new(0, 12, 0.3, 0)
coinsLabel.Size = UDim2.fromOffset(200, 46)
coinsLabel.Text = "🪙 0"
coinsLabel.Parent = gui

local notify = Instance.new("TextLabel")
notify.BackgroundTransparency = 1
notify.AnchorPoint = Vector2.new(0.5, 0)
notify.Position = UDim2.new(0.5, 0, 0, 64)
notify.Size = UDim2.fromOffset(460, 36)
notify.Font = Enum.Font.FredokaOne
notify.TextScaled = true
notify.TextColor3 = Color3.new(1, 1, 1)
notify.TextStrokeTransparency = 0
notify.Text = ""
notify.Parent = gui
local notifyId = 0
local function showMessage(text)
	notifyId = notifyId + 1
	local myId = notifyId
	notify.Text = text
	task.delay(3, function()
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

-- Upgrades (Coins)
local healthButton = button("", Color3.fromRGB(220, 60, 80), UDim2.new(0, 12, 0.3, 56), UDim2.fromOffset(200, 46))
local speedButton = button("", Color3.fromRGB(0, 160, 255), UDim2.new(0, 12, 0.3, 108), UDim2.fromOffset(200, 46))
healthButton.MouseButton1Click:Connect(function()
	remotes.Upgrade:FireServer("health")
end)
speedButton.MouseButton1Click:Connect(function()
	remotes.Upgrade:FireServer("speed")
end)

local function upgradeText(icon, name, level)
	if level >= config.MAX_UPGRADE_LEVEL.Value then
		return icon .. " " .. name .. " MAX"
	end
	return icon .. " " .. name .. " Lv" .. level .. " (" .. (100 * (level + 1) * (level + 1)) .. "🪙)"
end

local function refresh()
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		coinsLabel.Text = "🪙 " .. ls.Coins.Value
	end
	healthButton.Text = upgradeText("❤", "Health", player:GetAttribute("HealthLevel") or 0)
	speedButton.Text = upgradeText("👟", "Speed", player:GetAttribute("SpeedLevel") or 0)
end
task.spawn(function()
	local ls = player:WaitForChild("leaderstats")
	ls:WaitForChild("Coins").Changed:Connect(refresh)
	refresh()
end)
player:GetAttributeChangedSignal("HealthLevel"):Connect(refresh)
player:GetAttributeChangedSignal("SpeedLevel"):Connect(refresh)
refresh()

-- Robux-Shop
local shopItems = {
	{ "👑 VIP (2x Coins)", Color3.fromRGB(255, 170, 0), function() prompt(config.VIP_PASS.Value, true) end },
	{ "🎈 Balloon", Color3.fromRGB(255, 80, 160), function() prompt(config.BALLOON_PASS.Value, true) end },
	{ "🪙 500 Coins", Color3.fromRGB(0, 170, 90), function() prompt(config.SMALL_COINS_PRODUCT.Value, false) end },
	{ "💰 3000 Coins", Color3.fromRGB(140, 70, 255), function() prompt(config.BIG_COINS_PRODUCT.Value, false) end },
}
for i, item in ipairs(shopItems) do
	local b = button(item[1], item[2], UDim2.new(0, 12, 0.3, 112 + i * 52), UDim2.fromOffset(200, 46))
	b.MouseButton1Click:Connect(item[3])
end

-- Erdbeben: Kamera wackeln lassen
RunService:BindToRenderStep("EarthquakeShake", Enum.RenderPriority.Camera.Value + 1, function()
	if shake.Value then
		local camera = workspace.CurrentCamera
		local t = os.clock() * 40
		camera.CFrame = camera.CFrame * CFrame.Angles(math.sin(t) * 0.006, math.cos(t * 1.3) * 0.006, 0)
	end
end)
