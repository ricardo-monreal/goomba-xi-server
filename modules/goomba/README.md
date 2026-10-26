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
50, 60, 70 and 75, bought with conquest points through menus. LandSandBoat's own modules
(`/opt/goomba/server/modules/custom`, `era`, `example`) are good references.

`sql/accounts_login_tokens.sql` is the table behind the launcher's sign-in (see `patches/` at the
top of this repository); leave it in place.

Plain rates and switches (EXP rate, trusts, level cap...) are settings, not modules: change them
in `settings/main.lua` (or `map.lua`, `login.lua`) in this repo, then `sudo goomba apply &&
sudo goomba restart game`.
