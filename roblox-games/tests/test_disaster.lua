local H = require("harness")
local VIP, BALLOON, SMALL, BIG = 9301, 9302, 9303, 9304

H.runScript("4-disaster-survival/server", nil, {
	["VIP_PASS = 0"] = "VIP_PASS = " .. VIP,
	["BALLOON_PASS = 0"] = "BALLOON_PASS = " .. BALLOON,
	["SMALL_COINS_PRODUCT = 0"] = "SMALL_COINS_PRODUCT = " .. SMALL,
	["BIG_COINS_PRODUCT = 0"] = "BIG_COINS_PRODUCT = " .. BIG,
	-- Katastrophen der Reihe nach statt zufällig, damit jede einmal drankommt
	["local disasterName = DISASTER_NAMES[rng:NextInteger(1, #DISASTER_NAMES)]"] = "TEST_ROUND = (TEST_ROUND or 0) + 1\n\t\t\tlocal disasterName = DISASTER_NAMES[(TEST_ROUND - 1) % #DISASTER_NAMES + 1]",
})
H.run(1)
local remotes = game:GetService("ReplicatedStorage").DisasterRemotes
H.check(remotes.Status.Value == "Waiting for players...", "server waits when empty")

local a = H.addPlayer("Alice")
local b = H.addPlayer("Bob")
H.run(2)
H.runScript("4-disaster-survival/client", a)
H.run(1)

-- Shop
H.check(H.buyProduct(a, BIG) == Enum.ProductPurchaseDecision.PurchaseGranted, "coin pack granted")
H.check(a.leaderstats.Coins.Value == 3000, "3000 coins added")
local ui = a.PlayerGui.DisasterUI
local healthBtn = H.find(ui, function(d)
	return d.ClassName == "TextButton" and d.Text:find("Health")
end)
H.fire(healthBtn, "MouseButton1Click")
H.run(0.3)
H.check(a:GetAttribute("HealthLevel") == 1 and a.leaderstats.Coins.Value == 2900, "health upgrade bought for 100 coins")
H.check(a.Character.Humanoid.MaxHealth == 125, "health upgrade applied to character")
H.buyPass(a, VIP)
H.buyPass(a, BALLOON)
H.check(a.Character.HumanoidRootPart:FindFirstChild("Balloon") ~= nil, "balloon pass adds lift")

-- 6 Runden
local seen = {}
local shakeSeen, survivedRounds = false, 0
local statusLog = {}
remotes.Status.Changed:Connect(function(v)
	statusLog[#statusLog + 1] = v
end)
for round = 1, 6 do
	local winsBefore = a.leaderstats.Wins.Value + b.leaderstats.Wins.Value
	-- bis zum Rundenstart warten
	local guard = 0
	while not remotes.Status.Value:find("Get ready") and guard < 400 do
		H.run(0.5)
		guard = guard + 1
	end
	local arena = workspace:FindFirstChild("Arena")
	H.check(arena and #arena.Buildings:GetChildren() > 30, "round " .. round .. ": arena rebuilt")
	local onIsland = math.abs(a.Character.HumanoidRootPart.Position.Z) < 100
	H.check(onIsland, "round " .. round .. ": players teleported to island")
	-- Bob klettert aufs Dach (sicherster Ort)
	local roofs = H.findAll(arena.Buildings, function(d)
		return d.ClassName == "Part" and math.abs(d.Position.Y - 20.5) < 0.01
	end)
	b.Character.HumanoidRootPart.CFrame = roofs[1].CFrame + Vector3.new(0, 3.5, 0)
	H.run(9)
	local title = remotes.Status.Value:match("^(.-)%s%s")
	seen[title or remotes.Status.Value] = true
	for _ = 1, 62 do
		H.run(1)
		if remotes.Shake.Value then
			shakeSeen = true
		end
		-- Bob bleibt oben (Wurf durch Tornado zurücksetzen)
		if b.Character and b.Character:FindFirstChild("HumanoidRootPart") then
			b.Character.HumanoidRootPart.CFrame = roofs[1].CFrame + Vector3.new(0, 3.5, 0)
		end
	end
	H.run(3)
	local winsAfter = a.leaderstats.Wins.Value + b.leaderstats.Wins.Value
	if winsAfter > winsBefore then
		survivedRounds = survivedRounds + 1
	end
	H.check(remotes.Shake.Value == false, "round " .. round .. ": shaking stops after the round")
	H.run(6)
	local inLobby = a.Character and a.Character.HumanoidRootPart.Position.Z < -200
	H.check(inLobby, "round " .. round .. ": players are back in the lobby")
end
local count = 0
for k in pairs(seen) do
	count = count + 1
	print("    disaster seen: " .. k)
end
H.check(count == 6, "all 6 disasters ran (" .. count .. ")")
H.check(shakeSeen, "earthquake shakes the camera")
H.check(survivedRounds >= 1, "survivors get wins (" .. survivedRounds .. " rounds had survivors)")
H.check(a.leaderstats.Coins.Value >= 2900, "coins never go negative")

H.removePlayer(a)
local saved = H.datastore["DisasterSurvival_v1"]["u_" .. a.UserId]
H.check(saved and saved.health == 1, "data saved")
H.shutdown()
H.finish()
