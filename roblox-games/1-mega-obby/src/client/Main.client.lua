--[[
	MEGA OBBY - Client
	Platzieren in: StarterPlayer > StarterPlayerScripts (als LocalScript)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("ObbyRemotes")
local config = remotes:WaitForChild("Config")

local gui = Instance.new("ScreenGui")
gui.Name = "ObbyUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 12)
	c.Parent = parent
end

local function button(text, color, position, size)
	local b = Instance.new("TextButton")
	b.Text = text
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = color
	b.Position = position
	b.Size = size
	b.AutoButtonColor = true
	corner(b)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.fromRGB(30, 30, 30)
	stroke.Parent = b
	b.Parent = gui
	return b
end

-- Stage-Anzeige
local stageLabel = Instance.new("TextLabel")
stageLabel.AnchorPoint = Vector2.new(0.5, 0)
stageLabel.Position = UDim2.new(0.5, 0, 0, 8)
stageLabel.Size = UDim2.fromOffset(260, 50)
stageLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
stageLabel.BackgroundTransparency = 0.2
stageLabel.TextColor3 = Color3.new(1, 1, 1)
stageLabel.Font = Enum.Font.FredokaOne
stageLabel.TextScaled = true
corner(stageLabel)
stageLabel.Parent = gui

local progressBar = Instance.new("Frame")
progressBar.AnchorPoint = Vector2.new(0.5, 0)
progressBar.Position = UDim2.new(0.5, 0, 0, 62)
progressBar.Size = UDim2.fromOffset(260, 10)
progressBar.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
corner(progressBar, 5)
progressBar.Parent = gui
local progressFill = Instance.new("Frame")
progressFill.Size = UDim2.fromScale(0, 1)
progressFill.BackgroundColor3 = Color3.fromRGB(80, 220, 100)
corner(progressFill, 5)
progressFill.Parent = progressBar

local function refreshStage()
	local ls = player:FindFirstChild("leaderstats")
	local stageValue = ls and ls:FindFirstChild("Stage")
	local total = config.STAGES.Value
	local stage = stageValue and stageValue.Value or 0
	stageLabel.Text = "Stage " .. stage .. " / " .. total
	TweenService:Create(progressFill, TweenInfo.new(0.3), { Size = UDim2.fromScale(stage / total, 1) }):Play()
end

task.spawn(function()
	local ls = player:WaitForChild("leaderstats")
	local stageValue = ls:WaitForChild("Stage")
	stageValue.Changed:Connect(refreshStage)
	refreshStage()
end)

-- Benachrichtigungen
local notify = Instance.new("TextLabel")
notify.AnchorPoint = Vector2.new(0.5, 0)
notify.Position = UDim2.new(0.5, 0, 0, 90)
notify.Size = UDim2.fromOffset(420, 40)
notify.BackgroundTransparency = 1
notify.TextColor3 = Color3.new(1, 1, 1)
notify.TextStrokeTransparency = 0
notify.Font = Enum.Font.FredokaOne
notify.TextScaled = true
notify.Text = ""
notify.Parent = gui

local notifyId = 0
local function showMessage(text)
	notifyId = notifyId + 1
	local myId = notifyId
	notify.Text = text
	notify.TextTransparency = 0
	notify.TextStrokeTransparency = 0
	task.delay(3, function()
		if notifyId == myId then
			TweenService:Create(notify, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end
remotes:WaitForChild("Notify").OnClientEvent:Connect(showMessage)

-- Buttons (links)
local function promptProduct(id)
	if id == 0 then
		showMessage("Shop is not set up yet.")
		return
	end
	MarketplaceService:PromptProductPurchase(player, id)
end

local function promptPass(id)
	if id == 0 then
		showMessage("Shop is not set up yet.")
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, id)
end

local skip = button("⏭ Skip Stage", Color3.fromRGB(255, 170, 0), UDim2.new(0, 12, 0.4, 0), UDim2.fromOffset(170, 48))
skip.MouseButton1Click:Connect(function()
	promptProduct(config.SKIP_STAGE_PRODUCT.Value)
end)

local speed = button("⚡ Speed", Color3.fromRGB(0, 170, 255), UDim2.new(0, 12, 0.4, 58), UDim2.fromOffset(170, 48))
speed.MouseButton1Click:Connect(function()
	promptPass(config.SPEED_PASS.Value)
end)

local gravity = button("🪐 Low Gravity", Color3.fromRGB(150, 80, 255), UDim2.new(0, 12, 0.4, 116), UDim2.fromOffset(170, 48))
gravity.MouseButton1Click:Connect(function()
	promptPass(config.LOW_GRAVITY_PASS.Value)
end)

local respawn = button("↩ Checkpoint", Color3.fromRGB(70, 70, 80), UDim2.new(0, 12, 0.4, 174), UDim2.fromOffset(170, 48))
respawn.MouseButton1Click:Connect(function()
	remotes.Respawn:FireServer()
end)
