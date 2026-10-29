local H = require("harness")
local DOUBLE, AUTO, LUCKY, SMALL, BIG, REBIRTH = 9101, 9102, 9103, 9104, 9105, 9106

H.runScript("2-click-simulator/server", nil, {
	["DOUBLE_CLICKS_PASS = 0"] = "DOUBLE_CLICKS_PASS = " .. DOUBLE,
	["AUTO_CLICKER_PASS = 0"] = "AUTO_CLICKER_PASS = " .. AUTO,
	["LUCKY_PASS = 0"] = "LUCKY_PASS = " .. LUCKY,
	["SMALL_PACK_PRODUCT = 0"] = "SMALL_PACK_PRODUCT = " .. SMALL,
	["BIG_PACK_PRODUCT = 0"] = "BIG_PACK_PRODUCT = " .. BIG,
	["INSTANT_REBIRTH_PRODUCT = 0"] = "INSTANT_REBIRTH_PRODUCT = " .. REBIRTH,
})
H.run(1)
local p = H.addPlayer("Alice")
H.run(2)
H.runScript("2-click-simulator/client", p)
H.run(2)

local ls = p.leaderstats
H.check(ls.Clicks.Value == 0 and ls.Rebirths.Value == 0, "new player has 0 clicks / 0 rebirths")
local ui = p.PlayerGui.SimulatorUI
local function button(pattern)
	return H.find(ui, function(d)
		return d.ClassName == "TextButton" and d.Text:find(pattern)
	end)
end

-- Klicken über den echten UI-Button
local click = button("CLICK")
for _ = 1, 10 do
	H.fire(click, "MouseButton1Click")
end
H.run(0.2)
H.check(ls.Clicks.Value == 10, "10 clicks via UI button -> 10 clicks (got " .. ls.Clicks.Value .. ")")

-- Anti-Autoclicker: 40 Klicks in derselben Sekunde
H.run(1.1)
for _ = 1, 40 do
	H.fire(click, "MouseButton1Click")
end
H.run(0.1)
H.check(ls.Clicks.Value == 25, "rate limit caps clicks at 15/s (got " .. ls.Clicks.Value .. ")")

-- Ei öffnen ohne genug Geld
local stand = H.find(workspace, function(d)
	return d.Name == "Basic Egg Stand"
end)
local prompt = stand:FindFirstChildOfClass("ProximityPrompt")
H.fire(prompt, "Triggered", p)
H.run(0.2)
H.check(H.lastMessage("Notify"):find("You need"), "hatching without clicks shows a message")

-- Genug Klicks (Pakete kaufen)
H.check(H.buyProduct(p, SMALL) == Enum.ProductPurchaseDecision.PurchaseGranted, "small pack purchase granted")
H.check(ls.Clicks.Value == 2025, "small pack gives 2000 x click value (got " .. ls.Clicks.Value .. ")")

H.fire(prompt, "Triggered", p)
H.run(3)
local pets = H.json.decode(p:GetAttribute("Pets"))
H.check(#pets == 1, "hatching gives a pet")
H.check(ls.Clicks.Value == 1925, "egg cost deducted")
H.check((p:GetAttribute("ClickValue") or 0) > 1, "pet raises click multiplier")
H.check(p:GetAttribute("EquippedPets") == pets[1], "best pet is equipped")

-- Hatch-Cooldown
H.fire(prompt, "Triggered", p)
H.fire(prompt, "Triggered", p)
H.run(0.1)
H.check(#H.json.decode(p:GetAttribute("Pets")) == 2, "hatch cooldown prevents double hatch")
H.run(3)

-- Viele Eier: Inventar-Limit
for _ = 1, 60 do
	H.buyProduct(p, SMALL)
end
for _ = 1, 60 do
	H.fire(prompt, "Triggered", p)
	H.run(2.6)
end
pets = H.json.decode(p:GetAttribute("Pets"))
H.check(#pets == 50, "pet inventory capped at 50 (got " .. #pets .. ")")

-- Rebirth
local before = ls.Clicks.Value
H.fire(button("Rebirth"), "MouseButton1Click")
H.run(0.2)
H.check(ls.Rebirths.Value == 1 and ls.Clicks.Value == 0, "rebirth with enough clicks works (had " .. math.floor(before) .. ")")
H.fire(button("Rebirth"), "MouseButton1Click")
H.run(0.2)
H.check(ls.Rebirths.Value == 1, "rebirth without enough clicks is refused")
H.buyProduct(p, REBIRTH)
H.check(ls.Rebirths.Value == 2, "instant rebirth product works")

-- Auto-Clicker
H.fire(button("Auto"), "MouseButton1Click")
H.run(0.2)
H.check(H.prompts[#H.prompts].id == AUTO, "auto button prompts the pass when not owned")
H.buyPass(p, AUTO)
H.fire(button("Auto"), "MouseButton1Click")
H.run(0.2)
H.check(p:GetAttribute("AutoOn") == true, "auto clicker can be turned on")
local c0 = ls.Clicks.Value
H.run(5)
H.check(ls.Clicks.Value > c0, "auto clicker earns clicks over time")

-- 2x Pass
local v0 = p:GetAttribute("ClickValue")
H.buyPass(p, DOUBLE)
H.check(math.abs(p:GetAttribute("ClickValue") - v0 * 2) < 1e-6, "2x pass doubles click value")

-- Bestenliste + Speichern
H.run(100)
H.removePlayer(p)
local saved = H.datastore["ClickLegends_v1"]["u_" .. p.UserId]
H.check(saved and saved.rebirths == 2 and #saved.pets == 50, "data saved on leave")
H.check(H.ordered["ClickLegends_TopRebirths_v1"]["u_" .. p.UserId] == 2, "leaderboard entry saved")
local board = H.find(workspace, function(d)
	return d.ClassName == "TextLabel" and d.Text:find("TOP REBIRTHS")
end)
H.run(91)
H.check(board and board.Text:find("User" .. p.UserId), "global leaderboard shows the player")

H.shutdown()
H.finish()
