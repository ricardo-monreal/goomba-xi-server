-----------------------------------
-- Ambient crowds (FFXI Offline): adventurers who look like real players, so the towns and outposts feel less empty.
-- Areas: every era town (smaller towns get 60% of the crowd size) and the 17 conquest outposts (25%).
--
-- They are server-made NPCs (zone:insertDynamicEntity) with a full player look: race, face and era gear for
-- their job and level (crowds_data.lua, made by C:\FFXISOLO\build_crowds_data.py from the server's own item
-- tables, npcs.yaml and navmesh). They rest by the Home Points, browse the Auction House, stand around the shops
-- and walk between them, and now and then emote. Purely visual: they do not fight, trade or talk (yet).
--
--   * A crowd appears the first time you enter one of its areas and is removed 5 minutes after the area is empty.
--   * Every so often one of them "zones out" and someone new arrives by the Home Point.
--   * Switch and size: launcher, CONFIG > Rates ("Ambient crowds", "Crowd size"), written to crowds_config.lua.
--   * Commands (any character on this server): !crowd   status in this area
--         !crowd on|off     switch on/off now (until the next PLAY)
--         !crowd count N    crowd size now (0-40, until the next PLAY)
--         !crowd reload     re-read the settings and your marked spots, rebuild this area's crowd
--         !crowd mark rest|ah|idle   add a spot where you stand (saved in crowds_spots_user.lua)
--         !crowd unmark     remove your marked spot nearest to you (within 3 yalms)
--         !crowd chat on|off|quiet|normal|busy|aion|aioff|test   shouts and say chatter (crowds_chat.lua)
--         !crowd field on|off|test                               field parties camping and fighting (crowds_field.lua)
-----------------------------------
require('modules/module_utils')
-----------------------------------
local m = Module:new('crowds')

local DATA_PATH   = 'modules/goomba/lua/crowds_data'
local CONFIG_PATH = 'modules/goomba/lua/crowds_config'
local USER_SPOTS  = 'modules/goomba/lua/crowds_spots_user.lua'

local HARD_CAP       = 40       -- never more than this per area (dynamic entity ids are shared with squad mates, pets, caskets)
local EMPTY_DESPAWN  = 5 * 60   -- seconds an area must be empty before its crowd is removed
local THINK_MIN      = 8000     -- ms between two decisions of one bot
local THINK_MAX      = 25000
local WALK_CHECK     = 3000     -- ms between checks while a bot is walking
local NEAR_PLAYER    = 5        -- yalms: a bot this close may notice you

local ANIM_NONE, ANIM_HEALING, ANIM_SIT = 0, 33, 47

xi.crowds = xi.crowds or {}
xi.crowds.realPlayers = function(zone)
    local out = {}
    for _, p in ipairs(zone:getPlayers()) do
        if not (BotIsBot and BotIsBot(p:getID())) then
            out[#out + 1] = p
        end
    end

    return out
end

local chatOk, chat = pcall(require, 'modules/goomba/lua/crowds_chat')
if not chatOk or type(chat) ~= 'table' then
    print('[crowds] chat is off: crowds_chat.lua could not be loaded: ' .. tostring(chat))
    chat = nil
end

local fieldOk, field = pcall(require, 'modules/goomba/lua/crowds_field')
if not fieldOk or type(field) ~= 'table' then
    print('[crowds] field parties are off: crowds_field.lua could not be loaded: ' .. tostring(field))
    field = nil
end

local ok, data = pcall(require, DATA_PATH)
if not ok or type(data) ~= 'table' then
    print('[crowds] crowds_data.lua could not be loaded: ' .. tostring(data))
    data = { jobs = {}, outfits = {}, zones = {} }
end

local cfg = {}
local userSpots = {}               -- [zone id] = { { kind, x, y, z, rot }, ... }
local crowds = {}                  -- [zone id] = { bots = { [npc id] = bot }, emptySince = os.time() or nil, usedNames = {} }
local serial = 0                   -- makes internal names unique

-----------------------------------
-- Settings
-----------------------------------
local function loadConfig()
    package.loaded[CONFIG_PATH] = nil
    local okc, c = pcall(require, CONFIG_PATH)
    if not okc or type(c) ~= 'table' then
        c = {}
    end

    cfg.enabled        = c.enabled ~= false
    cfg.perZone        = math.max(0, math.min(HARD_CAP, math.floor(tonumber(c.per_zone) or 30)))
    cfg.emoteText      = c.emote_text == true            -- emotes also print a line in chat ("X waves.")
    cfg.turnover       = tonumber(c.turnover) or 0.012   -- chance per decision that a bot leaves and someone new arrives
    cfg.entityFlags    = tonumber(c.entity_flags) or 27  -- same flags as the player-looking NPCs in npcs.yaml
    cfg.chat           = c.chat ~= false                 -- shouts and say chatter (phase 2)
    cfg.chatAmount     = (c.chat_amount == 'quiet' or c.chat_amount == 'busy') and c.chat_amount or 'normal'
    cfg.chatAi         = c.chat_ai ~= false              -- mix in AI-written small talk (crowds_chat_ai.lua) when there is some
    cfg.field          = c.field ~= false                -- field parties (phase 3)
    cfg.fieldParties   = math.max(0, math.min(3, math.floor(tonumber(c.field_parties) or 1)))
    cfg.disabledZones  = {}
    for _, zoneId in ipairs(c.disabled_zones or {}) do
        cfg.disabledZones[zoneId] = true
    end
end

local function loadUserSpots()
    userSpots = {}
    local chunk = loadfile(USER_SPOTS)
    if chunk then
        local okc, t = pcall(chunk)
        if okc and type(t) == 'table' then
            userSpots = t
        end
    end
end

local function saveUserSpots()
    local f = io.open(USER_SPOTS, 'w')
    if not f then
        return false
    end

    f:write('-- Spots marked in game with !crowd mark. Read by crowds.lua. You can delete lines (or the whole file).\n')
    f:write('return {\n')
    for zoneId, list in pairs(userSpots) do
        f:write(string.format('    [%d] = {\n', zoneId))
        for _, s in ipairs(list) do
            f:write(string.format("        { kind = '%s', x = %.3f, y = %.3f, z = %.3f, rot = %d },\n", s.kind, s.x, s.y, s.z, s.rot))
        end
        f:write('    },\n')
    end
    f:write('}\n')
    f:close()
    return true
end

loadConfig()
loadUserSpots()

-----------------------------------
-- Helpers
-----------------------------------
local function rnd(a, b)
    return math.random(a, b)
end

local function chance(p)
    return math.random() < p
end

local function pickWeighted(weights)
    local total = 0
    for _, w in pairs(weights) do
        total = total + w
    end

    local roll = math.random() * total
    local last
    for key, w in pairs(weights) do
        last = key
        roll = roll - w
        if roll <= 0 then
            return key
        end
    end

    return last
end

local function dist2(ax, az, bx, bz)
    return (ax - bx) * (ax - bx) + (az - bz) * (az - bz)
end

local function channel()
    return (xi.msg and xi.msg.channel and xi.msg.channel.SYSTEM_3) or 0
end

local function tell(player, text)
    player:printToPlayer('[Crowd] ' .. text, channel())
end

-- Player-like names, flavoured by race (letters only, 3-15 characters)
local NAME_PARTS =
{
    hume   = { { 'Al', 'Bran', 'Cas', 'Dor', 'Ed', 'Fen', 'Gar', 'Hal', 'Jor', 'Kel', 'Lor', 'Mar', 'Nor', 'Os', 'Per', 'Ral', 'Sev', 'Tor', 'Val', 'Wil', 'Ari', 'Bel', 'Cyr', 'Dan' },
               { 'an', 'en', 'in', 'ius', 'or', 'ik', 'as', 'ric', 'ton', 'ley', 'ard', 'wyn', 'a', 'ia', 'ette', 'el' } },
    elvaan = { { 'Aure', 'Celes', 'Fere', 'Rau', 'Vala', 'Ghis', 'Mira', 'Thal', 'Euge', 'Ande', 'Lisa', 'Bene', 'Clau', 'Pier' },
               { 'lien', 'mont', 'rine', 'ault', 'oix', 'aine', 'bert', 'deau', 'lois', 'gard', 'ette', 'mand' } },
    taru   = { { 'Pa', 'Ku', 'Mi', 'To', 'Ra', 'Shi', 'Ya', 'Po', 'Ki', 'Na', 'Ta', 'Chu', 'Ma', 'Pu' },
               { 'ta', 'pi', 'mi', 'to', 'ra', 'ko', 'po', 'ri', 'ya', 'nu' } },
    mithra = { { 'Mi', 'Nya', 'Shi', 'La', 'Ra', 'Sa', 'Fu', 'Ka', 'Ze', 'Yo' },
               { 'na', 'ri', 'sha', 'ya', 'lia', 'ko', 'mya', 'ra', 'nell', 'tri' } },
    galka  = { { 'Grun', 'Thor', 'Brak', 'Durg', 'Mog', 'Kar', 'Hrok', 'Volg', 'Zun', 'Bor' },
               { 'ok', 'an', 'ur', 'ath', 'ag', 'om', 'ek', 'ul', 'ar', 'ug' } },
}
local RACE_STYLE = { 'hume', 'hume', 'elvaan', 'elvaan', 'taru', 'taru', 'mithra', 'galka' }
local RACE_WEIGHT = { [1] = 16, [2] = 14, [3] = 14, [4] = 10, [5] = 14, [6] = 12, [7] = 12, [8] = 8 }

local function makeName(race, used)
    local parts = NAME_PARTS[RACE_STYLE[race]]
    for _ = 1, 20 do
        local name
        if RACE_STYLE[race] == 'taru' then
            local a, b = parts[1][rnd(1, #parts[1])], parts[2][rnd(1, #parts[2])]
            name = chance(0.5) and (a .. string.lower(a) .. b) or (a .. b .. string.lower(b))
        else
            name = parts[1][rnd(1, #parts[1])] .. parts[2][rnd(1, #parts[2])]
            local extra = parts[2][rnd(1, #parts[2])]
            if chance(0.25) and not name:find(extra, 1, true) then
                name = name .. extra
            end
        end

        name = string.sub(name, 1, 15)
        if #name >= 3 and not used[name] then
            used[name] = true
            return name
        end
    end

    serial = serial + 1
    return 'Adventurer' .. serial
end

local BASE_JOBS = { 'WAR', 'MNK', 'WHM', 'BLM', 'RDM', 'THF' }
local EXTRA_JOBS = { 'PLD', 'DRK', 'BST', 'BRD', 'RNG', 'SAM', 'NIN', 'DRG', 'SMN' }
local TOAU_JOBS = { 'BLU', 'COR', 'PUP' }

local function pickJob(level)
    if level < 30 then
        return BASE_JOBS[rnd(1, #BASE_JOBS)]
    end

    local roll = math.random()
    if roll < 0.40 then
        return BASE_JOBS[rnd(1, #BASE_JOBS)]
    elseif roll < 0.88 then
        return EXTRA_JOBS[rnd(1, #EXTRA_JOBS)]
    end

    return TOAU_JOBS[rnd(1, #TOAU_JOBS)]
end

-- A full 40-digit look string: size (equipped), face, race, then 8 gear slots
local function makeLook(race, face, job, bracket)
    local byJob = data.outfits[job] or {}
    local list = byJob[bracket]
    local gearHex = (list and #list > 0) and list[rnd(1, #list)] or string.rep('0', 32)
    return string.format('0x0100%02X%02X', face, race) .. gearHex
end

local function zoneSpots(zoneId)
    local zd = data.zones[zoneId]
    local list = {}
    for _, s in ipairs(zd and zd.spots or {}) do
        list[#list + 1] = { kind = s.kind, x = s.x, y = s.y, z = s.z, rot = s.rot }
    end

    for _, s in ipairs(userSpots[zoneId] or {}) do
        list[#list + 1] = { kind = s.kind, x = s.x, y = s.y, z = s.z, rot = s.rot, user = true }
    end

    return list
end

-- How many in this area: the crowd size x the area's share (smaller towns 60%, outposts 25%)
local function targetFor(zoneId)
    local zd = data.zones[zoneId]
    if not zd or cfg.perZone <= 0 then
        return 0
    end

    local n = math.max(1, math.min(HARD_CAP, math.floor(cfg.perZone * (zd.scale or 1) + 0.5)))
    -- bot players living here (bots.lua) take some of the places
    if xi.bots and xi.bots.countInZone then
        local ok, bots = pcall(xi.bots.countInZone, zoneId)
        if ok and type(bots) == 'number' and bots > 0 then
            n = math.max(0, n - bots)
        end
    end

    return n
end

local function crowdOf(zoneId)
    local crowd = crowds[zoneId]
    if not crowd then
        crowd = { bots = {}, count = 0, usedNames = {}, spots = zoneSpots(zoneId) }
        crowds[zoneId] = crowd
    end

    return crowd
end

local function freeSpots(crowd, kind)
    local out = {}
    for _, s in ipairs(crowd.spots) do
        if not s.taken and (kind == nil or s.kind == kind) then
            out[#out + 1] = s
        end
    end

    return out
end

local function takeSpot(bot, spot)
    if bot.spot then
        bot.spot.taken = nil
    end

    bot.spot = spot
    if spot then
        spot.taken = bot.serial
    end
end

-- for bots_life.lua: the same names, spots and small talk as the crowds
xi.crowds.makeName = function(race, used)
    return makeName(race, used or {})
end
xi.crowds.zoneSpots = zoneSpots
xi.crowds.botChatter = function(zoneId, speakers, players, speak)
    if chat and chat.onBotThink then
        chat.onBotThink(zoneId, speakers, players, speak)
    end
end
xi.crowds.sayLine = function(who, zoneId)
    if chat and cfg.chat and chat.sayLine then
        return chat.sayLine(who, zoneId)
    end
end

if chat then
    chat.setup({ cfg = cfg, data = data, makeName = makeName, dist2 = dist2 })
end

if field then
    field.setup({ cfg = cfg, data = data, makeName = makeName, makeLook = makeLook, dist2 = dist2, pickWeighted = pickWeighted })
end

-----------------------------------
-- Behaviour
-----------------------------------
local think -- forward

local function schedule(npc, bot, ms)
    npc:timer(ms or rnd(THINK_MIN, THINK_MAX), function(n)
        think(n, bot)
    end)
end

local function emote(npc, target, which)
    local mode = cfg.emoteText and xi.emoteMode.ALL or xi.emoteMode.MOTION
    npc:sendEmote(target or npc, which, mode, false)
end

local IDLE_EMOTES = { 'WAVE', 'LAUGH', 'THINK', 'YES', 'NO', 'BOW', 'CHEER', 'CLAP', 'SMILE', 'DOUBT', 'HUH', 'SIGH', 'STRETCH', 'GRIN', 'JOY' }

local function randomEmote()
    for _ = 1, 5 do
        local e = xi.emote[IDLE_EMOTES[rnd(1, #IDLE_EMOTES)]]
        if e then
            return e
        end
    end

    return xi.emote.WAVE
end

local function settleAt(npc, bot, spot)
    -- what a bot does when it has arrived at (or was spawned on) a spot of this kind
    bot.kind = spot and spot.kind or 'idle'
    if bot.kind == 'rest' then
        npc:setAnimation(chance(0.6) and ANIM_HEALING or ANIM_SIT)
    else
        npc:setAnimation(ANIM_NONE)
    end

    if spot and (bot.kind == 'ah' or bot.kind == 'rest') then
        npc:setRotation(spot.rot)
    end
end

local function nearestBot(crowd, bot, maxDist)
    local best, bestD
    for id, other in pairs(crowd.bots) do
        if other ~= bot and other.x then
            local d = dist2(bot.x, bot.z, other.x, other.z)
            if d <= maxDist * maxDist and (bestD == nil or d < bestD) then
                best, bestD = id, d
            end
        end
    end

    return best
end

local WALK_RANGE = 80 -- yalms: most walks go to a spot this close (big towns, outposts with two camps)

local function startWalk(npc, bot, crowd)
    local targets = freeSpots(crowd)
    if #targets == 0 then
        return false
    end

    local pos = npc:getPos()
    local near = {}
    for _, s in ipairs(targets) do
        if dist2(pos.x, pos.z, s.x, s.z) <= WALK_RANGE * WALK_RANGE then
            near[#near + 1] = s
        end
    end

    if #near > 0 and chance(0.85) then
        targets = near
    end

    local target = targets[rnd(1, #targets)]
    npc:setAnimation(ANIM_NONE)
    takeSpot(bot, target)
    bot.kind = 'walk'
    bot.walkStarted = os.time()
    npc:pathTo(target.x, target.y, target.z)
    return true
end

local function removeBot(npc, crowd, bot, animate, after)
    if crowd.bots[npc:getID()] ~= bot then
        return
    end

    crowd.bots[npc:getID()] = nil
    crowd.count = crowd.count - 1
    crowd.usedNames[bot.name] = nil
    takeSpot(bot, nil)
    bot.gone = true
    npc:clearPath()
    if animate then
        npc:entityAnimationPacket(xi.animationString.STATUS_DISAPPEAR)
        npc:timer(1500, function(n)
            n:setStatus(xi.status.DISAPPEAR)
            if after then
                after()
            end
        end)
    else
        npc:setStatus(xi.status.DISAPPEAR)
    end
end

local spawnBot -- forward

local function despawnAll(zoneId)
    local crowd = crowds[zoneId]
    if not crowd then
        return 0
    end

    local removed = 0
    for id, bot in pairs(crowd.bots) do
        local npc = GetNPCByID(id)
        if npc then
            removeBot(npc, crowd, bot, false)
            removed = removed + 1
        else
            crowd.bots[id] = nil
        end
    end

    crowds[zoneId] = nil
    return removed
end

think = function(npc, bot)
    if bot.gone then
        return
    end

    local zoneId = npc:getZoneID()
    local crowd = crowds[zoneId]
    if not crowd or crowd.bots[npc:getID()] ~= bot then
        return -- this crowd was rebuilt or removed
    end

    local zone = npc:getZone()
    local players = zone and xi.crowds.realPlayers(zone) or {}
    if #players == 0 then
        crowd.emptySince = crowd.emptySince or os.time()
        if os.time() - crowd.emptySince >= EMPTY_DESPAWN then
            despawnAll(zoneId)
            return
        end

        schedule(npc, bot, 20000) -- nobody to see them: just wait
        return
    end

    crowd.emptySince = nil

    if not cfg.enabled then
        removeBot(npc, crowd, bot, true)
        return
    end

    -- Too many (the count was lowered): this one leaves
    if crowd.count > targetFor(zoneId) then
        removeBot(npc, crowd, bot, true)
        return
    end

    -- Shouts and say chatter (its own timing per area; this bot may be the one who speaks)
    if chat then
        -- with bot players living here, the chatter is theirs (bots_life.lua); the crowd stays quiet
        local botsHere = xi.bots and xi.bots.countInZone and xi.bots.countInZone(zoneId) or 0
        if botsHere < 2 then
            chat.onThink(npc, bot, crowd, zoneId, players)
        end
    end

    -- Walking: wait until arrived (or give up after 2 minutes)
    if bot.kind == 'walk' then
        if npc:isFollowingPath() and os.time() - (bot.walkStarted or 0) < 120 then
            schedule(npc, bot, WALK_CHECK)
            return
        end

        local pos = npc:getPos()
        bot.x, bot.z = pos.x, pos.z
        if bot.spot and dist2(pos.x, pos.z, bot.spot.x, bot.spot.z) > 16 then
            takeSpot(bot, nil) -- did not get there (no path): just stand where it is
            settleAt(npc, bot, nil)
        else
            settleAt(npc, bot, bot.spot)
        end
        schedule(npc, bot)
        return
    end

    -- Now and then someone logs out or zones away, and a new adventurer arrives by a Home Point
    if chance(cfg.turnover) then
        -- the newcomer appears once the leaver has gone (same moment its disappear effect ends)
        removeBot(npc, crowd, bot, true, function()
            local z = GetZone(zoneId)
            if z and crowds[zoneId] and crowds[zoneId].count < targetFor(zoneId) then
                spawnBot(z, crowds[zoneId], 'arrive')
            end
        end)
        return
    end

    -- Someone is close: look at them, sometimes wave
    for _, player in ipairs(players) do
        local p = player:getPos()
        if bot.x and dist2(p.x, p.z, bot.x, bot.z) <= NEAR_PLAYER * NEAR_PLAYER and chance(0.25) then
            if bot.kind ~= 'rest' then
                npc:lookAt(p)
            end

            if chance(0.3) then
                emote(npc, player, xi.emote.WAVE)
            end

            if chat then
                chat.onNear(npc, bot, player)
            end

            schedule(npc, bot)
            return
        end
    end

    local roll = math.random()
    if bot.kind == 'rest' then
        if roll < 0.06 then
            startWalk(npc, bot, crowd)          -- done resting
            schedule(npc, bot, WALK_CHECK)
            return
        elseif roll < 0.12 then
            npc:setAnimation(npc:getAnimation() == ANIM_SIT and ANIM_HEALING or ANIM_SIT)
        end
    elseif bot.kind == 'ah' then
        if roll < 0.10 then
            startWalk(npc, bot, crowd)
            schedule(npc, bot, WALK_CHECK)
            return
        elseif roll < 0.20 then
            emote(npc, nil, xi.emote.THINK)
        elseif roll < 0.35 and bot.spot then
            npc:setRotation((bot.spot.rot + rnd(-20, 20)) % 256)
        end
    else -- idle
        if roll < 0.18 then
            startWalk(npc, bot, crowd)
            schedule(npc, bot, WALK_CHECK)
            return
        elseif roll < 0.45 then
            local otherId = nearestBot(crowd, bot, 6)
            local other = otherId and GetNPCByID(otherId)
            if other then
                npc:lookAt(other:getPos())
                if chance(0.3) then
                    emote(npc, other, randomEmote())
                end
            elseif chance(0.3) then
                emote(npc, nil, randomEmote())
            end
        elseif roll < 0.60 then
            npc:setRotation(rnd(0, 255))
        end
    end

    schedule(npc, bot)
end

local function onBotTrigger(player, npc)
    local crowd = crowds[npc:getZoneID()]
    local bot = crowd and crowd.bots[npc:getID()]
    if bot and bot.kind ~= 'rest' then
        npc:lookAt(player:getPos())
    end

    npc:sendEmote(player, chance(0.5) and xi.emote.WAVE or xi.emote.BOW, xi.emoteMode.ALL, false)
    if chat and bot then
        chat.onTouch(npc, bot, player)
    end
end

-- how: 'start' (on a spot of its kind), 'arrive' (appears by a Home Point, then walks off)
spawnBot = function(zone, crowd, how)
    local zoneId = zone:getID()
    if crowd.count >= targetFor(zoneId) then
        return nil
    end

    local zd = data.zones[zoneId]
    if not zd then
        return nil
    end

    local kindWanted
    if how == 'arrive' then
        kindWanted = 'rest'
    else
        kindWanted = pickWeighted({ rest = 25, ah = 20, idle = 30, walk = 25 })
    end

    local spots = freeSpots(crowd, kindWanted ~= 'walk' and kindWanted or nil)
    if #spots == 0 then
        spots = freeSpots(crowd)
    end

    if #spots == 0 then
        return nil
    end

    local spot = spots[rnd(1, #spots)]
    local race = pickWeighted(RACE_WEIGHT)
    local face = rnd(0, 15)
    local bracket = pickWeighted(zd.levels or { [10] = 1 })
    local job = pickJob(bracket)
    local name = makeName(race, crowd.usedNames)
    serial = serial + 1

    local npc = zone:insertDynamicEntity({
        objtype              = xi.objType.NPC,
        name                 = 'Crowd' .. serial,
        packetName           = name,
        look                 = makeLook(race, face, job, bracket),
        x                    = spot.x,
        y                    = spot.y,
        z                    = spot.z,
        rotation             = spot.rot or rnd(0, 255),
        widescan             = 0,
        entityFlags          = cfg.entityFlags,
        releaseIdOnDisappear = true,
        onTrigger            = onBotTrigger,
    })

    if npc == nil then
        crowd.usedNames[name] = nil
        return nil
    end

    -- Gives the NPC a path finder. Must come before any timer: it replaces the NPC's AI (and with it its queued timers).
    npc:initNpcAi()

    local bot = { name = name, job = job, level = bracket, serial = serial, x = spot.x, z = spot.z }
    crowd.bots[npc:getID()] = bot
    crowd.count = crowd.count + 1
    takeSpot(bot, spot)

    if how == 'arrive' then
        npc:entityAnimationPacket(xi.animationString.STATUS_VISIBLE)
        bot.kind = 'idle'
        npc:timer(rnd(2000, 4000), function(n)
            if not bot.gone then
                startWalk(n, bot, crowd)
                schedule(n, bot, WALK_CHECK)
            end
        end)
    elseif kindWanted == 'walk' then
        settleAt(npc, bot, spot)
        npc:timer(rnd(1000, 6000), function(n)
            if not bot.gone then
                startWalk(n, bot, crowd)
                schedule(n, bot, WALK_CHECK)
            end
        end)
    else
        settleAt(npc, bot, spot)
        schedule(npc, bot, rnd(2000, THINK_MAX)) -- spread the first decisions out
    end

    return npc
end

local function ensureCrowd(zone)
    if not zone or not cfg.enabled then
        return 0
    end

    local zoneId = zone:getID()
    if not data.zones[zoneId] or cfg.disabledZones[zoneId] then
        return 0
    end

    local crowd = crowdOf(zoneId)
    crowd.emptySince = nil
    local made = 0
    local tries = 0
    while crowd.count < targetFor(zoneId) and tries < HARD_CAP * 2 do
        tries = tries + 1
        if spawnBot(zone, crowd, 'start') then
            made = made + 1
        elseif #freeSpots(crowd) == 0 then
            break
        end
    end

    return made
end

-----------------------------------
-- Hooks
-----------------------------------
m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    local result = super(player, firstLogin, zoning)
    if BotIsBot and BotIsBot(player:getID()) then
        return result -- a bot player arriving does not bring crowds or field parties
    end

    local here = player:getZoneID()
    if field and cfg.enabled and cfg.field and field.isFieldZone(here) then
        -- field parties: now, and a check every minute while you stay (a new party comes after one is over)
        local token = (player:getLocalVar('CROWD_FIELD_TICK') + 1) % 100000
        player:setLocalVar('CROWD_FIELD_TICK', token)
        local function tick(p)
            if p:getLocalVar('CROWD_FIELD_TICK') ~= token or p:getZoneID() ~= here then
                return
            end

            field.ensure(p:getZone())
            p:timer(60000, tick)
        end

        player:timer(5000, tick)
    end

    if cfg.enabled and data.zones[here] then
        -- a moment after arriving, so the area has finished loading for the client
        player:timer(3000, function(p)
            ensureCrowd(p:getZone())
        end)
    end

    return result
end)

-----------------------------------
-- GM command
-----------------------------------
local crowdCommand = {}
crowdCommand.cmdprops = { permission = 0, parameters = 'sss' } -- single-player server: your own character may use it

crowdCommand.onTrigger = function(player, action, arg1)
    local zone = player:getZone()
    local zoneId = player:getZoneID()
    action = string.lower(action or '')

    if action == '' or action == 'status' then
        local crowd = crowds[zoneId]
        local kinds = {}
        if crowd then
            for _, bot in pairs(crowd.bots) do
                kinds[bot.kind or '?'] = (kinds[bot.kind or '?'] or 0) + 1
            end
        end

        local parts = {}
        for k, v in pairs(kinds) do
            parts[#parts + 1] = k .. ' ' .. v
        end

        tell(player, string.format('%s, size %d. This area: %s, %d here (%s), %d spots (%d marked by you).',
            cfg.enabled and 'ON' or 'OFF', cfg.perZone,
            data.zones[zoneId] and ('crowd of ' .. targetFor(zoneId)) or 'no crowd data',
            crowd and crowd.count or 0, table.concat(parts, ', '),
            #zoneSpots(zoneId), #(userSpots[zoneId] or {})))
    elseif action == 'on' then
        cfg.enabled = true
        tell(player, 'On (until the next PLAY; the launcher setting decides after that). Spawned ' .. ensureCrowd(zone) .. '.')
    elseif action == 'off' then
        cfg.enabled = false
        local removed = 0
        for id in pairs(crowds) do
            removed = removed + despawnAll(id)
        end

        tell(player, 'Off (until the next PLAY). Removed ' .. removed .. '.')
    elseif action == 'count' then
        local n = tonumber(arg1)
        if not n then
            tell(player, 'Usage: !crowd count <0-40>')
            return
        end

        cfg.perZone = math.max(0, math.min(HARD_CAP, math.floor(n)))
        local made = ensureCrowd(zone)
        tell(player, string.format('Size %d (until the next PLAY). Added %d; extra ones leave over the next half minute.', cfg.perZone, made))
    elseif action == 'reload' then
        loadConfig()
        loadUserSpots()
        local removed = despawnAll(zoneId)
        local made = ensureCrowd(zone)
        tell(player, string.format('Settings re-read (%s, size %d). Removed %d, spawned %d.', cfg.enabled and 'ON' or 'OFF', cfg.perZone, removed, made))
    elseif action == 'chat' then
        local what = string.lower(arg1 or '')
        if not chat then
            tell(player, 'Chat is not available (crowds_chat.lua did not load, see the map server log).')
        elseif what == 'on' or what == 'off' then
            cfg.chat = what == 'on'
            tell(player, 'Chat ' .. what .. ' (until the next PLAY).')
        elseif what == 'quiet' or what == 'normal' or what == 'busy' then
            cfg.chat = true
            cfg.chatAmount = what
            tell(player, 'Chat amount: ' .. what .. ' (until the next PLAY).')
        elseif what == 'ai' then
            tell(player, 'Use: !crowd chat aion  or  !crowd chat aioff')
        elseif what == 'aion' or what == 'aioff' then
            cfg.chatAi = what == 'aion'
            tell(player, 'AI chatter ' .. (cfg.chatAi and 'on' or 'off') .. ' (until the next PLAY).')
        elseif what == 'test' then
            tell(player, chat.test(player, crowds[zoneId], zoneId))
        else
            tell(player, string.format('Chat %s, amount %s, AI chatter %s. Use: !crowd chat on|off|quiet|normal|busy|aion|aioff|test',
                cfg.chat and 'ON' or 'OFF', cfg.chatAmount, cfg.chatAi and 'on' or 'off'))
        end
    elseif action == 'field' then
        local what = string.lower(arg1 or '')
        if not field then
            tell(player, 'Field parties are not available (crowds_field.lua did not load, see the map server log).')
        elseif what == 'on' then
            cfg.field = true
            field.resetWait()
            tell(player, 'Field parties on (until the next PLAY). New here: ' .. field.ensure(zone) .. '.')
        elseif what == 'off' then
            cfg.field = false
            tell(player, 'Field parties off (until the next PLAY). Sent home: ' .. field.removeAll() .. '.')
        elseif what == 'test' then
            local made = field.ensure(zone, true)
            tell(player, made > 0 and 'A party set up camp in this area: ' .. field.status(zoneId)
                or ('No party: ' .. (field.isFieldZone(zoneId) and 'no free camp away from you right now (or the area already has its parties)' or 'this is not a field party area')))
        else
            tell(player, string.format('Field parties %s, %d per area. Here: %s. Use: !crowd field on|off|test',
                cfg.field and 'ON' or 'OFF', cfg.fieldParties, field.status(zoneId)))
        end
    elseif action == 'mark' then
        local kind = string.lower(arg1 or '')
        if kind ~= 'rest' and kind ~= 'ah' and kind ~= 'idle' then
            tell(player, 'Usage: !crowd mark rest|ah|idle   (stand where a bot should stand, facing the way it should face)')
            return
        end

        local pos = player:getPos()
        userSpots[zoneId] = userSpots[zoneId] or {}
        table.insert(userSpots[zoneId], { kind = kind, x = pos.x, y = pos.y, z = pos.z, rot = pos.rot })
        if saveUserSpots() then
            tell(player, string.format('Marked a %s spot (%.1f, %.1f, %.1f). !crowd reload to use it now.', kind, pos.x, pos.y, pos.z))
        else
            tell(player, 'Could not write ' .. USER_SPOTS)
        end
    elseif action == 'unmark' then
        local pos = player:getPos()
        local list = userSpots[zoneId] or {}
        local bestI, bestD
        for i, s in ipairs(list) do
            local d = dist2(pos.x, pos.z, s.x, s.z)
            if d <= 9 and (bestD == nil or d < bestD) then
                bestI, bestD = i, d
            end
        end

        if bestI then
            table.remove(list, bestI)
            saveUserSpots()
            tell(player, 'Removed the marked spot nearest to you. !crowd reload to apply.')
        else
            tell(player, 'No spot you marked within 3 yalms.')
        end
    else
        tell(player, 'Usage: !crowd [status|on|off|count N|reload|chat ...|field ...|mark rest|ah|idle|unmark]')
    end
end

xi.module.registerCommand('crowd', crowdCommand)

m.crowds = crowds -- (for the stand-in tests)

return m
