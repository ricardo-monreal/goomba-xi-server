# Goomba XI modules

Your own server changes, kept apart from LandSandBoat so `goomba update` never overwrites them.
`sudo goomba apply` copies this folder to `/opt/goomba/server/modules/goomba` and adds it, as the
line `goomba`, to the end of LandSandBoat's `modules/init.txt` (after the era modules listed in
`GOOMBA_ERA_MODULES`), so everything here loads last.

| Kind | Put it in | After a change |
| --- | --- | --- |
| Lua (scripts, overrides) | `lua/*.lua` | `sudo goomba apply && sudo goomba restart game` |
| C++ | `cpp/*.cpp` | `sudo goomba apply && sudo goomba build && sudo goomba restart game` |
| SQL (no `DROP TABLE`: it is re-imported on every update) | `sql/*.sql` | `sudo goomba apply && sudo goomba db-update && sudo goomba restart game` |

A Lua module overrides a function from LandSandBoat's `scripts/` and calls `super(...)` to keep the
original behaviour. `lua/welcome.lua` is a small working example; `lua/solo_trusts.lua`
(5 trusts, retail zone and battlefield rules, starter party on login, Geomancer/Rune Fencer/Dancer/Scholar trusts
blocked) is a larger one with options at the top. `lua/trust_shop.lua` adds the Trust Liaison NPC in
Lower Jeuno: every other trust LandSandBoat has (102) in tiers that open at job level 20, 30, 40,
50, 60, 70 and 75, bought with conquest points through menus. `lua/nation_ring_quest.lua` is a
quest, "A Small <Nation> Challenge" (e.g. "A Small Bastok Challenge"): an envoy beside the city gate guard in Southern San d'Oria, Bastok
Markets and Windurst Woods gives any citizen their nation's ring, whatever their race, for
defeating 10 monsters that give experience in each of the two areas outside the city. LandSandBoat's own modules
(`/opt/goomba/server/modules/custom`, `era`, `example`) are good references.

`lua/crowds.lua` is the **living world**: player-looking NPCs (`zone:insertDynamicEntity`) that fill
every era town and the 17 conquest outposts — resting at Home Points, browsing the Auction House,
loitering at shops and emoting. `lua/crowds_field.lua` adds field parties: adventurer camps outside
town that pull, tank, heal, refresh and close skillchains like a real 75-era exp party (they are
mobs on your side, like Garrison soldiers, with a player look). `lua/crowds_chat.lua` +
`lua/crowds_chat_data.lua` are their canned shout/say chatter. Settings are in `lua/crowds_config.lua`
and the in-game `!crowd` / `!crowd field` commands. The spot and gear data in `lua/crowds_data.lua`
is generated from this server's own tables, item data and navmeshes by `tools/crowds/gen-crowds-data.sh`
(re-run after a `goomba update`). Ported from [xi-forever-offline](https://github.com/Hurami89/xi-forever-offline)
(Hurami89, GPL v3); the bot-players half of its living world (which needs a custom C++ module) is not included.

`sql/accounts_login_tokens.sql` is the table behind the launcher's sign-in (see `patches/` at the
top of this repository); leave it in place.

Plain rates and switches (EXP rate, trusts, level cap...) are settings, not modules: change them
in `settings/main.lua` (or `map.lua`, `login.lua`) in this repo, then `sudo goomba apply &&
sudo goomba restart game`.
