-----------------------------------
-- Goomba XI: Trust Liaison (trust shop NPC in Lower Jeuno)
-----------------------------------
-- Opens up trusts this 75-era server can't otherwise give (their quests and ciphers belong to
-- content that is turned off). Talk to the Trust Liaison in Lower Jeuno: trusts unlock in tiers
-- by the player's highest job level and are bought with conquest points through menus,
-- five to a page.
--
-- Conquest points are the player's own nation's points (the ones shown in the conquest menu).
-- Edit the tiers or the NPC below, then: sudo goomba apply && sudo goomba restart game
-----------------------------------
require('modules/module_utils')
require('scripts/zones/Lower_Jeuno/Zone')
-----------------------------------
local m = Module:new('goomba_trust_shop')

-- Each tier: the job level needed, the price in conquest points, and its trusts as
-- { name in xi.magic.spell (scripts/enum/magic.lua), name shown to players }.
-- Every trust LandSandBoat implements, in the order they came to retail, except the five
-- starter trusts (solo_trusts.lua gives those to everyone) and the blocked Geomancer, Rune
-- Fencer, Dancer and Scholar trusts (solo_trusts.lua, blockedTrusts).
local tiers =
{
    {
        level = 20, cost = 1000,
        trusts =
        {
            { 'NANAA_MIHGO', "Nanaa Mihgo" }, -- THF
            { 'CURILLA', "Curilla" }, -- PLD
            { 'VOLKER', "Volker" }, -- WAR
            { 'AJIDO_MARUJIDO', "Ajido-Marujido" }, -- BLM
            { 'TRION', "Trion" }, -- PLD
            { 'ZEID', "Zeid" }, -- DRK
            { 'LION', "Lion" }, -- THF
            { 'TENZEN', "Tenzen" }, -- SAM
            { 'MIHLI_ALIAPOH', "Mihli Aliapoh" }, -- WHM
            { 'VALAINERAL', "Valaineral" }, -- PLD
            { 'JOACHIM', "Joachim" }, -- BRD
            { 'NAJA_SALAHEEM', "Naja Salaheem" }, -- MNK
            { 'PRISHE', "Prishe" }, -- MNK
            { 'ULMIA', "Ulmia" }, -- BRD
            { 'SHIKAREE_Z', "Shikaree Z" }, -- DRG
        },
    },
    {
        level = 30, cost = 1500,
        trusts =
        {
            { 'CHERUKIKI', "Cherukiki" }, -- WHM
            { 'IRON_EATER', "Iron Eater" }, -- WAR
            { 'GESSHO', "Gessho" }, -- NIN
            { 'GADALAR', "Gadalar" }, -- BLM
            { 'RAINEMARD', "Rainemard" }, -- RDM
            { 'INGRID', "Ingrid" }, -- WHM
            { 'LEHKO_HABHOKA', "Lehko Habhoka" }, -- THF
            { 'NASHMEIRA', "Nashmeira" }, -- PUP
            { 'ZAZARG', "Zazarg" }, -- MNK
            { 'OVJANG', "Ovjang" }, -- RDM
            { 'MNEJING', "Mnejing" }, -- PLD
            { 'LUZAF', "Luzaf" }, -- COR
            { 'NAJELITH', "Najelith" }, -- RNG
            { 'ALDO', "Aldo" }, -- THF
            { 'FABLINIX', "Fablinix" }, -- THF
        },
    },
    {
        level = 40, cost = 2000,
        trusts =
        {
            { 'MAAT', "Maat" }, -- MNK
            { 'DOMINA_SHANTOTTO', "Domina Shantotto" }, -- BLM
            { 'KARAHA_BARUHA', "Karaha-Baruha" }, -- WHM
            { 'CID', "Cid" }, -- WAR
            { 'GILGAMESH', "Gilgamesh" }, -- SAM
            { 'AREUHAT', "Areuhat" }, -- WAR
            { 'SEMIH_LAFIHNA', "Semih Lafihna" }, -- RNG
            { 'ELIVIRA', "Elivira" }, -- RNG
            { 'NOILLURIE', "Noillurie" }, -- SAM
            { 'LHU_MHAKARACCA', "Lhu Mhakaracca" }, -- BST
            { 'FERREOUS_COFFIN', "Ferreous Coffin" }, -- WHM
            { 'KLARA', "Klara" }, -- WAR
            { 'ROMAA_MIHGO', "Romaa Mihgo" }, -- THF
            { 'RAHAL', "Rahal" }, -- PLD
            { 'KORU_MORU', "Koru-Moru" }, -- RDM
        },
    },
    {
        level = 50, cost = 2500,
        trusts =
        {
            { 'PIEUJE_UC', "Pieuje (UC)" }, -- WHM
            { 'INVINCIBLE_SHIELD_UC', "Invincible Shield (UC)" }, -- WAR
            { 'APURURU_UC', "Apururu (UC)" }, -- WHM
            { 'JAKOH_UC', "Jakoh Wahcondalo (UC)" }, -- THF
            { 'FLAVIRIA_UC', "Flaviria (UC)" }, -- DRG
            { 'BABBAN', "Babban" }, -- MNK
            { 'ABENZIO', "Abenzio" }, -- MNK
            { 'RUGHADJEEN', "Rughadjeen" }, -- PLD
            { 'KUKKI_CHEBUKKI', "Kukki-Chebukki" }, -- BLM
            { 'MARGRET', "Margret" }, -- RNG
            { 'CHACHAROON', "Chacharoon" }, -- THF
            { 'LHE_LHANGAVO', "Lhe Lhangavo" }, -- MNK
            { 'ARCIELA', "Arciela" }, -- RDM
            { 'QULTADA', "Qultada" }, -- COR
            { 'MILDAURION', "Mildaurion" }, -- PLD
        },
    },
    {
        level = 60, cost = 3000,
        trusts =
        {
            { 'HALVER', "Halver" }, -- PLD
            { 'RONGELOUTS', "Rongelouts" }, -- WAR
            { 'LEONOYNE', "Leonoyne" }, -- BLM
            { 'MAXIMILIAN', "Maximilian" }, -- THF
            { 'KAYEEL_PAYEEL', "Kayeel-Payeel" }, -- BLM
            { 'ROBEL_AKBEL', "Robel-Akbel" }, -- BLM
            { 'SELHTEUS', "Selh'teus" }, -- PLD
            { 'YORAN_ORAN_UC', "Yoran-Oran (UC)" }, -- WHM
            { 'ABQUHBAH', "Abquhbah" }, -- WAR
            { 'BALAMOR', "Balamor" }, -- DRK
            { 'AUGUST', "August" }, -- PLD
            { 'ROSULATIA', "Rosulatia" }, -- BLM
            { 'TEODOR', "Teodor" }, -- BLM
            { 'ULLEGORE', "Ullegore" }, -- BLM
            { 'MAKKI_CHEBUKKI', "Makki-Chebukki" }, -- RNG
        },
    },
    {
        level = 70, cost = 4000,
        trusts =
        {
            { 'KING_OF_HEARTS', "King of Hearts" }, -- RDM
            { 'MORIMAR', "Morimar" }, -- BST
            { 'DARRCUILN', "Darrcuiln" }, -- WAR
            { 'IROHA', "Iroha" }, -- SAM
            { 'YGNAS', "Ygnas" }, -- WHM
            { 'MONBERAUX', "Monberaux" }, -- PLD
            { 'MATSUI_P', "Matsui-P" }, -- NIN
            { 'EXCENMILLE_S', "Excenmille [S]" }, -- WAR
            { 'AYAME_UC', "Ayame (UC)" }, -- SAM
            { 'MAAT_UC', "Maat (UC)" }, -- MNK
            { 'ALDO_UC', "Aldo (UC)" }, -- THF
            { 'NAJA_UC', "Naja Salaheem (UC)" }, -- THF
        },
    },
    {
        level = 75, cost = 5000,
        trusts =
        {
            { 'AAHM', "Ark Angel HM" }, -- WAR
            { 'AAEV', "Ark Angel EV" }, -- PLD
            { 'AAMR', "Ark Angel MR" }, -- BST
            { 'AATT', "Ark Angel TT" }, -- BLM
            { 'AAGK', "Ark Angel GK" }, -- SAM
            { 'LION_II', "Lion II" }, -- THF
            { 'ZEID_II', "Zeid II" }, -- DRK
            { 'PRISHE_II', "Prishe II" }, -- WHM
            { 'NASHMEIRA_II', "Nashmeira II" }, -- WHM
            { 'TENZEN_II', "Tenzen II" }, -- SAM
            { 'MUMOR_II', "Mumor II" }, -- BLM
            { 'INGRID_II', "Ingrid II" }, -- WHM
            { 'ARCIELA_II', "Arciela II" }, -- RDM
            { 'IROHA_II', "Iroha II" }, -- SAM
            { 'SHANTOTTO_II', "Shantotto II" }, -- BLM
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

local function confirm(player, npc, tierIndex, trust, page)
    local tier = tiers[tierIndex]
    showMenu(player, {
        title   = string.format('%s for %s conquest points?', trust.name, formatNumber(tier.cost)),
        options =
        {
            { 'Buy', function(playerArg) buy(playerArg, npc, tier, trust) end },
            { 'Back', function(playerArg) showTier(playerArg, npc, tierIndex, page) end },
        },
    })
end

local trustsPerPage = 5 -- the client shows up to 7 options: 5 trusts, More, Back

showTier = function(player, npc, tierIndex, page)
    page          = page or 1
    local tier    = tiers[tierIndex]
    local pages   = math.max(1, math.ceil(#tier.resolved / trustsPerPage))
    local first   = (page - 1) * trustsPerPage + 1
    local options = {}

    for i = first, math.min(#tier.resolved, first + trustsPerPage - 1) do
        local trust = tier.resolved[i]
        if player:hasSpell(trust.spellId) then
            table.insert(options, {
                trust.name .. ' (owned)',
                function(playerArg)
                    say(playerArg, npc, string.format('You already know %s.', trust.name))
                    showTier(playerArg, npc, tierIndex, page)
                end,
            })
        else
            table.insert(options, {
                trust.name,
                function(playerArg) confirm(playerArg, npc, tierIndex, trust, page) end,
            })
        end
    end

    if page < pages then
        table.insert(options, { 'More', function(playerArg) showTier(playerArg, npc, tierIndex, page + 1) end })
    end

    if page > 1 then
        table.insert(options, { 'Back', function(playerArg) showTier(playerArg, npc, tierIndex, page - 1) end })
    else
        table.insert(options, { 'Back', function(playerArg) showTiers(playerArg, npc, math.floor((tierIndex - 1) / perPage) + 1) end })
    end

    showMenu(player, {
        title   = string.format('Level %d trusts, %s CP each (%d/%d)', tier.level, formatNumber(tier.cost), page, pages),
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
