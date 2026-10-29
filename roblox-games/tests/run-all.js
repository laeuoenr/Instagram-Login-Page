// Führt alle test_*.lua nacheinander aus
const { execFileSync } = require("child_process");
const fs = require("fs");
const path = require("path");
let failed = 0;
for (const f of fs.readdirSync(__dirname).filter((f) => /^test_.*\.lua$/.test(f)).sort()) {
  console.log(`\n=== ${f} ===`);
  try {
    execFileSync("node", [path.join(__dirname, "run.js"), path.join(__dirname, f)], { stdio: "inherit" });
  } catch {
    failed++;
  }
}
console.log(failed ? `\n${failed} test file(s) FAILED` : "\nALL TESTS PASSED");
process.exit(failed ? 1 : 0);
