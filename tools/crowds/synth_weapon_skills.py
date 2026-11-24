#!/usr/bin/env python3
# Write <server>/data/weapon_skills.yaml from <server>/sql/weapon_skills.sql, in the shape
# build_crowds_data.py expects. Upstream LandSandBoat keeps weapon skills in SQL; the Phoenix fork
# the crowds generator came from keeps them in that YAML. Run with -I. Usage:
#   python3 -I synth_weapon_skills.py <server dir>   (default /opt/goomba/server)
import re, sys, os
server = sys.argv[1] if len(sys.argv) > 1 else '/opt/goomba/server'
sql = open(os.path.join(server, 'sql', 'weapon_skills.sql'), encoding='utf-8', errors='replace').read()
# skill id -> name, in LandSandBoat skill order (melee 1..12 are what field parties use)
skill_names = ['hand_to_hand','dagger','sword','great_sword','axe','great_axe','scythe','polearm',
               'katana','great_katana','club','staff','archery','marksmanship','throwing']
jobs_short = [None,'war','mnk','whm','blm','rdm','thf','pld','drk','bst','brd','rng','sam','nin','drg','smn','blu','cor','pup','dnc','sch','geo','run']
sc = ['none','transfixion','compression','liquefaction','scission','reverberation','detonation','induration',
      'impaction','gravitation','distortion','fusion','fragmentation','light','darkness','light_ii','darkness_ii']
rx = re.compile(r"VALUES \((\d+),'([^']*)',(0x[0-9A-Fa-f]+),(.+?)\);")
out = ['# Synthesised from sql/weapon_skills.sql by tools/crowds/synth_weapon_skills.py.', 'weapon_skills:']
n = 0
for m in rx.finditer(sql):
    name, mask = m.group(2), m.group(3)[2:]
    ints = [int(x) for x in m.group(4).split(',')]
    wtype, level, primary, secondary, tertiary, unlock = ints[0], ints[1], ints[8], ints[9], ints[10], ints[12]
    if not (1 <= wtype <= len(skill_names)):
        continue
    by = [int(mask[i:i+2], 16) for i in range(0, len(mask), 2)]
    jobs = [jobs_short[i+1] for i in range(min(22, len(by))) if by[i] != 0 and jobs_short[i+1]]
    scs = [sc[v] for v in (primary, secondary, tertiary) if 0 < v < len(sc)]
    out.append(f'  {name}:')
    out.append(f'    skill: {skill_names[wtype-1]}')
    out.append(f'    level: {level}')
    out.append(f'    jobs: [{", ".join(jobs)}]')
    if scs:
        out.append(f'    skillchain: [{", ".join(scs)}]')
    if unlock:
        out.append(f'    unlock: {unlock}')
    n += 1
open(os.path.join(server, 'data', 'weapon_skills.yaml'), 'w').write('\n'.join(out) + '\n')
print(f'wrote {n} weapon skills to {server}/data/weapon_skills.yaml')
