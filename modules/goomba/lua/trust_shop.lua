-----------------------------------
-- Goomba XI: Trust Liaison (trust shop NPC in Lower Jeuno)
-----------------------------------
-- Opens up trusts this 75-era server can't otherwise give (their quests and ciphers belong to
-- content that is turned off). Talk to the Trust Liaison in Lower Jeuno: trusts unlock in tiers
-- by the player's highest job level and are bought with conquest points through menus.
--
-- Conquest points are the player's own nation's points (the ones shown in the conquest menu).
-- Edit the tiers or the NPC below, then: sudo goomba apply && sudo goomba restart game
-----------------------------------
require('modules/module_utils')
require('scripts/zones/Lower_Jeuno/Zone')
-----------------------------------
local m = Module:new('goomba_trust_shop')

-- Each tier: the job level needed, the price in conquest points, and five trusts as
-- { name in xi.magic.spell (scripts/enum/magic.lua), name shown to players }.
-- 35 trusts in all, 75-era jobs only.
local tiers =
{
    {
        level = 20, cost = 1000,
        trusts = { { 'ZEID', 'Zeid' }, { 'LION', 'Lion' }, { 'TENZEN', 'Tenzen' }, { 'MIHLI_ALIAPOH', 'Mihli Aliapoh' }, { 'VALAINERAL', 'Valaineral' } },
    },
    {
        level = 30, cost = 1500,
        trusts = { { 'NAJA_SALAHEEM', 'Naja Salaheem' }, { 'JOACHIM', 'Joachim' }, { 'RAINEMARD', 'Rainemard' }, { 'GADALAR', 'Gadalar' }, { 'NAJELITH', 'Najelith' } },
    },
    {
        level = 40, cost = 2000,
        trusts = { { 'LUZAF', 'Luzaf' }, { 'GESSHO', 'Gessho' }, { 'ZAZARG', 'Zazarg' }, { 'LEHKO_HABHOKA', 'Lehko Habhoka' }, { 'KARAHA_BARUHA', 'Karaha-Baruha' } },
    },
    {
        level = 50, cost = 2500,
        trusts = { { 'LILISETTE', 'Lilisette' }, { 'AREUHAT', 'Areuhat' }, { 'ELIVIRA', 'Elivira' }, { 'NOILLURIE', 'Noillurie' }, { 'RAHAL', 'Rahal' } },
    },
    {
        level = 60, cost = 3000,
        trusts = { { 'CID', 'Cid' }, { 'FABLINIX', 'Fablinix' }, { 'ADELHEID', 'Adelheid' }, { 'KORU_MORU', 'Koru-Moru' }, { 'FERREOUS_COFFIN', 'Ferreous Coffin' } },
    },
    {
        level = 70, cost = 4000,
        trusts = { { 'GILGAMESH', 'Gilgamesh' }, { 'DOMINA_SHANTOTTO', 'Domina Shantotto' }, { 'MUMOR', 'Mumor' }, { 'QULTADA', 'Qultada' }, { 'ROMAA_MIHGO', 'Romaa Mihgo' } },
    },
    {
        level = 75, cost = 5000,
        trusts = { -- the Ark Angels
            { 'AAHM', 'Ark Angel HM' }, { 'AAEV', 'Ark Angel EV' }, { 'AAMR', 'Ark Angel MR' }, { 'AATT', 'Ark Angel TT' }, { 'AAGK', 'Ark Angel GK' },
        },
    },
}

-- The NPC. Placed in the open square where retail later put Lower Jeuno's waypoint, and
-- dressed like Wetata, the Trust program's cipher reader in Windurst Woods.
local npcSettings =
{
    name     = 'Trust Liaison',
    look     = '0x01000306461118205230B8408550006000700000',
    x        = -33.000,
    y        = 0.000,
    z        = -29.000,
    rotation = 18,
}

local maxDistance = 6    -- yalms; menu choices only count while the player stands at the NPC
local perPage     = 5    -- tiers per menu page (the client shows up to 7 options)
local channel     = xi.msg.channel.NS_SAY

-- Resolved on first use, so xi.magic.spell is certainly loaded.
local resolved = false

local function resolveTiers()
    if resolved then
        return
    end

    resolved = true
    for tierIndex, tier in ipairs(tiers) do
        local list = {}
        for _, trust in ipairs(tier.trusts) do
            local spellId = xi.magic.spell[trust[1]]
            if spellId then
                table.insert(list, { spellId = spellId, name = trust[2] })
            else
                print(string.format('[goomba_trust_shop] unknown trust %s in tier %d; skipped', trust[1], tierIndex))
            end
        end

        tier.resolved = list
    end
end

-- Highest level on any job, so changing jobs never locks a player out of a tier.
local function highestJobLevel(player)
    local best = player:getMainLvl()
    for jobId = 1, 22 do
        local lvl = player:getJobLevel(jobId)
        if lvl and lvl > best then
            best = lvl
        end
    end

    return best
end

local function formatNumber(n)
    local s = tostring(n):reverse():gsub('(%d%d%d)', '%1,'):reverse()
    return (s:gsub('^,', ''))
end

local function say(player, npc, text)
    player:printToPlayer(text, channel, npc:getPacketName())
end

-- New menus must wait a moment for the previous one to close.
local function showMenu(player, menu)
    player:timer(50, function(playerArg)
        playerArg:customMenu(menu)
    end)
end

local function nearNpc(player, npc)
    return player:getZoneID() == xi.zone.LOWER_JEUNO and player:checkDistance(npc) <= maxDistance
end

local showTiers, showTier

local function buy(player, npc, tier, trust)
    if not nearNpc(player, npc) then
        return
    end

    if player:hasSpell(trust.spellId) then
        say(player, npc, string.format('You already know %s.', trust.name))
        return
    end

    if highestJobLevel(player) < tier.level then
        say(player, npc, string.format('%s needs a job at level %d.', trust.name, tier.level))
        return
    end

    if player:getCP() < tier.cost then
        say(player, npc, string.format('%s costs %s conquest points. You have %s.', trust.name, formatNumber(tier.cost), formatNumber(player:getCP())))
        return
    end

    player:delCP(tier.cost)
    player:addSpell(trust.spellId, { silentLog = true })
    say(player, npc, string.format('You learned Trust: %s. %s conquest points left.', trust.name, formatNumber(player:getCP())))
end

local function confirm(player, npc, tierIndex, trust)
    local tier = tiers[tierIndex]
    showMenu(player, {
        title   = string.format('%s for %s conquest points?', trust.name, formatNumber(tier.cost)),
        options =
        {
            { 'Buy', function(playerArg) buy(playerArg, npc, tier, trust) end },
            { 'Back', function(playerArg) showTier(playerArg, npc, tierIndex) end },
        },
    })
end

showTier = function(player, npc, tierIndex)
    local tier    = tiers[tierIndex]
    local options = {}

    for _, trust in ipairs(tier.resolved) do
        if player:hasSpell(trust.spellId) then
            table.insert(options, {
                trust.name .. ' (owned)',
                function(playerArg)
                    say(playerArg, npc, string.format('You already know %s.', trust.name))
                    showTier(playerArg, npc, tierIndex)
                end,
            })
        else
            table.insert(options, {
                trust.name,
                function(playerArg) confirm(playerArg, npc, tierIndex, trust) end,
            })
        end
    end

    table.insert(options, { 'Back', function(playerArg) showTiers(playerArg, npc, math.floor((tierIndex - 1) / perPage) + 1) end })

    showMenu(player, {
        title   = string.format('Level %d trusts, %s conquest points each', tier.level, formatNumber(tier.cost)),
        options = options,
    })
end

showTiers = function(player, npc, page)
    local level   = highestJobLevel(player)
    local pages   = math.ceil(#tiers / perPage)
    local first   = (page - 1) * perPage + 1
    local options = {}

    for tierIndex = first, math.min(#tiers, first + perPage - 1) do
        local tier = tiers[tierIndex]
        local owned = 0
        for _, trust in ipairs(tier.resolved) do
            if player:hasSpell(trust.spellId) then
                owned = owned + 1
            end
        end

        if level >= tier.level then
            table.insert(options, {
                string.format('Level %d (%d/%d owned)', tier.level, owned, #tier.resolved),
                function(playerArg) showTier(playerArg, npc, tierIndex) end,
            })
        else
            table.insert(options, {
                string.format('Level %d (locked)', tier.level),
                function(playerArg)
                    say(playerArg, npc, string.format('Come back when one of your jobs reaches level %d.', tier.level))
                end,
            })
        end
    end

    if page < pages then
        table.insert(options, { 'More trusts', function(playerArg) showTiers(playerArg, npc, page + 1) end })
    end

    if page > 1 then
        table.insert(options, { 'Previous', function(playerArg) showTiers(playerArg, npc, page - 1) end })
    else
        table.insert(options, { 'Never mind', function(playerArg) end })
    end

    showMenu(player, {
        title   = string.format('Trusts for conquest points (you have %s)', formatNumber(player:getCP())),
        options = options,
    })
end

local function onTrigger(player, npc)
    resolveTiers()

    if xi.settings.main.ENABLE_TRUST_CASTING == 0 then
        say(player, npc, 'The Trust program is closed for now.')
        return
    end

    say(player, npc, 'Adventurers who serve their nation can call on more allies. Conquest points buy a place on their roster.')
    showTiers(player, npc, 1)
end

m:addOverride('xi.zones.Lower_Jeuno.Zone.onInitialize', function(zone)
    super(zone)

    zone:insertDynamicEntity({
        objtype   = xi.objType.NPC,
        name      = npcSettings.name,
        look      = npcSettings.look,
        x         = npcSettings.x,
        y         = npcSettings.y,
        z         = npcSettings.z,
        rotation  = npcSettings.rotation,
        widescan  = 1,
        onTrigger = onTrigger,
    })
end)
