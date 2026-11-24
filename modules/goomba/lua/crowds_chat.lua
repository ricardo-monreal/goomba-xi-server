-----------------------------------
-- Ambient crowds: chat (phase 2). Used by crowds.lua; not a module of its own (not listed in init.txt).
--
-- Shouts (whole area): party wanted, members wanted, selling/buying crafted era items, linkshell recruiting,
-- help wanted, 75 content. They come from the bots you can see (their own job and level), and in Jeuno now and
-- then from someone elsewhere in town. Say (only near you): small talk, two-bot exchanges, outpost camp chatter,
-- greetings and replies when you touch one. No tells.
-- Lines: templates (crowds_chat_data.lua), mixed with AI-written small talk (crowds_chat_ai.lua, written by the
-- C:\FFXISOLO\crowds\crowd_chat_ai.py helper through your local Ollama) when "AI chatter" is on.
-----------------------------------
local T = require('modules/goomba/lua/crowds_chat_data')

local chat = {}
local env            -- set by chat.setup: cfg, data, makeName, dist2
local AI_PATH        = 'modules/goomba/lua/crowds_chat_ai.lua'
local AI_RELOAD      = 300  -- seconds between re-reads of the AI line pool
local SAY_RANGE      = 20   -- yalms: say is only heard this close
local PAIR_RANGE     = 8    -- yalms: the bot that answers stands this close to the first one
local GREET_AGAIN    = 15 * 60

local ai = { say = {}, pairs = {}, outpost = {}, react = {}, shout = {} }
local aiLoaded = -AI_RELOAD

-- Shout and say intervals (seconds) at the "normal" amount. nil = no shouts there.
local JEUNO = { [243] = true, [244] = true, [245] = true, [246] = true }
local SMALL = { [237] = true, [247] = true, [248] = true, [249] = true, [250] = true, [252] = true, [48] = true, [53] = true }
local NATION_OF = {
    [230] = "San d'Oria", [231] = "San d'Oria", [232] = "San d'Oria", [234] = 'Bastok', [235] = 'Bastok', [236] = 'Bastok', [237] = 'Bastok',
    [238] = 'Windurst', [239] = 'Windurst', [240] = 'Windurst', [241] = 'Windurst',
}
local AMOUNT = { quiet = 2.0, normal = 1.0, busy = 0.5 }

local function profile(zoneId)
    local zd = env.data.zones[zoneId]
    if zd and zd.scale and zd.scale < 0.5 then -- outposts: no shouts, more camp chatter
        return { shout = nil, say = { 25, 50 }, weights = {}, outpost = true }
    end

    if JEUNO[zoneId] then
        return { shout = { 30, 45 }, say = { 35, 70 }, ghost = 0.25,
            weights = { lfp = 26, lfp_heal = 6, lfm = 24, selling = 14, buying = 6, ls = 8, help = 8, endgame = 8, ai = 6 } }
    elseif SMALL[zoneId] then
        return { shout = { 180, 300 }, say = { 45, 90 },
            weights = { lfp = 20, lfm = 10, selling = 25, buying = 15, ls = 5, help = 10, ai = 15 } }
    elseif zoneId == 50 then -- Aht Urhgan Whitegate: the ToAU hub
        return { shout = { 50, 80 }, say = { 35, 70 }, ghost = 0.15,
            weights = { lfp = 22, lfm = 22, selling = 14, buying = 6, ls = 6, help = 8, endgame = 14, ai = 8 } }
    end

    return { shout = { 60, 120 }, say = { 35, 70 },
        weights = { lfp = 24, lfp_heal = 4, lfm = 16, selling = 22, buying = 8, ls = 8, help = 12, ai = 6 } }
end

-----------------------------------
-- helpers
-----------------------------------
local function rnd(a, b)
    return math.random(a, b)
end

local function pick(list)
    if list == nil or #list == 0 then
        return nil
    end

    return list[rnd(1, #list)]
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

local function interval(range)
    local m = AMOUNT[env.cfg.chatAmount] or 1
    return math.floor(rnd(range[1], range[2]) * m)
end

local function byLevel(tbl, lvl)
    local best, bestKey, prevKey = nil, -1, nil
    for key in pairs(tbl) do
        if key <= lvl and key > bestKey then
            bestKey = key
        end
    end

    if bestKey < 0 then
        for key in pairs(tbl) do
            if bestKey < 0 or key < bestKey then
                bestKey = key
            end
        end
    end

    best = tbl[bestKey]
    -- sometimes the neighbour below as well (camps overlap)
    for key in pairs(tbl) do
        if key < bestKey and (prevKey == nil or key > prevKey) then
            prevKey = key
        end
    end

    if prevKey and math.random() < 0.3 then
        return tbl[prevKey]
    end

    return best
end

local function price(gil)
    gil = math.floor(gil * (0.85 + math.random() * 0.3))
    if gil < 1000 then
        return string.format('%dg', math.floor(gil / 10 + 0.5) * 10)
    elseif gil < 10000 then
        local s = string.format('%.1fk', gil / 1000)
        return (s:gsub('%.0k', 'k'))
    elseif gil < 1000000 then
        return string.format('%dk', math.floor(gil / 1000 + 0.5))
    end

    local s = string.format('%.1fm', gil / 1000000)
    return (s:gsub('%.0m', 'm'))
end

local function clean(text)
    text = tostring(text or ''):gsub('[^\32-\126]', '')
    if #text > 110 then
        text = text:sub(1, 110)
    end

    return text
end

-- the speaker's real level (bots carry a level bracket; advanced jobs start at 30 in this era)
local BASE = { WAR = true, MNK = true, WHM = true, BLM = true, RDM = true, THF = true }
function chat.levelOf(bot)
    if bot.lvl then
        return bot.lvl
    end

    local b = bot.level or 10
    local lvl
    if b >= 75 then
        lvl = math.random() < 0.7 and 75 or rnd(71, 75)
    else
        lvl = rnd(math.max(5, b - 9), b)
    end

    if not BASE[bot.job or 'WAR'] then
        lvl = math.max(lvl, 30)
    end

    bot.lvl = lvl
    return lvl
end

local function fill(text, who, zoneId, playerName)
    local lvl = chat.levelOf(who)
    local job = who.job or 'WAR'
    local sub = who.sub or pick(T.subs[job]) or 'WAR'
    who.sub = sub
    local item = pick(env.data.sell or {}) or { 'Bronze Ingot', 300, 1 }
    local lo, hi = math.max(1, lvl - rnd(1, 3)), math.min(75, lvl + rnd(1, 3))
    local fields = {
        job = job, lvl = tostring(lvl), sub = sub, sublvl = tostring(math.floor(lvl / 2)),
        camp = pick(byLevel(T.camps, lvl)) or 'Valkurm', range = lo .. '-' .. hi, need = pick(T.needs),
        item = item[1], price = price(item[2]), ls = who.ls or (pick(T.lsWords1) .. pick(T.lsWords2)),
        nation = NATION_OF[zoneId] or 'Jeuno', mission = pick(byLevel(T.missions, lvl)) or 'a mission',
        endgame = pick(T.endgame), self = who.name or 'me', name = playerName or 'you',
    }
    return clean((text:gsub('{(%w+)}', function(key)
        return fields[key] or ''
    end)))
end

local function loadAi(now)
    if now - aiLoaded < AI_RELOAD then
        return
    end

    aiLoaded = now
    local chunk = loadfile(AI_PATH)
    if not chunk then
        return
    end

    local ok, pool = pcall(chunk)
    if ok and type(pool) == 'table' then
        ai = {
            say = pool.say or {}, pairs = pool.pairs or {}, outpost = pool.outpost or {},
            react = pool.react or {}, shout = pool.shout or {},
        }
    end
end

local function useAi(list, share)
    return env.cfg.chatAi and #list > 0 and math.random() < share
end

local function recentCheck(crowd, line)
    crowd.recentLines = crowd.recentLines or {}
    for _, l in ipairs(crowd.recentLines) do
        if l == line then
            return false
        end
    end

    table.insert(crowd.recentLines, line)
    if #crowd.recentLines > 25 then
        table.remove(crowd.recentLines, 1)
    end

    return true
end

-----------------------------------
-- output
-----------------------------------
local SHOUT = 1
local SAY = 0

local function sendShout(players, name, text)
    for _, p in ipairs(players) do
        p:printToPlayer(text, (xi.msg and xi.msg.channel and xi.msg.channel.SHOUT) or SHOUT, name)
    end
end

local function sendSay(players, x, z, name, text)
    local heard = 0
    for _, p in ipairs(players) do
        local pos = p:getPos()
        if env.dist2(pos.x, pos.z, x, z) <= SAY_RANGE * SAY_RANGE then
            p:printToPlayer(text, (xi.msg and xi.msg.channel and xi.msg.channel.SAY) or SAY, name)
            heard = heard + 1
        end
    end

    return heard
end

local function nearAPlayer(players, x, z, range)
    for _, p in ipairs(players) do
        local pos = p:getPos()
        if env.dist2(pos.x, pos.z, x, z) <= range * range then
            return p
        end
    end

    return nil
end

-----------------------------------
-- making lines
-----------------------------------
function chat.shoutLine(who, zoneId, group)
    local lvl = chat.levelOf(who)
    if group == 'endgame' and lvl < 75 then
        group = 'lfp'
    end

    if group == 'ai' then
        if env.cfg.chatAi and #ai.shout > 0 then
            return fill(pick(ai.shout), who, zoneId)
        end

        group = 'lfp'
    end

    if group == 'lfp_heal' then
        -- only for a healer/support job, with the speaker's own job
        local own = {}
        for _, line in ipairs(T.shout.lfp_heal) do
            if line:find(who.job or '?', 1, true) then
                own[#own + 1] = line
            end
        end

        if #own > 0 then
            return fill(pick(own), who, zoneId)
        end

        group = 'lfp'
    end

    return fill(pick(T.shout[group] or T.shout.lfp), who, zoneId)
end

-- players in an area, without the bot players (bots.lua): bots do not keep crowds or field parties alive
local function realPlayers(zone)
    if xi.crowds and xi.crowds.realPlayers then
        return xi.crowds.realPlayers(zone)
    end

    return zone:getPlayers()
end

local function sayLine(who, zoneId, outpost)
    if outpost then
        if useAi(ai.outpost, 0.5) then
            return fill(pick(ai.outpost), who, zoneId)
        end

        return fill(pick(T.outpost), who, zoneId)
    end

    if useAi(ai.say, 0.5) then
        return fill(pick(ai.say), who, zoneId)
    end

    return fill(pick(T.say), who, zoneId)
end

chat.sayLine = sayLine

local function pairLines(who, other, zoneId)
    local pr
    if useAi(ai.pairs, 0.5) then
        pr = pick(ai.pairs)
    else
        pr = pick(T.pairs)
    end

    return fill(pr[1], who, zoneId), fill(pr[2], other, zoneId)
end

-----------------------------------
-- hooks from crowds.lua
-----------------------------------
function chat.setup(e)
    env = e
end

-- A bot is thinking and somebody is in the area: maybe it is this bot's turn to shout or talk.
function chat.onThink(npc, bot, crowd, zoneId, players)
    if not env.cfg.chat or #players == 0 then
        return
    end

    local now = os.time()
    loadAi(now)
    local prof = profile(zoneId)
    crowd.chatNextShout = crowd.chatNextShout or (now + rnd(5, 20))
    crowd.chatNextSay = crowd.chatNextSay or (now + rnd(10, 25))

    if prof.shout and now >= crowd.chatNextShout then
        crowd.chatNextShout = now + interval(prof.shout)
        local who = bot
        if prof.ghost and math.random() < prof.ghost then
            -- someone elsewhere in town
            local ghostRace = rnd(1, 8)
            local jobs = { 'WAR', 'MNK', 'WHM', 'BLM', 'RDM', 'THF', 'PLD', 'DRK', 'BRD', 'RNG', 'SAM', 'NIN', 'DRG', 'SMN', 'BLU', 'COR', 'PUP', 'BST' }
            who = { name = env.makeName(ghostRace, crowd.usedNames), job = pick(jobs), level = pick({ 20, 30, 40, 50, 60, 70, 75, 75 }) }
            -- (the name stays taken, so a bot who arrives later never shares it)
        end

        for _ = 1, 3 do
            local line = chat.shoutLine(who, zoneId, pickWeighted(prof.weights))
            if recentCheck(crowd, line) then
                sendShout(players, who.name, line)
                return
            end
        end

        return
    end

    if now >= crowd.chatNextSay then
        local pos = npc:getPos()
        if bot.kind == 'walk' or not nearAPlayer(players, pos.x, pos.z, SAY_RANGE) then
            return -- someone closer to you will talk
        end

        crowd.chatNextSay = now + interval(prof.say)
        -- a two-bot exchange when a neighbour stands close
        local partner
        if not prof.outpost and math.random() < 0.4 then
            for _, other in pairs(crowd.bots) do
                if other ~= bot and other.kind ~= 'walk' and other.x and env.dist2(other.x, other.z, pos.x, pos.z) <= PAIR_RANGE * PAIR_RANGE then
                    partner = other
                    break
                end
            end
        end

        if partner then
            local a, b = pairLines(bot, partner, zoneId)
            sendSay(players, pos.x, pos.z, bot.name, a)
            npc:timer(rnd(3000, 6000), function(n)
                if not partner.gone and env.cfg.chat then
                    local z = n:getZone()
                    sendSay(z and realPlayers(z) or players, partner.x, partner.z, partner.name, b)
                end
            end)
        else
            sendSay(players, pos.x, pos.z, bot.name, sayLine(bot, zoneId, prof.outpost))
        end
    end
end

-- You walked up to a bot
-- The same town chatter, spoken by the bot players (bots_life.lua) instead of crowd NPCs: real shouts and says
-- from real characters (their own job and level go into the lines). speakers = bot entities in the area,
-- players = real players there, speak(bot, kind, text) sends it (kind 0 say, 1 shout).
local botZones = {}

function chat.onBotThink(zoneId, speakers, players, speak)
    if not env.cfg.chat or #players == 0 or #speakers == 0 then
        return
    end

    local JOBS = { 'WAR', 'MNK', 'WHM', 'BLM', 'RDM', 'THF', 'PLD', 'DRK', 'BST', 'BRD', 'RNG', 'SAM', 'NIN', 'DRG', 'SMN', 'BLU', 'COR', 'PUP' }
    local now = os.time()
    loadAi(now)
    local prof = profile(zoneId)
    local z = botZones[zoneId] or {}
    botZones[zoneId] = z
    z.nextShout = z.nextShout or (now + rnd(10, 30))
    z.nextSay = z.nextSay or (now + rnd(10, 25))
    local function who(e)
        return { name = e:getName(), job = JOBS[e:getMainJob()] or 'WAR', lvl = e:getMainLvl(), level = e:getMainLvl(),
                 ls = xi.bots and xi.bots.lsName and xi.bots.lsName(e) or nil }
    end

    if prof.shout and now >= z.nextShout then
        z.nextShout = now + interval(prof.shout)
        local e = pick(speakers)
        for _ = 1, 3 do
            local w = who(e)
            local group = pickWeighted(prof.weights)
            if group == 'ls' and not w.ls then
                group = 'lfp' -- (only a member recruits for its own linkshell)
            end

            local line = chat.shoutLine(w, zoneId, group)
            if line and line ~= '' and recentCheck(z, line) then
                speak(e, 1, line)
                return
            end
        end

        return
    end

    if now >= z.nextSay then
        -- someone standing near a real player says something (a neighbour may answer)
        local near = {}
        for _, e in ipairs(speakers) do
            local pos = e:getPos()
            if nearAPlayer(players, pos.x, pos.z, SAY_RANGE) then
                near[#near + 1] = e
            end
        end

        if #near == 0 then
            return
        end

        z.nextSay = now + interval(prof.say)
        local a = pick(near)
        local partner
        if not prof.outpost and #near > 1 and math.random() < 0.4 then
            for _, e in ipairs(near) do
                if e ~= a then
                    local pa, pe = a:getPos(), e:getPos()
                    if env.dist2(pa.x, pa.z, pe.x, pe.z) <= PAIR_RANGE * PAIR_RANGE then
                        partner = e
                        break
                    end
                end
            end
        end

        if partner then
            local l1, l2 = pairLines(who(a), who(partner), zoneId)
            speak(a, 0, l1)
            a:timer(rnd(3000, 6000), function()
                if partner:isAlive() then
                    speak(partner, 0, l2)
                end
            end)
        else
            speak(a, 0, sayLine(who(a), zoneId, prof.outpost))
        end
    end
end

function chat.onNear(npc, bot, player)
    if not env.cfg.chat or math.random() > 0.25 then
        return
    end

    bot.greeted = bot.greeted or {}
    local id = player:getID()
    local now = os.time()
    if bot.greeted[id] and now - bot.greeted[id] < GREET_AGAIN then
        return
    end

    bot.greeted[id] = now
    local pos = npc:getPos()
    sendSay({ player }, pos.x, pos.z, bot.name, fill(pick(T.greet), bot, npc:getZoneID(), player:getName()))
end

-- You touched a bot
function chat.onTouch(npc, bot, player)
    if not env.cfg.chat or not bot or math.random() > 0.6 then
        return
    end

    local now = os.time()
    loadAi(now)
    local line = useAi(ai.react, 0.4) and pick(ai.react) or pick(T.react)
    local pos = npc:getPos()
    sendSay({ player }, pos.x, pos.z, bot.name, fill(line, bot, npc:getZoneID(), player:getName()))
end

-- !crowd chat test: one line of each kind, from the bot nearest to you
function chat.test(player, crowd, zoneId)
    loadAi(os.time() + AI_RELOAD) -- re-read the AI pool now
    local pos = player:getPos()
    local best, bestD
    for _, bot in pairs(crowd and crowd.bots or {}) do
        if bot.x then
            local d = env.dist2(pos.x, pos.z, bot.x, bot.z)
            if not bestD or d < bestD then
                best, bestD = bot, d
            end
        end
    end

    best = best or { name = 'Testbot', job = 'WHM', level = 20 }
    local players = { player }
    for _, group in ipairs({ 'lfp', 'lfm', 'selling', 'ls', 'help' }) do
        sendShout(players, best.name, chat.shoutLine(best, zoneId, group))
    end

    player:printToPlayer(sayLine(best, zoneId, false), (xi.msg and xi.msg.channel and xi.msg.channel.SAY) or SAY, best.name)
    return string.format('AI lines in the pool: say %d, pairs %d, outpost %d, react %d, shout %d (AI chatter %s).',
        #ai.say, #ai.pairs, #ai.outpost, #ai.react, #ai.shout, env.cfg.chatAi and 'on' or 'off')
end

return chat
