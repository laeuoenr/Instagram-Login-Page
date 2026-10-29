local H = require("harness")
local DOUBLE, LUCKY, GROW, RESTOCK, MONEY = 9401, 9402, 9403, 9404, 9405

H.runScript("5-grow-a-garden/server", nil, {
	["DOUBLE_SELL_PASS = 0"] = "DOUBLE_SELL_PASS = " .. DOUBLE,
	["LUCKY_PASS = 0"] = "LUCKY_PASS = " .. LUCKY,
	["INSTANT_GROW_PRODUCT = 0"] = "INSTANT_GROW_PRODUCT = " .. GROW,
	["RESTOCK_PRODUCT = 0"] = "RESTOCK_PRODUCT = " .. RESTOCK,
	["MONEY_PRODUCT = 0"] = "MONEY_PRODUCT = " .. MONEY,
})
H.run(1)
local remotes = game:GetService("ReplicatedStorage").GardenRemotes
H.check(remotes.Seeds.Carrot.Value >= 5, "carrots always in stock at start")

local p = H.addPlayer("Alice")
H.run(2)
H.runScript("5-grow-a-garden/client", p)
H.run(1)
local ls = p.leaderstats
H.check(ls.Sheckles.Value == 20, "start money is 20")
local seeds = H.json.decode(p:GetAttribute("Seeds"))
H.check(seeds.Carrot == 3, "new player gets 3 carrot seeds")

local garden
for _, m in ipairs(workspace.GardenWorld:GetChildren()) do
	if m.ClassName == "Model" and p.RespawnLocation and p.RespawnLocation:IsDescendantOf(m) then
		garden = m
	end
end
H.check(garden ~= nil, "player owns a garden")
local tiles = H.findAll(garden, function(d)
	return d.ClassName == "ProximityPrompt"
end)
H.check(#tiles == 24, "garden has 24 soil tiles")

local ui = p.PlayerGui.GardenUI
local function uiButton(pattern)
	return H.find(ui, function(d)
		return d.ClassName == "TextButton" and d.Text:find(pattern)
	end)
end

-- Ohne Auswahl pflanzen
H.fire(tiles[1], "Triggered", p)
H.run(0.2)
H.check(H.lastMessage("Notify"):find("Select a seed"), "planting without selection shows a hint")

-- Samen in der Hotbar wählen und pflanzen
H.fire(uiButton("^Carrot"), "MouseButton1Click")
H.run(0.2)
H.check(p:GetAttribute("SelectedSeed") == "Carrot", "hotbar selects the seed")
H.fire(tiles[1], "Triggered", p)
H.run(1.2)
H.check(H.json.decode(p:GetAttribute("Seeds")).Carrot == 2, "planting uses a seed")
H.check(tiles[1].Enabled == false, "growing plant cannot be harvested yet")

-- Fremder Spieler
local bob = H.addPlayer("Bob")
H.run(2)
H.fire(tiles[2], "Triggered", bob)
H.run(0.2)
H.check(H.json.decode(p:GetAttribute("Seeds")).Carrot == 2, "others cannot plant in your garden")

-- Wachsen + ernten
H.run(31)
H.check(tiles[1].Enabled == true and tiles[1].ActionText == "Harvest", "carrot is ready after 30s")
H.fire(tiles[1], "Triggered", p)
H.run(0.3)
H.check(p:GetAttribute("FruitCount") == 1, "harvest gives a fruit")
H.check(tiles[1].ActionText == "Plant", "single-harvest crop leaves the soil empty")

-- Verkaufen nur am Stand
H.fire(uiButton("Sell"), "MouseButton1Click")
H.run(0.2)
H.check(H.lastMessage("Notify"):find("Walk to"), "sell button far away asks you to walk to the stand")
local sellPrompt
for _, d in ipairs(workspace.GardenWorld:GetDescendants()) do
	if d.ClassName == "ProximityPrompt" and d.ActionText == "Sell All" then
		sellPrompt = d
	end
end
H.fire(sellPrompt, "Triggered", p)
H.run(0.2)
H.check(ls.Sheckles.Value > 20 and p:GetAttribute("FruitCount") == 0, "selling at the stand gives money (" .. ls.Sheckles.Value .. ")")

-- Samen kaufen
local before = remotes.Seeds.Carrot.Value
local m0 = ls.Sheckles.Value
H.fire(H.find(ui, function(d)
	return d.ClassName == "TextButton" and d.Text == "$10"
end), "MouseButton1Click")
H.run(0.2)
H.check(remotes.Seeds.Carrot.Value == before - 1 and ls.Sheckles.Value == m0 - 10, "buying a seed costs money and stock")

-- Instant Grow
H.fire(tiles[3], "Triggered", p)
H.run(0.2)
H.buyProduct(p, GROW)
H.run(1.2)
H.check(tiles[3].ActionText == "Harvest", "instant grow product makes plants ready")

-- Mehrfach-Ernte (Strawberry)
local d = nil
H.buyProduct(p, MONEY)
H.check(ls.Sheckles.Value >= 3000, "money product gives sheckles (" .. ls.Sheckles.Value .. ")")
remotes.Seeds.Strawberry.Value = 5
remotes.BuySeed:FireServer("Strawberry")
H.run(0.2)
H.fire(tiles[5], "Triggered", p)
H.run(61)
H.fire(tiles[5], "Triggered", p)
H.run(1.2)
H.check(tiles[5].ActionText ~= "Plant", "strawberry regrows after harvest")

-- Ungültige Eingaben vom Client
remotes.BuySeed:FireServer({})
remotes.BuySeed:FireServer("NotASeed")
remotes.SelectSeed:FireServer(123)
H.run(0.2)
H.check(#H.errors == 0, "invalid remote arguments are ignored safely")

-- Restock für alle
H.buyProduct(p, RESTOCK)
H.check(H.lastMessage("Notify"):find("restocked the seed shop for everyone"), "restock product announces to server")

-- Automatischer Restock
H.run(301)
H.check(remotes.RestockAt.Value > os.time(), "shop restocks automatically")

-- Offline-Wachstum: pflanzen, gehen, nach 2 Min wiederkommen
remotes.Seeds.Carrot.Value = 5
remotes.BuySeed:FireServer("Carrot")
H.run(0.2)
H.fire(tiles[7], "Triggered", p)
H.run(0.2)
local uid = p.UserId
H.removePlayer(p)
local saved = H.datastore["GardenGrow_v1"]["u_" .. uid]
H.check(saved and saved.tiles and saved.tiles["7"] and saved.tiles["7"].s == "Carrot", "planted tiles are saved")
H.run(120)
-- gleicher Account kommt zurück: UserId wiederverwenden
local p2 = H.newInstance("Player")
p2.Name, p2.DisplayName, p2.UserId = "Alice", "Alice", uid
local pg = H.newInstance("PlayerGui")
pg.Name = "PlayerGui"
pg.Parent = p2
p2.__methods.LoadCharacter = function() end
p2.Parent = game:GetService("Players")
H.fire(game:GetService("Players"), "PlayerAdded", p2)
H.run(2)
local garden2
for _, m in ipairs(workspace.GardenWorld:GetChildren()) do
	if m.ClassName == "Model" and p2.RespawnLocation and p2.RespawnLocation:IsDescendantOf(m) then
		garden2 = m
	end
end
local tiles2 = H.findAll(garden2, function(x)
	return x.ClassName == "ProximityPrompt"
end)
H.check(tiles2[7].ActionText == "Harvest", "plants keep growing while offline")
H.check(p2.leaderstats.Sheckles.Value > 0, "money restored after rejoin")

H.shutdown()
H.finish()
