local H = require("harness")
local DOUBLE, AUTO, SMALL, BIG = 9201, 9202, 9203, 9204

H.runScript("3-money-tycoon/server", nil, {
	["DOUBLE_CASH_PASS = 0"] = "DOUBLE_CASH_PASS = " .. DOUBLE,
	["AUTO_COLLECT_PASS = 0"] = "AUTO_COLLECT_PASS = " .. AUTO,
	["SMALL_CASH_PRODUCT = 0"] = "SMALL_CASH_PRODUCT = " .. SMALL,
	["BIG_CASH_PRODUCT = 0"] = "BIG_CASH_PRODUCT = " .. BIG,
})
H.run(1)
local tycoons = workspace.Tycoons
H.check(#tycoons:GetChildren() == 6, "6 plots are built")

local p = H.addPlayer("Alice")
H.run(2)
H.runScript("3-money-tycoon/client", p)
H.run(1)
local ls = p.leaderstats
H.check(ls.Cash.Value == 50, "start cash is 50")

local plot
for _, m in ipairs(tycoons:GetChildren()) do
	if p.RespawnLocation and p.RespawnLocation:IsDescendantOf(m) then
		plot = m
	end
end
H.check(plot ~= nil, "player got a plot and respawns there")
H.check((p.Character.HumanoidRootPart.Position - p.RespawnLocation.Position).Magnitude < 8, "player is teleported to their plot")

local function buttonFor(name)
	for _, b in ipairs(plot.Buttons:GetChildren()) do
		local label = b:FindFirstChildOfClass("BillboardGui"):FindFirstChildOfClass("TextLabel")
		if label.Text:find("^" .. name .. "\n") then
			return b
		end
	end
	return nil
end
H.check(#plot.Buttons:GetChildren() == 1 and buttonFor("Dropper"), "only the first dropper button is shown at start")

-- Ein anderer Spieler kann nicht kaufen
local bob = H.addPlayer("Bob")
H.run(2)
H.touch(buttonFor("Dropper"), bob.Character)
H.run(0.6)
H.check(#plot.Items:GetChildren() == 0, "other players cannot buy on your plot")

-- Dropper kaufen
H.touch(buttonFor("Dropper"), p.Character)
H.run(0.6)
H.check(ls.Cash.Value == 0, "buying dropper costs 50")
H.check(plot.Items:FindFirstChild("dropper1") ~= nil, "dropper is built")
H.check(#plot.Buttons:GetChildren() == 2, "new buttons unlocked (dropper 2 + walls)")

-- Dropper erzeugt Erz; Erz am Sammler verkaufen
H.run(4.5)
local ores = plot.Ore:GetChildren()
H.check(#ores >= 2, "dropper spawns ore (" .. #ores .. ")")
local collector = H.find(plot, function(d)
	return d.ClassName == "Part" and d:FindFirstChildOfClass("BillboardGui") and d:FindFirstChildOfClass("BillboardGui"):FindFirstChildOfClass("TextLabel").Text == "SELL"
end)
for _, ore in ipairs(ores) do
	H.fire(collector, "Touched", ore)
	H.fire(collector, "Touched", ore) -- doppelt berühren darf nicht doppelt zählen
end
H.run(0.1)
local pad = H.find(plot, function(d)
	local gui = d:FindFirstChildOfClass("BillboardGui")
	return gui and gui:FindFirstChildOfClass("TextLabel").Text:find("Collect")
end)
local padLabel = pad:FindFirstChildOfClass("BillboardGui"):FindFirstChildOfClass("TextLabel")
H.check(padLabel.Text == "💰 Collect $" .. (#ores * 5), "collector stores pending cash once per ore (" .. padLabel.Text .. ")")
H.touch(pad, p.Character)
H.run(0.1)
H.check(ls.Cash.Value == #ores * 5, "stepping on pad collects cash")

-- Erz verschwindet nach Ablauf
H.run(25)
H.check(#plot.Ore:GetChildren() <= 11, "old ore is cleaned up (" .. #plot.Ore:GetChildren() .. ")")

-- Geld-Paket
H.check(H.buyProduct(p, SMALL) == Enum.ProductPurchaseDecision.PurchaseGranted, "cash pack purchase granted")
H.check(ls.Cash.Value >= 1500, "cash pack gives ~10 min of income (" .. ls.Cash.Value .. ")")

-- Alles kaufen (genug Geld geben)
for _ = 1, 400 do
	H.buyProduct(p, BIG)
	if ls.Cash.Value > 3e6 then
		break
	end
end
local bought = 0
for _ = 1, 30 do
	local any = false
	for _, b in ipairs(plot.Buttons:GetChildren()) do
		H.touch(b, p.Character)
		any = true
	end
	H.run(0.6)
	if not any then
		break
	end
end
bought = #plot.Items:GetChildren()
H.check(bought == 16, "all 16 items can be bought (" .. bought .. ")")

-- Upgrader multipliziert
local ore = plot.Ore:GetChildren()[1]
local up = H.find(plot.Items.upgrader1, function(d)
	return d.Transparency == 0.4
end)
local v0 = ore:GetAttribute("Value")
H.fire(up, "Touched", ore)
H.fire(up, "Touched", ore)
H.check(ore:GetAttribute("Value") == v0 * 2, "upgrader doubles ore value exactly once")

-- Auto-Collect-Pass
H.buyPass(p, AUTO)
local c0 = ls.Cash.Value
local fresh = plot.Ore:GetChildren()[2]
H.fire(collector, "Touched", fresh)
H.run(0.1)
H.check(ls.Cash.Value > c0, "auto collect puts cash directly in wallet")

-- Rebirth
H.fire(H.find(p.PlayerGui, function(d)
	return d.ClassName == "TextButton" and d.Text:find("Rebirth")
end), "MouseButton1Click")
H.run(0.5)
H.check(ls.Rebirths.Value == 1 and ls.Cash.Value == 50, "rebirth resets cash and counts rebirth")
H.check(#plot.Items:GetChildren() == 0, "rebirth clears the plot")

-- Verlassen: Grundstück wird frei, Daten gespeichert
H.removePlayer(p)
H.check(#plot.Items:GetChildren() == 0 and #plot.Buttons:GetChildren() == 0, "plot is cleared when owner leaves")
local saved = H.datastore["MoneyTycoon_v1"]["u_" .. p.UserId]
H.check(saved and saved.rebirths == 1, "data saved")

-- Volle Server: 7. Spieler
local extra = {}
for i = 1, 6 do
	extra[i] = H.addPlayer("P" .. i)
end
H.run(3)
H.check(H.lastMessage("Notify"):find("All plots are taken"), "7th player is told all plots are taken")

-- Gespeicherte Käufe werden wieder aufgebaut
local c = H.addPlayer("Carol")
H.run(2)
local cplot
for _, m in ipairs(tycoons:GetChildren()) do
	if c.RespawnLocation and c.RespawnLocation:IsDescendantOf(m) then
		cplot = m
	end
end
H.check(cplot == nil, "no plot when full")

H.shutdown()
H.finish()
