// Generate reference docs from the LandSandBoat source this server runs:
//
//   LSB_DIR=/opt/goomba/server node tools/gen-reference-docs.mjs
//
// Writes docs/gm-commands.md, docs/zone-ids.md and docs/nm-ids.md from the
// checkout's own data, so they match the exact LSB_REF you run (re-run after a
// `goomba update`). No installs or network. Then rebuild the site with
// tools/build-docs.mjs. LSB_DIR defaults to /opt/goomba/server.

import { readFileSync, writeFileSync, readdirSync, existsSync } from 'node:fs'
import { dirname, join, basename } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const LSB = process.env.LSB_DIR || '/opt/goomba/server'
const docs = join(root, 'docs')

if (!existsSync(join(LSB, 'sql', 'zone_settings.sql'))) {
  console.error(`LandSandBoat source not found at ${LSB}. Set LSB_DIR to the checkout (e.g. /opt/goomba/server).`)
  process.exit(1)
}

const esc = (s) => String(s).replace(/\|/g, '\\|')

// ---- zones: id -> internal name -------------------------------------------------------------
const zoneSql = readFileSync(join(LSB, 'sql', 'zone_settings.sql'), 'utf8')
const zoneById = new Map()
const zoneIdByFolder = new Map()
for (const m of zoneSql.matchAll(/INSERT INTO `zone_settings` VALUES \((\d+),'[^']*',\d+,'([^']*)'\)/g)) {
  const id = Number(m[1])
  const internal = m[2]
  zoneById.set(id, internal)
  zoneIdByFolder.set(internal.toLowerCase(), id)
}

// A readable zone name from the internal one (underscores to spaces, a few apostrophes).
const prettyZone = (internal) =>
  internal
    .replace(/_/g, ' ')
    .replace(/\bd Oria\b/g, "d'Oria")
    .replace(/\bd Oraguille\b/g, "d'Oraguille")
    .replace(/\bGhoyu s\b/g, "Ghoyu's")
    .replace(/\bRala\b/g, 'Rala')

// ---- GM commands ----------------------------------------------------------------------------
function buildCommands() {
  const dir = join(LSB, 'scripts', 'commands')
  const rows = []
  for (const f of readdirSync(dir).filter((n) => n.endsWith('.lua'))) {
    const name = basename(f, '.lua')
    const src = readFileSync(join(dir, f), 'utf8')
    const perm = src.match(/permission\s*=\s*(\d+)/)
    const func = src.match(/^--\s*func:\s*(.+?)\s*$/m)
    const desc = src.match(/^--\s*desc:\s*(.+?)\s*$/m)
    rows.push({
      name,
      level: perm ? Number(perm[1]) : '',
      usage: (func ? func[1] : name).replace(/^!+\s*/, ''),
      desc: desc ? desc[1] : ''
    })
  }
  rows.sort((a, b) => a.name.localeCompare(b.name))

  let md = `# GM commands

Every in-game command on this server, read from \`scripts/commands/\` in the LandSandBoat build it runs. In game, commands start with \`!\` (for example \`!pos\`, \`!additem\`). Give yourself command access with \`sudo goomba gm <account> 5\` on the game server; the **Level** column is the minimum GM level a command needs.

${rows.length} commands.

| Command | Level | What it does |
| --- | --- | --- |
`
  for (const r of rows) md += `| \`!${esc(r.usage)}\` | ${r.level} | ${esc(r.desc)} |\n`
  writeFileSync(join(docs, 'gm-commands.md'), md)
  return rows.length
}

// ---- zone IDs -------------------------------------------------------------------------------
function buildZones() {
  const rows = [...zoneById.entries()]
    .filter(([, name]) => name && name.toLowerCase() !== 'unknown')
    .sort((a, b) => a[0] - b[0])
  let md = `# Zone IDs

Every zone and its ID, from \`sql/zone_settings.sql\`. Use the ID with commands that take one, for example \`!zone <id>\` to warp, or \`sudo goomba zone-ip\` notes. The **Internal name** is the folder name under \`scripts/zones/\`.

${rows.length} zones.

| ID | Zone | Internal name |
| --- | --- | --- |
`
  for (const [id, internal] of rows) md += `| ${id} | ${esc(prettyZone(internal))} | \`${esc(internal)}\` |\n`
  writeFileSync(join(docs, 'zone-ids.md'), md)
  return rows.length
}

// ---- NM IDs (from data/zones/<zone>/mobs.yaml, type: [notorious]) ---------------------------
// Light line scan of the YAML: template keys sit at two-space indent, with id: and type: below.
function notoriousInFile(file) {
  const out = []
  const lines = readFileSync(file, 'utf8').split('\n')
  let inTemplates = false
  let cur = null
  const flush = () => {
    if (cur && cur.id != null && cur.notorious) out.push({ name: cur.name, id: cur.id })
    cur = null
  }
  for (const line of lines) {
    if (/^templates:\s*$/.test(line)) { inTemplates = true; continue }
    if (inTemplates && /^[A-Za-z0-9_]/.test(line)) { flush(); inTemplates = false; continue } // next top-level key
    if (!inTemplates) continue
    const head = line.match(/^ {2}([A-Za-z0-9_]+):\s*$/)
    if (head) { flush(); cur = { name: head[1], id: null, notorious: false }; continue }
    if (!cur) continue
    const id = line.match(/^ {4,}id:\s*(\d+)/)
    if (id) cur.id = Number(id[1])
    const type = line.match(/^ {4,}type:\s*(.+)$/)
    if (type && /\bnotorious\b/.test(type[1])) cur.notorious = true
  }
  flush()
  return out
}

function buildNMs() {
  const zonesDir = join(LSB, 'data', 'zones')
  const rows = []
  if (existsSync(zonesDir)) {
    for (const folder of readdirSync(zonesDir)) {
      const mobsFile = join(zonesDir, folder, 'mobs.yaml')
      if (!existsSync(mobsFile)) continue
      const zid = zoneIdByFolder.get(folder.toLowerCase())
      if (zid == null) continue
      for (const nm of notoriousInFile(mobsFile)) {
        const full = 0x1000000 | (zid << 12) | nm.id
        rows.push({ zid, zone: prettyZone(zoneById.get(zid)), name: nm.name.replace(/_/g, ' '), id: full })
      }
    }
  }
  rows.sort((a, b) => a.zid - b.zid || a.name.localeCompare(b.name))
  let md = `# Notorious Monster IDs

Every notorious monster (NM) in the LandSandBoat build this server runs, read from \`data/zones/<zone>/mobs.yaml\` (templates marked \`type: [notorious]\`). The **Mob ID** is the full entity ID, the number GM commands such as \`!spawnmob <id>\` take; the hex form is the same value.

${rows.length} notorious monsters &mdash; field NMs as well as battlefield, mission and event monsters flagged notorious. Search with your browser's find (Ctrl+F / Cmd+F).

| Zone | Notorious Monster | Mob ID | Hex |
| --- | --- | --- | --- |
`
  for (const r of rows) md += `| ${esc(r.zone)} | ${esc(r.name)} | ${r.id} | \`0x${r.id.toString(16).toUpperCase()}\` |\n`
  writeFileSync(join(docs, 'nm-ids.md'), md)
  return rows.length
}

const c = buildCommands()
const z = buildZones()
const n = buildNMs()
console.log(`Wrote docs/gm-commands.md (${c}), docs/zone-ids.md (${z}), docs/nm-ids.md (${n}) from ${LSB}`)
