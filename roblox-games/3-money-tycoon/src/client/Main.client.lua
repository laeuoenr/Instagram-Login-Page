--[[
	MONEY TYCOON - Client
	Platzieren in: StarterPlayer > StarterPlayerScripts (als LocalScript)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("TycoonRemotes")
local config = remotes:WaitForChild("Config")

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

local gui = Instance.new("ScreenGui")
gui.Name = "TycoonUI"
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

local function button(parent, text, color, position, size)
	local b = Instance.new("TextButton")
	style(b, color)
	b.Text = text
	b.Position = position
	b.Size = size
	b.Parent = parent
	return b
end

local cashLabel = Instance.new("TextLabel")
style(cashLabel, Color3.fromRGB(30, 120, 50))
cashLabel.AnchorPoint = Vector2.new(0.5, 0)
cashLabel.Position = UDim2.new(0.5, 0, 0, 8)
cashLabel.Size = UDim2.fromOffset(280, 56)
cashLabel.Text = "$0"
cashLabel.Parent = gui

local notify = Instance.new("TextLabel")
notify.BackgroundTransparency = 1
notify.AnchorPoint = Vector2.new(0.5, 0)
notify.Position = UDim2.new(0.5, 0, 0, 72)
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

local rebirthButton = button(gui, "🌟 Rebirth", Color3.fromRGB(255, 170, 0), UDim2.new(0, 12, 0.35, 0), UDim2.fromOffset(190, 52))
rebirthButton.MouseButton1Click:Connect(function()
	remotes.Rebirth:FireServer()
end)

local shopItems = {
	{ "💸 2x Cash", Color3.fromRGB(0, 170, 80), function() prompt(config.DOUBLE_CASH_PASS.Value, true) end },
	{ "🤖 Auto Collect", Color3.fromRGB(0, 150, 255), function() prompt(config.AUTO_COLLECT_PASS.Value, true) end },
	{ "💰 10 min Cash", Color3.fromRGB(230, 170, 0), function() prompt(config.SMALL_CASH_PRODUCT.Value, false) end },
	{ "💎 1 hour Cash", Color3.fromRGB(170, 70, 255), function() prompt(config.BIG_CASH_PRODUCT.Value, false) end },
}
for i, item in ipairs(shopItems) do
	local b = button(gui, item[1], item[2], UDim2.new(0, 12, 0.35, i * 60), UDim2.fromOffset(190, 50))
	b.MouseButton1Click:Connect(item[3])
end

local function refresh()
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		cashLabel.Text = "$" .. formatNumber(ls.Cash.Value)
	end
	rebirthButton.Text = "🌟 Rebirth ($" .. formatNumber(player:GetAttribute("RebirthCost") or 0) .. ")"
end

task.spawn(function()
	local ls = player:WaitForChild("leaderstats")
	ls:WaitForChild("Cash").Changed:Connect(refresh)
	refresh()
end)
player:GetAttributeChangedSignal("RebirthCost"):Connect(refresh)
