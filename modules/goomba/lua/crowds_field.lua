-----------------------------------
-- Ambient crowds, phase 3: field parties. Used by crowds.lua (not listed in init.txt itself).
--
-- A party of 5-6 adventurers sets up camp in a field area, near monsters a few levels above them ("Tough" to
-- "Incredibly Tough", like a real 75-era exp party), and plays it like players did:
--   * the puller (THF, RNG or BRD, else the tank) runs out, takes a free monster and runs back to camp
--   * the tank (PLD or NIN from 30, WAR before) takes hate: "Provoke", Flash, Utsusemi, re-Provoke every 30 s
--   * the healer (WHM) cures whoever drops low, the tank first; the support (RDM or BRD) refreshes, hastes, sings,
--     and puts Dia/Slow/Paralyze on the monster; a monster that joins in (an add) is put to sleep and fought next
--   * the damage dealers build TP and close skillchains (one opens, the next closes with a weapon skill that
--     chains); the BLM magic-bursts the right element right after the close
--   * after a fight the mages rest (/heal) when their MP is low; then the next pull
--   * they can die; when the tank and the healer are both down, or fewer than two stand, the party is over
-- Bots are monsters on your side (like Garrison soldiers: server group "Garrison" in GM Home), with a player look.
-- Monsters they kill give nobody anything and respawn normally. They never take a monster that is fighting you,
-- your squad or Kurami, or one within 40 yalms of a player, and they never camp near you.
-----------------------------------
local F = {}
local unpack = unpack or table.unpack
local env                      -- from crowds.lua: cfg, data, makeName, makeLook, dist2, pickWeighted

-- Tuning ----------------------------------------------------------------------------------------------------
local PLAYER_SPACE   = 40      -- yalms: no monster this close to a player is taken
local CAMP_SPACE     = 50      -- yalms: no camp this close to a player
local PULL_RANGE     = 45      -- yalms: monsters this far from camp can be pulled
local SAY_RANGE      = 25      -- yalms: party talk is heard this close
local BRAIN_FIGHT    = 1500    -- ms between decisions in a fight or a pull
local BRAIN_IDLE     = 3000    -- ms between decisions while resting
local EMPTY_DESPAWN  = 5 * 60  -- seconds an area must be empty before its parties leave
local NEW_PARTY_WAIT = { 6 * 60, 12 * 60 }   -- seconds before a new party comes after one is over
local STRENGTH       = { hpp = 40, def = 15, acc = 20, att = 10 } -- a little help: they have no real gear stats
local REST_TICK_HPP  = 3       -- % of max HP back per resting tick (3 s)
local REST_TICK_MPP  = 4

local parties = {}             -- [zone id] = { list = { party }, nextAt = os.time(), emptySince = time }
local serial = 0

local SC_COMBOS =              -- opener property -> closer property -> resulting skillchain
{
    transfixion   = { compression = 'compression', scission = 'distortion', reverberation = 'reverberation' },
    compression   = { transfixion = 'transfixion', detonation = 'detonation' },
    liquefaction  = { scission = 'scission', impaction = 'fusion' },
    scission      = { liquefaction = 'liquefaction', reverberation = 'reverberation', detonation = 'detonation' },
    reverberation = { induration = 'induration', impaction = 'impaction' },
    detonation    = { scission = 'scission', compression = 'gravitation' },
    induration    = { compression = 'compression', reverberation = 'fragmentation', impaction = 'impaction' },
    impaction     = { liquefaction = 'liquefaction', detonation = 'detonation' },
    gravitation   = { distortion = 'darkness', fragmentation = 'fragmentation' },
    distortion    = { gravitation = 'darkness', fusion = 'fusion' },
    fusion        = { gravitation = 'gravitation', fragmentation = 'light' },
    fragmentation = { fusion = 'light', distortion = 'distortion' },
}
local MB_ELEMENT =             -- skillchain -> element to burst with
{
    liquefaction = 'fire', scission = 'stone', reverberation = 'water', detonation = 'aero', induration = 'blizzard',
    impaction = 'thunder', gravitation = 'stone', distortion = 'blizzard', fusion = 'fire', fragmentation = 'thunder',
    light = 'thunder', darkness = 'blizzard',
}

-----------------------------------
-- helpers
-----------------------------------
-- players in an area, without the bot players (bots.lua): bots do not keep crowds or field parties alive
local function realPlayers(zone)
    if xi.crowds and xi.crowds.realPlayers then
        return xi.crowds.realPlayers(zone)
    end

    return zone:getPlayers()
end

local function rnd(a, b)
    return math.random(a, b)
end

local function pick(list)
    return list[rnd(1, #list)]
end

local function now()
    return os.time()
end

local function d2(a, b)
    return env.dist2(a.x, a.z, b.x, b.z)
end

local function prettyName(entity)
    local ok, name = pcall(function() return entity:getName() end)
    return ((ok and name) or 'it'):gsub('_', ' ')
end

local function alive(e)
    if e == nil then
        return false
    end

    local ok, res = pcall(function() return e:isAlive() end)
    return ok and res
end

local function memberEntity(m)
    if m.dead then
        return nil
    end

    local e = GetMobByID(m.id)
    if e and alive(e) then
        return e
    end

    return nil
end

local function say(party, m, text)
    local e = memberEntity(m)
    local zone = GetZone(party.zoneId)
    if not e or not zone then
        return
    end

    local pos = e:getPos()
    for _, p in ipairs(realPlayers(zone)) do
        local pp = p:getPos()
        if env.dist2(pp.x, pp.z, pos.x, pos.z) <= SAY_RANGE * SAY_RANGE then
            p:printToPlayer(text, (xi.msg and xi.msg.channel and xi.msg.channel.SAY) or 0, m.name)
        end
    end
end

local function spellFor(job, lvl, names)
    -- the highest of the given spells (best first) this job knows at this level
    for _, name in ipairs(names) do
        local s = env.data.spells and env.data.spells[name]
        if s and s[2][job] and s[2][job] <= lvl then
            return s[1], name
        end
    end

    return nil
end

local function spellName(name)
    local s = name:gsub('_([iv]+)$', function(t) return ' ' .. string.upper(t) end)
    s = s:gsub('^%l', string.upper):gsub('_', ' ')
    return s
end

local function wsList(job, lvl)
    local out = {}
    for _, w in ipairs((env.data.ws or {})[job] or {}) do
        if w[1] <= lvl then
            out[#out + 1] = w
        end
    end

    return out
end


local function playersOf(zone)
    local list = {}
    for _, p in ipairs(realPlayers(zone)) do
        list[#list + 1] = p:getPos()
    end

    return list
end

local function nearAnyPlayer(pos, players, range)
    for _, pp in ipairs(players) do
        if env.dist2(pp.x, pp.z, pos.x, pos.z) <= range * range then
            return true
        end
    end

    return false
end

local function isEnemy(mob)
    local ok, a = pcall(function() return mob:getAllegiance() end)
    return ok and a == ((xi.allegiance and xi.allegiance.MOB) or 0)
end

-- A monster the party may take: a normal enemy, alive, not fighting anyone, not near a player
local function free(mob, players)
    if not isEnemy(mob) or not alive(mob) then
        return false
    end

    local ok, busy = pcall(function() return mob:isNM() or mob:isEngaged() or mob:getTarget() ~= nil end)
    if not ok or busy then
        return false
    end

    return not nearAnyPlayer(mob:getPos(), players, PLAYER_SPACE)
end

-----------------------------------
-- making a party
-----------------------------------
local BASE_DD = { 'MNK', 'THF', 'WAR' }
local DD_30   = { 'SAM', 'DRK', 'WAR', 'MNK', 'THF', 'DRG', 'BLU', 'RNG', 'SAM', 'DRK' }

local function composition(lvl)
    local roles = {}
    local tank = lvl >= 30 and pick({ 'PLD', 'NIN', 'PLD', 'NIN', 'WAR' }) or 'WAR'
    roles[#roles + 1] = { job = tank, role = 'tank' }
    roles[#roles + 1] = { job = 'WHM', role = 'healer' }
    roles[#roles + 1] = { job = (lvl >= 30 and math.random() < 0.4) and 'BRD' or 'RDM', role = 'support' }
    local size = math.random() < 0.75 and 6 or 5
    if math.random() < (lvl < 50 and 0.7 or 0.35) then
        roles[#roles + 1] = { job = 'BLM', role = 'nuker' }
    end

    local pool = lvl >= 30 and DD_30 or BASE_DD
    while #roles < size do
        local job = pick(pool)
        if not (job == tank and job == 'WAR' and lvl < 30 and #roles < 4) then
            roles[#roles + 1] = { job = job, role = 'dd' }
        end
    end

    -- the puller
    local pullerIdx
    for _, want in ipairs({ 'THF', 'RNG', 'BRD' }) do
        for i, r in ipairs(roles) do
            if r.job == want and not pullerIdx then
                pullerIdx = i
            end
        end
    end

    roles[pullerIdx or 1].puller = true
    return roles
end

local function bracketOf(lvl)
    for _, b in ipairs({ 10, 20, 30, 40, 50, 60, 70, 75 }) do
        if lvl <= b then
            return b
        end
    end

    return 75
end

local function findCamp(zone, players)
    -- a random free monster far from you; the camp goes 15-28 yalms from it, on walkable ground
    local mobs = zone:getMobs()
    local candidates = {}
    for _, mob in ipairs(mobs) do
        if free(mob, players) then
            local pos = mob:getPos()
            if not nearAnyPlayer(pos, players, CAMP_SPACE + 20) then
                candidates[#candidates + 1] = mob
            end
        end
    end

    for _ = 1, 12 do
        if #candidates == 0 then
            return nil
        end

        local m = pick(candidates)
        local mp = m:getPos()
        for _ = 1, 8 do
            local a = math.random() * 2 * math.pi
            local r = 15 + math.random() * 13
            local camp = { x = mp.x + r * math.cos(a), y = mp.y, z = mp.z + r * math.sin(a) }
            if zone:isNavigablePoint(camp) and not nearAnyPlayer(camp, players, CAMP_SPACE) then
                local lvl = math.max(5, math.min(75, m:getMainLvl() - rnd(3, 6)))
                return camp, lvl
            end
        end
    end

    return nil
end

local onMemberDeath -- forward
local brain         -- forward

local function spawnMember(zone, party, r, idx)
    local race = env.pickWeighted({ [1] = 16, [2] = 14, [3] = 14, [4] = 10, [5] = 14, [6] = 12, [7] = 12, [8] = 8 })
    local name = env.makeName(race, party.usedNames)
    local a = (idx / 6) * 2 * math.pi
    local x, z = party.camp.x + 2.5 * math.cos(a), party.camp.z + 2.5 * math.sin(a)
    serial = serial + 1
    local mob = zone:insertDynamicEntity({
        objtype               = xi.objType.MOB,
        allegiance            = (xi.allegiance and xi.allegiance.PLAYER) or 1,
        name                  = 'FieldBot' .. serial,
        packetName            = name,
        x                     = x,
        y                     = party.camp.y,
        z                     = z,
        rotation              = rnd(0, 255),
        look                  = env.makeLook(race, rnd(0, 15), r.job, bracketOf(party.lvl)),
        groupId               = 1,
        groupZoneId           = xi.zone.GM_HOME,
        minLevel              = party.lvl,
        maxLevel              = party.lvl,
        releaseIdOnDisappear  = true,
        specialSpawnAnimation = true,
    })
    if mob == nil then
        return nil
    end

    mob:setSpawn(x, party.camp.y, z, 0)
    mob:setMobMod(xi.mobMod.NO_DROPS, 1)
    mob:setRoamFlags(xi.roamFlag.SCRIPTED)
    mob:spawn()
    DisallowRespawn(mob:getID(), true)
    mob:setAllegiance((xi.allegiance and xi.allegiance.PLAYER) or 1)
    mob:setBaseSpeed(50)
    mob:setMagicCastingEnabled(false) -- only the casts this file asks for
    mob:setMobAbilityEnabled(false)   -- only the weapon skills this file asks for
    mob:addMod(xi.mod.HPP, STRENGTH.hpp)
    mob:addMod(xi.mod.DEFP, STRENGTH.def)
    mob:addMod(xi.mod.ACC, STRENGTH.acc)
    mob:addMod(xi.mod.ATTP, STRENGTH.att)
    local caster = ({ WHM = 6, RDM = 5, BLM = 6, BRD = 3, PLD = 2, NIN = 0 })[r.job]
    if caster and caster > 0 then
        mob:addMod(xi.mod.MP, party.lvl * caster + 20)
    end

    mob:updateHealth()
    mob:setHP(mob:getMaxHP())
    if mob:getMaxMP() > 0 then
        mob:setMP(mob:getMaxMP())
    end

    local m = { id = mob:getID(), name = name, job = r.job, role = r.role, puller = r.puller, lvl = party.lvl }
    mob:addListener('DEATH', 'CROWD_FIELD_DEATH', function(dead)
        onMemberDeath(party, m)
    end)
    return m
end

local function newParty(zone, players)
    local camp, lvl = findCamp(zone, players)
    if not camp then
        return nil
    end

    local party = { zoneId = zone:getID(), camp = camp, lvl = lvl, members = {}, state = 'rest', usedNames = {},
        adds = {}, voke = 0, flash = 0, utsu = 0, songs = 0, debuffed = {}, healBusy = 0, supBusy = 0, nukeBusy = 0,
        restLine = 0, kills = 0, started = now() }
    for i, r in ipairs(composition(lvl)) do
        local m = spawnMember(zone, party, r, i)
        if m then
            party.members[#party.members + 1] = m
        end
    end

    if #party.members < 3 then
        for _, m in ipairs(party.members) do
            DespawnMob(m.id)
        end

        return nil
    end

    party.leader = party.members[1]
    local e = GetMobByID(party.leader.id)
    e:timer(4000, function(n)
        brain(party)
    end)
    return party
end

local function aliveMembers(party)
    local out = {}
    for _, m in ipairs(party.members) do
        if not m.dead and memberEntity(m) then
            out[#out + 1] = m
        end
    end

    return out
end

local function byRole(party, role)
    for _, m in ipairs(party.members) do
        if not m.dead and m.role == role and memberEntity(m) then
            return m
        end
    end

    return nil
end

local function puller(party)
    for _, m in ipairs(party.members) do
        if m.puller and not m.dead and memberEntity(m) then
            return m
        end
    end

    return byRole(party, 'tank') or aliveMembers(party)[1]
end

local function endParty(party, reason)
    if party.over then
        return
    end

    party.over = true
    local zp = parties[party.zoneId]
    if zp then
        for i, p in ipairs(zp.list) do
            if p == party then
                table.remove(zp.list, i)
                break
            end
        end

        zp.nextAt = now() + rnd(NEW_PARTY_WAIT[1], NEW_PARTY_WAIT[2])
    end

    for _, m in ipairs(party.members) do
        local e = GetMobByID(m.id)
        if e and not m.dead then
            if reason == 'wipe' then
                say(party, m, pick({ 'ugh... warping out', 'HP time...', 'wipe lol', 'gg, im out' }))
            end

            pcall(function() e:entityAnimationPacket(xi.animationString.STATUS_DISAPPEAR) end)
            e:timer(1500, function(n)
                DespawnMob(n:getID())
            end)
        end
    end
end

onMemberDeath = function(party, m)
    if m.dead then
        return
    end

    m.dead = true
    local others = aliveMembers(party)
    if #others > 0 and math.random() < 0.6 then
        say(party, pick(others), pick({ m.name .. '!', 'oh no ' .. m.name, 'raise ' .. m.name .. '?', 'nooo' }))
    end

    -- the brain runs on one member; if that one fell, hand it on
    if party.leader == m and #others > 0 then
        party.leader = others[1]
        local e = memberEntity(party.leader)
        if e then
            e:timer(BRAIN_FIGHT, function()
                brain(party)
            end)
        end
    end

    local tank, healer = byRole(party, 'tank'), byRole(party, 'healer')
    if #others < 2 or (not tank and not healer) then
        endParty(party, 'wipe')
    end
end

-----------------------------------
-- fighting
-----------------------------------
local function cast(party, m, spellId, target, line)
    local e = memberEntity(m)
    if not e or not spellId or not target then
        return false
    end

    e:castSpell(spellId, target)
    if line then
        say(party, m, line)
    end

    return true
end

local function hpp(e)
    local ok, v = pcall(function() return e:getHPP() end)
    return ok and v or 100
end

local function mpp(e)
    local ok, mp, max = pcall(function() return e:getMP(), e:getMaxMP() end)
    if not ok or not max or max <= 0 then
        return 100
    end

    return math.floor(mp * 100 / max)
end

local function startFight(party, target)
    party.target = target
    party.targetId = target:getID()
    party.state = 'fight'
    party.fightStart = now()
    party.sc = nil
    party.debuffed = {}
    local tank = byRole(party, 'tank') or puller(party)
    local te = tank and memberEntity(tank)
    if te then
        target:addEnmity(te, 1800, 1800)   -- Provoke / first hate
        te:addEnmity(target, 1, 1)
        say(party, tank, pick({ 'Provoke >> ' .. prettyName(target), '<< Provoke >> ' .. prettyName(target), 'voke' }))
        party.voke = now()
    end

    -- melee join once the tank holds it
    te = te or memberEntity(aliveMembers(party)[1])
    if te then
        te:timer(2500, function()
            if party.over or party.targetId ~= target:getID() or not alive(target) then
                return
            end

            for _, m in ipairs(party.members) do
                local e = memberEntity(m)
                if e and (m.role == 'dd' or m.role == 'tank' or (m.role == 'support' and m.job ~= 'BRD' and party.lvl < 30)) then
                    e:addEnmity(target, 1, 1)
                end
            end
        end)
    end
end

local function healerTurn(party, healer)
    local he = memberEntity(healer)
    if not he or now() < party.healBusy then
        return
    end

    local worst, worstHpp
    for _, m in ipairs(party.members) do
        local e = memberEntity(m)
        if e then
            local h = hpp(e)
            local limit = m.role == 'tank' and 75 or 60
            if h <= limit and (not worstHpp or h < worstHpp) then
                worst, worstHpp = m, h
            end
        end
    end

    if worst then
        local id, name = spellFor(healer.job, party.lvl, worstHpp < 40 and { 'cure_iv', 'cure_iii', 'cure_ii', 'cure' } or { 'cure_iii', 'cure_ii', 'cure' })
        if id and cast(party, healer, id, memberEntity(worst), math.random() < 0.5 and (spellName(name) .. ' >> ' .. worst.name) or nil) then
            party.healBusy = now() + 4
            return true
        end
    end

    -- Dia / Paralyze / Slow on the monster early in the fight (WHM does Dia, the support the rest)
    local target = party.target
    if target and alive(target) and not party.debuffed.dia then
        local id = spellFor(healer.job, party.lvl, { 'dia_ii', 'dia' })
        if id then
            party.debuffed.dia = true
            cast(party, healer, id, target)
            party.healBusy = now() + 3
            return true
        end
    end

    return false
end

local function supportTurn(party, sup)
    local se = memberEntity(sup)
    if not se or now() < party.supBusy then
        return
    end

    local target = party.target
    if sup.job == 'BRD' then
        if now() - party.songs > 120 then
            party.songs = now()
            local id, name = spellFor('BRD', party.lvl, { 'valor_minuet_iv', 'valor_minuet_iii', 'valor_minuet_ii', 'valor_minuet' })
            if id then
                cast(party, sup, id, se, spellName(name))
                party.supBusy = now() + 4
                return
            end
        end

        if now() - party.songs > 8 and not party.ballad then
            party.ballad = true
            local id, name = spellFor('BRD', party.lvl, { 'mages_ballad_ii', 'mages_ballad' })
            if id then
                cast(party, sup, id, se, spellName(name))
                party.supBusy = now() + 4
                return
            end
        end
    else -- RDM
        local healer = byRole(party, 'healer')
        local he = healer and memberEntity(healer)
        if he and mpp(he) < 70 and now() - (party.refresh or 0) > 150 then
            local id = spellFor('RDM', party.lvl, { 'refresh' })
            if id then
                party.refresh = now()
                cast(party, sup, id, he, 'Refresh >> ' .. healer.name)
                party.supBusy = now() + 4
                return
            end
        end

        local tank = byRole(party, 'tank')
        local te = tank and memberEntity(tank)
        if te and now() - (party.haste or 0) > 180 then
            local id = spellFor('RDM', party.lvl, { 'haste' })
            if id then
                party.haste = now()
                cast(party, sup, id, te, 'Haste >> ' .. tank.name)
                party.supBusy = now() + 4
                return
            end
        end

        if hpp(se) > 0 then
            -- off-heal when the healer is busy or gone
            for _, m in ipairs(party.members) do
                local e = memberEntity(m)
                if e and hpp(e) < 45 then
                    local id = spellFor('RDM', party.lvl, { 'cure_iv', 'cure_iii', 'cure_ii', 'cure' })
                    if id then
                        cast(party, sup, id, e)
                        party.supBusy = now() + 4
                        return
                    end
                end
            end
        end
    end

    if target and alive(target) then
        for _, debuff in ipairs({ 'slow', 'paralyze' }) do
            if not party.debuffed[debuff] then
                local id = spellFor(sup.job, party.lvl, { debuff })
                party.debuffed[debuff] = true
                if id then
                    cast(party, sup, id, target)
                    party.supBusy = now() + 4
                    return
                end
            end
        end
    end
end

local function tankTurn(party, tank)
    local te = memberEntity(tank)
    local target = party.target
    if not te or not target or not alive(target) then
        return
    end

    if now() - party.voke >= 30 then
        party.voke = now()
        target:addEnmity(te, 900, 0)
        if math.random() < 0.4 then
            say(party, tank, 'Provoke >> ' .. prettyName(target))
        end
    end

    if tank.job == 'PLD' and now() - party.flash >= 45 then
        local id = spellFor('PLD', party.lvl, { 'flash' })
        if id then
            party.flash = now()
            cast(party, tank, id, target)
        end
    elseif tank.job == 'NIN' and now() - party.utsu >= 60 then
        local id = spellFor('NIN', party.lvl, { 'utsusemi_ni', 'utsusemi_ichi' })
        if id then
            party.utsu = now()
            cast(party, tank, id, te)
        end
    end
end

local function closingWs(list, props)
    -- the highest weapon skill in list that chains after an opener with these properties
    for i = #list, 1, -1 do
        local w = list[i]
        for _, open in ipairs(props) do
            for _, close in ipairs(w[4]) do
                local result = SC_COMBOS[open] and SC_COMBOS[open][close]
                if result then
                    return w, result
                end
            end
        end
    end

    return nil
end

local function ddTurn(party)
    local target = party.target
    if not target or not alive(target) then
        return
    end

    local t = now()
    if party.sc and t - party.sc.at > 8 then
        party.sc = nil -- the window closed
    end

    local melee = {}
    for _, m in ipairs(party.members) do
        local e = memberEntity(m)
        if e and (m.role == 'dd' or m.role == 'tank') then
            melee[#melee + 1] = { m = m, e = e, list = wsList(m.job, party.lvl), tp = e:getTP() }
        end
    end

    -- close an open skillchain (3+ s after the opener, like players waiting for the window)
    if party.sc then
        if t - party.sc.at < 3 then
            return
        end

        for _, c in ipairs(melee) do
            if c.m ~= party.sc.by and c.tp >= 1000 and #c.list > 0 then
                local w, result = closingWs(c.list, party.sc.props)
                if w then
                    c.e:useMobAbility(w[2], target)
                    c.e:setTP(0)
                    c.m.lastWs = t
                    party.sc = nil
                    say(party, c.m, w[3] .. ' -> ' .. result:gsub('^%l', string.upper) .. '!')
                    party.burst = { element = MB_ELEMENT[result], at = t }
                    return
                end
            end
        end

        return
    end

    -- open: wait until a partner is about ready, then open with a weapon skill they can close
    for _, o in ipairs(melee) do
        if o.tp >= 1000 and #o.list > 0 and t - (o.m.lastWs or 0) > 6 then
            for _, c in ipairs(melee) do
                if c ~= o and c.tp >= 700 and #c.list > 0 then
                    for i = #o.list, 1, -1 do
                        local w = o.list[i]
                        if closingWs(c.list, w[4]) then
                            o.e:useMobAbility(w[2], target)
                            o.e:setTP(0)
                            o.m.lastWs = t
                            party.sc = { props = w[4], at = t, by = o.m }
                            say(party, o.m, w[3] .. ' -> SC open, ' .. c.m.name .. ' close')
                            return
                        end
                    end
                end
            end

            -- no chain possible (or nobody ready): a weapon skill on its own when TP is high, to keep up the damage
            if o.tp >= 1500 or (o.m.role == 'dd' and #melee == 1) then
                local w = o.list[#o.list]
                o.e:useMobAbility(w[2], target)
                o.e:setTP(0)
                o.m.lastWs = t
                return
            end
        end
    end
end

local function nukerTurn(party, nuker)
    local ne = memberEntity(nuker)
    local target = party.target
    if not ne or not target or not alive(target) or now() < party.nukeBusy then
        return
    end

    if party.burst and now() - party.burst.at <= 6 and party.burst.element then
        local e = party.burst.element
        party.burst = nil
        local id, name = spellFor(nuker.job, party.lvl, { e .. '_iv', e .. '_iii', e .. '_ii', e })
        if id then
            cast(party, nuker, id, target, 'MB ' .. spellName(name) .. '!')
            party.nukeBusy = now() + 5
            return
        end
    end

    -- a free nuke late in the fight when MP allows (not too early: it would pull hate)
    if hpp(target) < 50 and mpp(ne) > 60 and now() - (party.freeNuke or 0) > 20 then
        local e = pick({ 'stone', 'water', 'aero', 'fire', 'blizzard', 'thunder' })
        local id = spellFor(nuker.job, party.lvl, { e .. '_iii', e .. '_ii', e })
        if id then
            party.freeNuke = now()
            cast(party, nuker, id, target)
            party.nukeBusy = now() + 5
        end
    end
end

local function checkAdds(party, zone)
    if now() - (party.addCheck or 0) < 3 then
        return
    end

    party.addCheck = now()
    local ids = {}
    for _, m in ipairs(party.members) do
        if not m.dead then
            ids[m.id] = true
        end
    end

    for _, mob in ipairs(zone:getMobs()) do
        if isEnemy(mob) and alive(mob) and mob:getID() ~= party.targetId and not party.adds[mob:getID()] then
            local ok, tgt = pcall(function() return mob:getTarget() end)
            if ok and tgt and ids[tgt:getID()] then
                party.adds[mob:getID()] = true
                local sleeper
                for _, m in ipairs(party.members) do
                    if not m.dead and (m.job == 'BLM' or m.job == 'RDM' or m.job == 'BRD') and memberEntity(m) then
                        sleeper = m
                        break
                    end
                end

                local spoke = false
                if sleeper then
                    local id, name = spellFor(sleeper.job, party.lvl, sleeper.job == 'BRD' and { 'foe_lullaby' } or { 'sleep_ii', 'sleep' })
                    if id then
                        cast(party, sleeper, id, mob, spellName(name) .. ' >> ' .. prettyName(mob))
                        spoke = true
                    end
                end

                if not spoke then
                    say(party, aliveMembers(party)[1], 'add!')
                end
            end
        end
    end
end

local function nextTarget(party)
    for id in pairs(party.adds) do
        party.adds[id] = nil
        local mob = GetMobByID(id)
        if mob and alive(mob) then
            return mob
        end
    end

    return nil
end

local function restTick(party)
    local need = false
    for _, m in ipairs(party.members) do
        local e = memberEntity(m)
        if e then
            local h, mp = hpp(e), mpp(e)
            local mine = false
            if h < 95 then
                e:setHP(math.min(e:getMaxHP(), e:getHP() + math.floor(e:getMaxHP() * REST_TICK_HPP / 100)))
                mine = h < 85
            end

            if e:getMaxMP() > 0 and mp < 95 then
                e:setMP(math.min(e:getMaxMP(), e:getMP() + math.floor(e:getMaxMP() * REST_TICK_MPP / 100)))
                mine = mine or (mp < 70 and (m.role == 'healer' or m.role == 'nuker' or m.role == 'support'))
            end

            need = need or mine
            if mine ~= m.resting then
                m.resting = mine
                pcall(function() e:setAnimation(mine and 33 or 0) end) -- /heal while low
            end
        end
    end

    return need
end

local function choosePull(party, zone)
    -- you standing at (or next to) their camp to watch does not stop them pulling their own monsters
    local players = {}
    for _, pp in ipairs(playersOf(zone)) do
        if d2(pp, party.camp) > 30 * 30 then
            players[#players + 1] = pp
        end
    end

    local best, bestD
    for _, mob in ipairs(zone:getMobs()) do
        if free(mob, players) then
            local lv = mob:getMainLvl()
            local pos = mob:getPos()
            local dd = d2(pos, party.camp)
            local bad = party.badPull and party.badPull[mob:getID()]
            if lv >= party.lvl + 1 and lv <= party.lvl + 8 and dd <= PULL_RANGE * PULL_RANGE and dd > 36
                and not (bad and now() - bad < 600)
                and (not bestD or dd < bestD) and math.random() < 0.8 then
                -- not a monster another party camps on
                local taken = false
                for _, other in ipairs((parties[party.zoneId] or { list = {} }).list) do
                    if other ~= party and (other.targetId == mob:getID() or other.pullingId == mob:getID()) then
                        taken = true
                    end
                end

                if not taken then
                    best, bestD = mob, dd
                end
            end
        end
    end

    return best
end

brain = function(party)
    if party.over then
        return
    end

    local leaderE = memberEntity(party.leader)
    if not leaderE then
        local others = aliveMembers(party)
        if #others == 0 then
            endParty(party, 'gone')
            return
        end

        party.leader = others[1]
        leaderE = memberEntity(party.leader)
    end

    local zone = GetZone(party.zoneId)
    local zp = parties[party.zoneId]
    if not zone or not zp then
        endParty(party, 'gone')
        return
    end

    local wait = BRAIN_FIGHT
    if #realPlayers(zone) == 0 then
        zp.emptySince = zp.emptySince or now()
        if now() - zp.emptySince >= EMPTY_DESPAWN then
            endParty(party, 'empty')
            return
        end

        leaderE:timer(20000, function() brain(party) end)
        return
    end

    zp.emptySince = nil
    if not env.cfg.field or not env.cfg.enabled then
        endParty(party, 'off')
        return
    end

    if party.state == 'rest' then
        wait = BRAIN_IDLE
        local need = restTick(party)
        if need then
            if now() - party.restLine > 90 and math.random() < 0.5 then
                party.restLine = now()
                local healer = byRole(party, 'healer') or aliveMembers(party)[1]
                say(party, healer, pick({ 'resting', 'mp', 'need to rest, sec', 'MP ' .. rnd(20, 45) .. '%', 'resting for mp' }))
            end
        elseif now() >= (party.nextPullAt or 0) then
            local target = choosePull(party, zone)
            local p = puller(party)
            local pe = p and memberEntity(p)
            if target and pe then
                party.idleSince = nil
                pe:setAnimation(0)
                p.resting = false
                party.state = 'pull'
                party.pulled = nil
                party.pullingId = target:getID()
                party.pullStart = now()
                party.pullerM = p
                pe:setAnimation(0)
                local tp = target:getPos()
                pe:pathTo(tp.x, tp.y, tp.z)
                say(party, p, pick({ 'Pulling >> ' .. prettyName(target), 'pulling', 'pulling ' .. prettyName(target), '>> ' .. prettyName(target) }))
            else
                party.nextPullAt = now() + 10 -- nothing free right now (respawns)
                party.idleSince = party.idleSince or now()
                if now() - party.idleSince > 180 then
                    -- nothing left here: move camp, like a party would
                    local camp = findCamp(zone, playersOf(zone))
                    if camp then
                        party.camp = camp
                        party.idleSince = nil
                        say(party, aliveMembers(party)[1], pick({ 'moving camp', 'no pop here, moving', 'lets move' }))
                        for i, m in ipairs(aliveMembers(party)) do
                            local e = memberEntity(m)
                            local a = (i / 6) * 2 * math.pi
                            e:setAnimation(0)
                            m.resting = false
                            e:pathTo(camp.x + 2.5 * math.cos(a), camp.y, camp.z + 2.5 * math.sin(a))
                        end
                    end
                end
            end
        end
    elseif party.state == 'pull' then
        local target = GetMobByID(party.pullingId or 0)
        local p = party.pullerM
        local pe = p and memberEntity(p)
        if not target or not alive(target) or not pe or now() - party.pullStart > 45 then
            party.state = 'rest'
            party.pullingId = nil
            party.pulled = nil
            if target and alive(target) and party.pulled == nil and pe and now() - party.pullStart > 45 then
                party.badPull = party.badPull or {}
                party.badPull[target:getID()] = now() -- could not get it (out of reach): leave it alone for a while
            end
            if pe then
                pe:pathTo(party.camp.x, party.camp.y, party.camp.z)
            end
        elseif not party.pulled then
            local tp, pp = target:getPos(), pe:getPos()
            if d2(tp, pp) <= 15 * 15 then
                party.pulled = true
                target:addEnmity(pe, 1, 1) -- (a ranged attack / Provoke from the puller)
                pe:clearPath()
                pe:pathTo(party.camp.x, party.camp.y, party.camp.z)
            elseif not free(target, playersOf(zone)) then
                party.state = 'rest' -- someone else got it, or it wandered near you
                party.pullingId = nil
                pe:pathTo(party.camp.x, party.camp.y, party.camp.z)
            end
        else
            local tp = target:getPos()
            if d2(tp, party.camp) <= 12 * 12 or d2(pe:getPos(), party.camp) <= 4 * 4 then
                party.pulled = nil
                party.pullingId = nil
                say(party, p, pick({ 'inc', 'inc!', '<< inc >>', 'incoming' }))
                startFight(party, target)
            end
        end
    elseif party.state == 'fight' then
        local target = party.target
        if not alive(target) then
            party.kills = party.kills + 1
            local nxt = nextTarget(party)
            if nxt then
                startFight(party, nxt)
            else
                party.state = 'rest'
                party.target, party.targetId = nil, nil
                party.nextPullAt = now() + rnd(3, 10)
                if math.random() < 0.3 then
                    say(party, pick(aliveMembers(party)), pick({ 'gj', 'nice', 'ty', 'next', 'k next' }))
                end

                -- walk back to camp positions
                for i, m in ipairs(aliveMembers(party)) do
                    local e = memberEntity(m)
                    local a = (i / 6) * 2 * math.pi
                    e:pathTo(party.camp.x + 2.5 * math.cos(a), party.camp.y, party.camp.z + 2.5 * math.sin(a))
                end
            end
        else
            checkAdds(party, zone)
            local healer = byRole(party, 'healer')
            if healer then
                healerTurn(party, healer)
            end

            local sup = byRole(party, 'support')
            if sup then
                supportTurn(party, sup)
            end

            local tank = byRole(party, 'tank')
            if tank then
                tankTurn(party, tank)
            end

            ddTurn(party)
            local nuker = byRole(party, 'nuker')
            if nuker then
                nukerTurn(party, nuker)
            end

            if now() - party.fightStart > 240 then
                -- a fight that never ends (the monster ran home): give it up
                party.state = 'rest'
                party.target, party.targetId = nil, nil
            end
        end
    end

    leaderE = memberEntity(party.leader)
    if leaderE then
        leaderE:timer(wait, function() brain(party) end)
    end
end

-----------------------------------
-- hooks for crowds.lua
-----------------------------------
function F.setup(e)
    env = e
end

function F.isFieldZone(zoneId)
    return env and env.data.field and env.data.field[zoneId] ~= nil
end

-- Called a few seconds after you arrive in an area
function F.ensure(zone, force)
    if not env.cfg.field or not zone then
        return 0
    end

    local zoneId = zone:getID()
    if not F.isFieldZone(zoneId) then
        return 0
    end

    local zp = parties[zoneId]
    if not zp then
        zp = { list = {}, nextAt = 0 }
        parties[zoneId] = zp
    end

    if #realPlayers(zone) > 0 then
        zp.emptySince = nil
    end

    local made = 0
    local want = math.max(0, math.min(3, env.cfg.fieldParties or 1))
    while #zp.list < want and (force or now() >= zp.nextAt) do
        local party = newParty(zone, playersOf(zone))
        if not party then
            zp.nextAt = now() + 60 -- no good camp right now (you may be standing near all of it)
            break
        end

        table.insert(zp.list, party)
        made = made + 1
        force = false
    end

    return made
end

-- Parties that are waiting to be made after one ended come when you next zone in, or from this check
function F.tickZone(zone)
    F.ensure(zone)
end

function F.removeAll(zoneId)
    local n = 0
    for id, zp in pairs(parties) do
        if zoneId == nil or id == zoneId then
            for _, party in ipairs({ unpack(zp.list) }) do
                endParty(party, 'off')
                n = n + 1
            end
        end
    end

    return n
end

function F.status(zoneId)
    local zp = parties[zoneId]
    if not F.isFieldZone(zoneId) then
        return 'no field parties in this area'
    end

    if not zp or #zp.list == 0 then
        return 'no party here right now' .. ((zp and zp.nextAt > now()) and string.format(' (next in about %d min)', math.ceil((zp.nextAt - now()) / 60)) or '')
    end

    local parts = {}
    for _, p in ipairs(zp.list) do
        local jobs = {}
        for _, m in ipairs(p.members) do
            jobs[#jobs + 1] = (m.dead and 'x' or '') .. m.job
        end

        parts[#parts + 1] = string.format('lvl %d %s, %s, %d kills', p.lvl, table.concat(jobs, '/'), p.state, p.kills)
    end

    return table.concat(parts, ' | ')
end

function F.resetWait()
    for _, zp in pairs(parties) do
        zp.nextAt = 0
    end
end

F.parties = parties -- (for the stand-in tests)
return F
