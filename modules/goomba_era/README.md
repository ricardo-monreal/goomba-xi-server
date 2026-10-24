# goomba_era: era fixes as zone patches

LandSandBoat moved zone settings (level caps, which songs and abilities work where, …) from the
`zone_settings` database table to `data/zones/<zone>/zone.yaml`. Two of its era-accuracy SQL files
still update the old table columns, so they stop `dbtool` with "Unknown column":

| LandSandBoat file | What it reverted | Here instead |
| --- | --- | --- |
| `era/sql/abyssea/cop_level_restrictions.sql` | Level caps in the Promyvions, Phomiuna Aqueducts, Sacrarium and Riverne sites (before June 2010) | `data/abyssea_cop_level_caps/` |
| `era/sql/abyssea/job_adjustments.sql` (Mazurka part) | Mazurka usable in towns and fields only (before September 2010) | `data/abyssea_mazurka/` |

`bin/goomba apply` removes just those `UPDATE zone_settings … restriction/misc` statements from
the era SQL while the columns don't exist (everything else in those files still runs), and the
two folders here are loaded through `GOOMBA_ERA_MODULES` in `/etc/goomba/goomba.conf`.

The patches are generated, not hand-written, because a `misc:` patch replaces the zone's whole
list. After moving `LSB_REF` to a newer LandSandBoat, regenerate them from the new checkout:

```bash
sudo goomba update                                    # moves the server to the new LSB_REF
python3 tools/gen-era-zone-patches.py /opt/goomba/server
git add modules/goomba_era && git commit -m "Regenerate era zone patches"
sudo goomba apply && sudo goomba restart game
```

(`python3-yaml` is needed: `sudo apt install python3-yaml`.)

If LandSandBoat fixes its era SQL upstream, the stripping step turns itself off (it only runs
while `sql/zone_settings.sql` has no `restriction` column) and these two folders can be dropped
from `GOOMBA_ERA_MODULES`.
