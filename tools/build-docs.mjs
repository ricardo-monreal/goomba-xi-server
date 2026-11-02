// Build the offline HTML documentation site from docs/*.md into docs-site/.
//
//   node tools/build-docs.mjs
//
// No installs, no network: Markdown is rendered by the vendored copy of marked
// (tools/vendor/marked.esm.js, MIT — see marked.LICENSE). The result is a static
// site that opens straight from disk (double-click docs-site/index.html) and can
// also be dropped on any web host. Links between pages, a sidebar and search all
// work with the files open locally (file://). Re-run after editing any doc.

import { Marked } from './vendor/marked.esm.js'
import { readFileSync, writeFileSync, mkdirSync, copyFileSync, existsSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const docsDir = join(root, 'docs')
const outDir = join(root, 'docs-site')

// Sidebar order, source file, and the one-line description shown on the home page.
const pages = [
  { slug: 'install', file: 'install.md', nav: 'Install', desc: 'From an empty Proxmox host to players logging in.' },
  { slug: 'features', file: 'features.md', nav: 'Gameplay features', desc: 'Era, rates, trusts, quests — what Goomba XI changes and where.' },
  { slug: 'operations', file: 'operations.md', nav: 'Operations', desc: 'Running the server day to day: commands, settings, backups.' },
  { slug: 'updating', file: 'updating.md', nav: 'Updating', desc: 'Moving to a newer LandSandBoat commit.' },
  { slug: 'file-server', file: 'file-server.md', nav: 'File server', desc: 'The client host: backups, community packs and addons.' },
  { slug: 'client-and-launcher', file: 'client-and-launcher.md', nav: 'Client & launcher', desc: 'Build the game client and publish the launcher.' },
  { slug: 'auction-house', file: 'auction-house.md', nav: 'Auction House', desc: 'The Auction House bot for solo and small-group play.' },
  { slug: 'moving-to-vps', file: 'moving-to-vps.md', nav: 'Moving to a VPS', desc: 'Taking the server off your home network.' },
  { slug: 'without-github', file: 'without-github.md', nav: 'Without GitHub', desc: 'Install, update and build entirely from your own machines.' },
  { slug: 'gm-commands', file: 'gm-commands.md', nav: 'GM commands', desc: 'Every in-game ! command and the GM level it needs.', group: 'Reference' },
  { slug: 'zone-ids', file: 'zone-ids.md', nav: 'Zone IDs', desc: 'Every zone and its ID.', group: 'Reference' },
  { slug: 'nm-ids', file: 'nm-ids.md', nav: 'NM IDs', desc: 'Every notorious monster and its mob ID.', group: 'Reference' }
]

const fileToSlug = new Map(pages.map((p) => [p.file, p.slug]))

// GitHub-style heading slugs, so in-page anchors like #part-1-the-game-server-vm resolve.
const slugify = (s) =>
  s.toLowerCase().trim().replace(/[^\w\s-]/g, '').replace(/\s+/g, '-').replace(/-+/g, '-')

const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')

function newMarked() {
  const m = new Marked()
  m.use({
    renderer: {
      heading(token) {
        const text = this.parser.parseInline(token.tokens)
        return `<h${token.depth} id="${slugify(token.text)}">${text}</h${token.depth}>\n`
      },
      link(token) {
        let href = token.href || ''
        // A link to another doc becomes a link to its built page.
        href = href.replace(/^([\w-]+)\.md(#.*)?$/, (_, base, hash) => `${fileToSlug.get(base + '.md') || base}.html${hash || ''}`)
        const external = /^https?:\/\//i.test(href)
        const text = this.parser.parseInline(token.tokens)
        const title = token.title ? ` title="${esc(token.title)}"` : ''
        const rel = external ? ' target="_blank" rel="noopener noreferrer"' : ''
        return `<a href="${href}"${title}${rel}>${text}</a>`
      }
    }
  })
  return m
}

// Pull the leading "# Title" out so it can head the page template instead of repeating.
function splitTitle(md, fallback) {
  const m = md.match(/^\s*#\s+(.+?)\s*$/m)
  if (m) return { title: m[1].replace(/`/g, ''), body: md.replace(m[0], '').trim() }
  return { title: fallback, body: md }
}

const SITE = 'Goomba XI'

function navHtml(activeSlug) {
  let seenGroup = null
  const items = pages
    .map((p) => {
      let prefix = ''
      if (p.group && p.group !== seenGroup) {
        seenGroup = p.group
        prefix = `      <div class="nav-group">${p.group}</div>\n`
      }
      return `${prefix}      <a class="nav-link${p.slug === activeSlug ? ' active' : ''}" href="${p.slug}.html">${p.nav}</a>`
    })
    .join('\n')
  return `    <a class="nav-link nav-home${activeSlug === 'index' ? ' active' : ''}" href="index.html">Home</a>\n${items}`
}

function layout({ slug, title, contentHtml }) {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(title)} · ${SITE} docs</title>
<link rel="stylesheet" href="docs.css">
</head>
<body>
<input type="checkbox" id="nav-toggle" hidden>
<header class="topbar">
  <label for="nav-toggle" class="burger" aria-label="Menu"><span></span><span></span><span></span></label>
  <a class="brand" href="index.html"><span class="brand-mark" aria-hidden="true">◆</span> ${SITE} <small>docs</small></a>
</header>
<div class="layout">
  <nav class="sidebar" aria-label="Documentation">
${navHtml(slug)}
    <div class="nav-foot">Offline copy · <a href="https://github.com/ricardo-monreal/goomba-xi-server" target="_blank" rel="noopener noreferrer">source</a></div>
  </nav>
  <label for="nav-toggle" class="scrim" aria-hidden="true"></label>
  <main class="content">
    <article>
      <h1 class="page-title">${esc(title)}</h1>
${contentHtml}
    </article>
  </main>
</div>
</body>
</html>
`
}

function homePage() {
  let seen = null
  const cards = pages
    .map((p) => {
      let pre = ''
      if (p.group && p.group !== seen) { seen = p.group; pre = `      <h2 class="card-group">${p.group}</h2>\n` }
      return `${pre}      <a class="card" href="${p.slug}.html">
        <h3>${p.nav}</h3>
        <p>${esc(p.desc)}</p>
      </a>`
    })
    .join('\n')
  const content = `    <p class="lede">Everything needed to run the Goomba XI FINAL FANTASY XI preservation server and its website &mdash; a Level&nbsp;75 era server built on LandSandBoat. This is an offline copy of the documentation; start with <a href="install.html">Install</a>.</p>
    <div class="cards">
${cards}
    </div>`
  return layout({ slug: 'index', title: 'Documentation', contentHtml: content })
}

// ---- build ----
mkdirSync(outDir, { recursive: true })

for (const p of pages) {
  const src = join(docsDir, p.file)
  if (!existsSync(src)) {
    console.warn(`skip: ${p.file} not found`)
    continue
  }
  const { title, body } = splitTitle(readFileSync(src, 'utf8'), p.nav)
  const html = newMarked().parse(body)
  writeFileSync(join(outDir, `${p.slug}.html`), layout({ slug: p.slug, title, contentHtml: html }))
}

writeFileSync(join(outDir, 'index.html'), homePage())
copyFileSync(join(root, 'tools', 'docs.css'), join(outDir, 'docs.css'))

console.log(`Built ${pages.length + 1} pages into ${outDir}`)
