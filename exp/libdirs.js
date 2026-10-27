// Prints the real android/ source dir of every autolinked native lib of an RN app,
// plus the cloned nitro-modules package, one per line.
// usage: node libdirs.js <app-dir>
const { execSync } = require('child_process')
const fs = require('fs')
const path = require('path')

const app = path.resolve(process.argv[2])
const out = execSync('npx --no-install react-native config', { cwd: app, maxBuffer: 1e8 }).toString()
const cfg = JSON.parse(out)
const dirs = new Set()
for (const d of Object.values(cfg.dependencies)) {
  const a = d.platforms && d.platforms.android
  if (a && a.sourceDir && fs.existsSync(a.sourceDir)) dirs.add(fs.realpathSync(a.sourceDir))
}
for (const d of [...dirs]) console.log(d)
