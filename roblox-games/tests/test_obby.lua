local H = require("harness")
local SKIP, SPEED, GRAV = 9001, 9002, 9003

H.runScript("1-mega-obby/server", nil, {
	["SKIP_STAGE_PRODUCT = 0"] = "SKIP_STAGE_PRODUCT = " .. SKIP,
	["SPEED_PASS = 0"] = "SPEED_PASS = " .. SPEED,
	["LOW_GRAVITY_PASS = 0"] = "LOW_GRAVITY_PASS = " .. GRAV,
})
H.run(1)

local map = workspace:FindFirstChild("ObbyMap")
H.check(map ~= nil, "map folder is built")
local checkpoints = H.findAll(map, function(d)
	return d.Name == "Checkpoint"
end)
H.check(#checkpoints == 60, "60 checkpoints exist (got " .. #checkpoints .. ")")
H.check(workspace:FindFirstChild("Baseplate") == nil, "baseplate removed")

local p = H.addPlayer("Alice")
H.run(2)
H.runScript("1-mega-obby/client", p)
H.run(2)
H.check(p.leaderstats.Stage.Value == 0, "new player starts at stage 0")
H.check(p.PlayerGui:FindFirstChild("ObbyUI") ~= nil, "client UI created")

local function checkpoint(n)
	return H.find(map, function(d)
		return d.Name == "Checkpoint" and d:GetAttribute("Stage") == n
	end)
end

-- Checkpoints der Reihe nach berühren
H.touch(checkpoint(1), p.Character)
H.run(0.2)
H.check(p.leaderstats.Stage.Value == 1, "touching checkpoint 1 -> stage 1")
H.touch(checkpoint(3), p.Character)
H.run(0.2)
H.check(p.leaderstats.Stage.Value == 1, "skipping ahead to checkpoint 3 is ignored")
H.touch(checkpoint(2), p.Character)
H.run(0.2)
H.check(p.leaderstats.Stage.Value == 2, "checkpoint 2 -> stage 2")

-- Respawn bringt zum Checkpoint
p.Character.Humanoid.Health = 0
H.run(6)
local rootPos = p.Character.HumanoidRootPart.Position
local cpPos = checkpoint(2).Position
H.check((rootPos - cpPos).Magnitude < 6, "respawn teleports to current checkpoint")

-- Kill-Teile
local lava = map:FindFirstChild("LavaSea")
H.touch(lava, p.Character)
H.run(0.2)
H.check(p.Character.Humanoid.Health == 0, "lava kills the player")
H.run(6)

-- Skip-Stage kaufen
local decision = H.buyProduct(p, SKIP)
H.check(decision == Enum.ProductPurchaseDecision.PurchaseGranted, "skip stage purchase granted")
H.check(p.leaderstats.Stage.Value == 3, "skip stage -> stage 3")

-- Pässe
H.buyPass(p, SPEED)
H.check(p.Character.Humanoid.WalkSpeed > 16, "speed pass raises walk speed immediately")
H.buyPass(p, GRAV)
H.check(p.Character.HumanoidRootPart:FindFirstChild("LowGravity") ~= nil, "low gravity force added")

-- Client-Buttons
local ui = p.PlayerGui.ObbyUI
local skipButton = H.find(ui, function(d)
	return d.ClassName == "TextButton" and d.Text:find("Skip")
end)
H.fire(skipButton, "MouseButton1Click")
H.run(0.2)
H.check(#H.prompts == 1 and H.prompts[1].id == SKIP, "skip button prompts the product")

-- Gewinnen
for n = 4, 60 do
	H.touch(checkpoint(n), p.Character)
	H.run(0.05)
end
H.check(p.leaderstats.Stage.Value == 60, "can reach stage 60")
H.touch(map.WinPad, p.Character)
H.run(3)
H.check(p.leaderstats.Wins.Value == 1 and p.leaderstats.Stage.Value == 0, "win pad gives a win and resets stage")

-- Speichern & Laden
H.touch(checkpoint(1), p.Character)
H.run(0.2)
H.removePlayer(p)
local p2 = H.addPlayer("Alice") -- neuer Spieler-Objekt, andere UserId -> darum Daten direkt prüfen
H.run(2)
local saved
for key, value in pairs(H.datastore["MegaObby_v1"]) do
	if key == "u_" .. p.UserId then
		saved = value
	end
end
H.check(saved and saved.stage == 1 and saved.wins == 1, "progress saved on leave")
H.removePlayer(p2)

-- DataStore-Ausfall: nichts überschreiben
H.failDataStore = true
local p3 = H.addPlayer("Bob")
H.run(5)
H.check(H.lastMessage("Notify") and H.lastMessage("Notify"):find("could not be loaded"), "player is warned when data fails to load")
H.failDataStore = false
H.removePlayer(p3)
H.check(H.datastore["MegaObby_v1"]["u_" .. p3.UserId] == nil, "failed load -> data is not overwritten")

H.run(130) -- Auto-Save-Schleife einmal laufen lassen
H.shutdown()
H.finish()
