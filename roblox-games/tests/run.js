// Startet einen Lua-Test in fengari (Lua 5.3 in JavaScript).
// Aufruf: node run.js <test.lua>   (vorher einmal: npm install)
const fs = require("fs");
const path = require("path");
const { lua, lauxlib, lualib, to_luastring } = require("fengari");

const testFile = path.resolve(process.argv[2]);
const gamesDir = path.resolve(__dirname, "..");
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);

// Alle Spielskripte als Strings bereitstellen: SRC["1-mega-obby/server"] = "..."
lua.lua_newtable(L);
for (const game of fs.readdirSync(gamesDir)) {
  for (const side of ["server", "client"]) {
    const file = path.join(gamesDir, game, "src", side, `Main.${side}.lua`);
    if (fs.existsSync(file)) {
      lua.lua_pushstring(L, to_luastring(fs.readFileSync(file, "utf8")));
      lua.lua_setfield(L, -2, to_luastring(`${game}/${side}`));
    }
  }
}
lua.lua_setglobal(L, to_luastring("SRC"));

const code = `package.path = ${JSON.stringify(__dirname + "/?.lua;")} .. package.path
dofile(${JSON.stringify(testFile)})`;
if (lauxlib.luaL_dostring(L, to_luastring(code)) !== lua.LUA_OK) {
  console.error(lua.lua_tojsstring(L, -1));
  process.exit(1);
}
