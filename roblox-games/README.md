# 5 Roblox-Spiele – fertig zum Einfügen

| # | Spiel | Genre | Was die Spieler machen | Robux-Einnahmen |
|---|-------|-------|------------------------|-----------------|
| 1 | **Mega Obby** | Obby | 60 Stages, die immer schwerer werden (Sprünge, Lava, Spinner, Leitern, verschwindende Plattformen), Wins sammeln | Skip Stage, Speed-Pass, Low-Gravity-Pass |
| 2 | **Click Legends Simulator** | Simulator | Klicken, 4 Eier mit 15 Pets, Rebirths, globale Bestenliste | 2x Clicks, Auto Clicker, Lucky Eggs, Click-Packs, Instant Rebirth |
| 3 | **Money Tycoon** | Tycoon | Eigenes Grundstück, 8 Dropper, Förderband, Upgrader, Deko, Rebirth | 2x Cash, Auto Collect, Cash-Pakete |
| 4 | **Disaster Survival** | Runden-Spiel | 6 Katastrophen (Flut, Lava, Meteore, Tornado, Erdbeben, Säureregen) überleben | VIP (2x Coins), Balloon-Pass, Coin-Pakete |
| 5 | **Garden Grow** | „Grow a Garden“-Stil | Samen kaufen, pflanzen, wächst auch offline, ernten, Mutationen (Gold/Rainbow), verkaufen | 2x Sell, Lucky, Grow All, Server-Restock, Geld-Paket |

Jedes Spiel besteht aus **2 Skripten**. Die Map baut sich beim Start selbst – du musst nichts bauen.
Fortschritt wird gespeichert (DataStore, Auto-Save alle 2 Minuten + beim Verlassen).

---

## Einrichten (pro Spiel ca. 5 Minuten)

1. **Roblox Studio** öffnen → **New** → Vorlage **Baseplate**.
2. Im **Explorer** auf `ServerScriptService` → **+** → **Script** → Inhalt von `src/server/Main.server.lua` hineinkopieren.
3. `StarterPlayer` → `StarterPlayerScripts` → **+** → **LocalScript** → Inhalt von `src/client/Main.client.lua` hineinkopieren.
4. **File → Publish to Roblox** (Name, Beschreibung, Genre festlegen).
5. **Speichern aktivieren:** *Home → Game Settings → Security → „Enable Studio Access to API Services“* einschalten (sonst funktioniert das Speichern nur im echten Spiel, nicht in Studio).
6. **Bei Tycoon und Garden Grow:** *Game Settings → Places → Max Players* = **6** (es gibt 6 Grundstücke).
7. Mit **Play** testen.

> Alternativ mit [Rojo](https://rojo.space): Jeder Spiel-Ordner hat eine `default.project.json` → `rojo build -o Spiel.rbxlx`.

## Geld verdienen: Game Passes & Developer Products anlegen

1. [create.roblox.com](https://create.roblox.com) → dein Spiel → **Monetization** → **Passes** (bzw. **Developer Products**) → **Create**.
2. Die **ID** kopieren und oben im Server-Skript im `CONFIG`-Block eintragen, z. B.:
   ```lua
   SKIP_STAGE_PRODUCT = 1234567890,
   ```
3. Solange eine ID `0` ist, zeigt der Shop-Button „Shop is not set up yet.“ – nichts geht kaputt.

**Preisvorschläge (bewährt):**

| Typ | Preis |
|-----|-------|
| Kleine Pakete / Skip Stage / Restock | 15–49 R$ |
| Große Pakete / Grow All | 99–199 R$ |
| Game Passes (2x, Auto, Lucky, VIP) | 99–399 R$ |

## Damit das Spiel auch gespielt wird (das ist der wichtigste Teil)

Der Code ist nur die halbe Miete. Ob ein Spiel groß wird, entscheidet vor allem:

1. **Thumbnail + Icon**: Bunt, große Schrift, ein Charakter mit Emotion. Das ist der Faktor Nr. 1 für die Klickrate.
2. **Titel**: z. B. „🌱 Garden Grow [NEW SEEDS!]“ – Updates im Titel erhöhen die Klicks.
3. **Werbung**: Mit *Sponsored Experiences* im Creator Dashboard klein anfangen (z. B. 500–1.000 R$) und schauen, welches Spiel die besten Werte hat (D1-Retention, Spielzeit).
4. **Updates**: Erfolgreiche Spiele bekommen jede Woche ein Update (neue Samen, Pets, Stages, Events). Das Gameplay ist so gebaut, dass du in den Tabellen oben im Skript (`SEEDS`, `EGGS`, `ITEMS`, `STAGES`) einfach Einträge ergänzen kannst.
5. **Auf ein Spiel konzentrieren**: Alle 5 veröffentlichen, eine Woche testen, dann das mit den besten Zahlen weiterentwickeln.

## Auszahlung (DevEx)

Robux in echtes Geld umtauschen geht über das **Developer Exchange (DevEx)**-Programm. Voraussetzungen laut Roblox (Stand kann sich ändern – bitte auf der offiziellen Seite prüfen): mindestens 13 Jahre alt (bei Minderjährigen braucht es die Zustimmung der Eltern), verifiziertes Konto, eine Mindestmenge an *verdienten* Robux und Einhaltung der Roblox-Regeln.

## Wichtig zu wissen

- Die Skripte sind syntaktisch geprüft, wurden aber **nicht in Roblox Studio selbst** getestet. Teste jedes Spiel einmal mit *Play* und mit *Test → Start (2 Players)*, bevor du es veröffentlichst. Fehler erscheinen im *Output*-Fenster.
- Niemand kann garantieren, dass ein Spiel viel gespielt wird oder Geld bringt – auf Roblox gibt es Millionen Spiele. Die Genres hier sind aber genau die, die auf Roblox am meisten Geld verdienen.
- Halte dich an die [Roblox Community Standards](https://en.help.roblox.com/hc/articles/203313410) (keine irreführenden Thumbnails, keine „Free Robux“-Versprechen), sonst kann das Spiel gesperrt werden.
