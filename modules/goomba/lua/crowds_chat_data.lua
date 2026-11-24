-----------------------------------
-- Ambient crowds: chat templates (read by crowds_chat.lua). Hand-written, 75 era only
-- (base game, Rise of the Zilart, Chains of Promathia, Treasures of Aht Urhgan). Edit freely: keep it ASCII,
-- keep lines short, and use the {fields} below. A line is picked at random and the fields are filled in:
--   {job} {lvl}         the speaker's job and level      {sub} {sublvl}   a typical support job, half the level
--   {camp}              a camp that fits the level       {range}          a level range around the speaker ("23-26")
--   {need}              one or two jobs a party lacks    {item} {price}   a crafted era item and a fair price
--   {ls}                a linkshell name                 {nation}         the nation of the city
--   {mission}           a mission/BC that fits the level {endgame}        75 content
--   {name}              you (only in lines said to you)
-----------------------------------
local c = {}

-- Camps by the lowest level they suit (the highest entry at or below the speaker's level is used, plus its neighbour)
c.camps =
{
    [10] = { 'Valkurm', 'Konschtat', 'Tahrongi', 'La Theine', 'Gusgen' },
    [15] = { 'Valkurm', 'Valkurm Dunes', 'Gusgen Mines' },
    [19] = { 'Qufim', 'Jugner', 'Valkurm' },
    [22] = { 'Qufim', 'Qufim Island', 'Jugner Forest', 'Korroloka' },
    [25] = { 'Yuhtunga', 'Qufim', 'Bibiki Bay', 'Buburimu' },
    [30] = { 'Crawlers Nest', 'Yhoator', 'Beadeaux', 'Davoi', 'Sauromugue' },
    [35] = { 'Garlaige', 'Oztroja', 'Crawlers', 'Yhoator Jungle' },
    [40] = { 'E. Altepa', 'Crawlers Nest', 'Garlaige', 'Sea Serpent Grotto' },
    [45] = { 'Eldieme', 'Sea Serpent Grotto', 'Onzozo', 'Eldieme Necropolis' },
    [50] = { 'Kuftal', 'Gustav', 'Boyahda', 'Ifrits Cauldron', 'Aydeewa' },
    [55] = { 'Boyahda Tree', 'Kuftal Tunnel', 'Ro\'Maeve', 'Mamook', 'Aydeewa' },
    [60] = { 'Mamook', 'Caedarva', 'Aydeewa', 'Valley of Sorrows', 'Den of Rancor' },
    [65] = { 'Caedarva Mire', 'Mount Zhayolm', 'Bhaflau', 'Uleguerand', 'Wajaom' },
    [70] = { 'Bhaflau Thickets', 'Wajaom', 'Zhayolm', 'Arrapago', 'Halvung' },
    [75] = { 'Bhaflau', 'Wajaom', 'Zhayolm', 'Arrapago Reef', 'Halvung', 'Aydeewa' },
}

-- Missions, battlefields and quests people shout for help with, by level
c.missions =
{
    [10] = { 'rank 2 mission', 'BCNM 20', 'the Ghelsba hut fight', 'my rank 3 BC' },
    [25] = { 'Promyvion-Holla', 'Promyvion-Dem', 'the Waughroon BC', 'Ranperre\'s Tomb', 'my rank 4 mission' },
    [35] = { 'Promyvion-Mea', 'Fei\'Yin', 'my rank 5 mission', 'the Eldieme BC' },
    [45] = { 'the Shadow Lord fight', 'my AF fight', 'Promyvion-Vahzl', 'the Sea Serpent Grotto coffer' },
    [50] = { 'the Limit Break quest', 'Genkai 1', 'my AF coffers', 'CoP 3-5', 'Ro\'Maeve' },
    [55] = { 'Genkai 2', 'CoP 4-1', 'the Zilart missions', 'Assault' },
    [60] = { 'Genkai 3', 'the Sacrarium', 'CoP 4-3', 'Riverne', 'Assault' },
    [65] = { 'Genkai 4', 'Riverne B01', 'CoP 5-3', 'Ouryu', 'Nyzul Isle' },
    [70] = { 'Maat', 'Genkai 5', 'CoP 6-4', 'CoP 7-5', 'Salvage' },
    [75] = { 'Maat', 'CoP 8-4', 'Kirin pop', 'Nyzul Isle', 'Salvage', 'Assault' },
}

c.endgame = { 'Dynamis', 'Dynamis-Jeuno', 'Dynamis-Bastok', 'Sky', 'Sea', 'Limbus', 'Salvage', 'HNM', 'Kings',
    'Fafnir', 'Behemoth', 'Adamantoise', 'Assault', 'Nyzul Isle', 'Besieged', 'Kirin', 'Ouryu' }

-- Typical support jobs (era): main job -> subs
c.subs =
{
    WAR = { 'NIN', 'SAM', 'THF' }, MNK = { 'WAR', 'NIN', 'THF' }, WHM = { 'BLM', 'RDM', 'SMN' }, BLM = { 'WHM', 'RDM' },
    RDM = { 'WHM', 'BLM', 'NIN' }, THF = { 'NIN', 'WAR' }, PLD = { 'WAR', 'NIN', 'WHM', 'RDM' }, DRK = { 'SAM', 'WAR', 'THF' },
    BST = { 'WHM', 'NIN', 'WAR' }, BRD = { 'WHM', 'NIN' }, RNG = { 'NIN', 'WAR', 'SAM' }, SAM = { 'WAR', 'NIN', 'THF' },
    NIN = { 'WAR', 'THF', 'DRK' }, DRG = { 'SAM', 'WAR', 'WHM' }, SMN = { 'WHM', 'RDM' }, BLU = { 'WAR', 'NIN', 'RDM' },
    COR = { 'NIN', 'RNG', 'WHM' }, PUP = { 'WAR', 'THF', 'NIN' },
}
-- Jobs a party looks for
c.needs = { 'WHM', 'tank', 'healer', 'BRD', 'RDM', 'DD', 'BLM', 'puller', 'NIN tank', 'support', 'COR', 'WHM or RDM', 'BLM, WHM', 'DD and healer' }

c.lsWords1 = { 'Crimson', 'Silver', 'Azure', 'Starlight', 'Moonlit', 'Iron', 'Golden', 'Lucky', 'Wandering', 'Black', 'Hidden', 'Northern',
    'Sleeping', 'Rusty', 'Tidal', 'Ancient', 'Mythril', 'Emerald', 'Cosmic', 'Little' }
c.lsWords2 = { 'Wolves', 'Tonberries', 'Knights', 'Lanterns', 'Crabs', 'Chocobos', 'Roses', 'Blades', 'Mandragoras', 'Moogles',
    'Dragons', 'Wanderers', 'Ravens', 'Order', 'Company', 'Society', 'Family', 'Guild', 'Crew', 'Legion' }

-- ---------------------------------------------------------------------------------------------------------------
-- Shouts (whole area). Each group has a weight per kind of town (see crowds_chat.lua).
-- ---------------------------------------------------------------------------------------------------------------
c.shout = {}

c.shout.lfp =
{
    '{job}{lvl} LFP', 'LFP {job} {lvl}', '{job} {lvl}/{sub}{sublvl} LFP', 'LFP {job}{lvl} /{sub}, can go anywhere',
    '{job}{lvl} looking for party', 'LFP {job} {lvl}, have exp ring', '{job} {lvl} lfp {camp}?', 'LFP {job}{lvl}/{sub}{sublvl} pls /t',
    '{job}{lvl} lf exp party', 'lfp {job} {lvl} anywhere', '{job} {lvl}/{sub} LFP, need exp', 'LFP {job}{lvl}! /t me',
}
c.shout.lfp_heal = { 'WHM{lvl} LFP, have Raise', 'LFP WHM {lvl}/BLM, Cure III', 'RDM{lvl} LFP, Refresh', 'LFP BRD{lvl}, Ballad + Minuets' }

c.shout.lfm =
{
    'LFM {camp} {range} need {need}', 'LFM {range} {camp}, need {need} /t', 'party {range} @ {camp} need {need}',
    'need {need} for {camp} {range} pt', 'LFM {camp}! {range}, need {need}, pst', 'Seeking {need} for {range} party, {camp}',
    'LFM exp {range} need {need}, leaving now', '{range} pt need {need} {camp}, have tank', 'LF {need} {range} {camp} :)',
}
c.shout.selling =
{
    'Selling {item} {price}', 'WTS {item} {price} /t', 'Selling {item}, {price} obo', 'Crafted {item} for sale {price}, pst',
    'WTS {item} cheaper than AH: {price}', 'Selling {item} x1 {price}', 'Have {item}, {price}, /t if interested',
}
c.shout.buying =
{
    'WTB {item} /t', 'Buying {item}, paying {price}', 'Anyone selling {item}?', 'LF {item}, will pay {price}', 'WTB {item} pst',
}
c.shout.ls =
{
    '{ls} LS recruiting, all lvls, /t {self}', '{ls} is recruiting! casual LS, /t for pearl', 'LS recruiting: {ls}, we do {endgame}',
    '{ls} recruiting {lvl}+ for {endgame}, /t', 'Casual LS {ls} looking for members, any job', '{ls} LS: {endgame} on weekends, all welcome',
}
c.shout.help =
{
    'need help w/ {mission}, will pay', 'LF help {mission} /t', 'Anyone doing {mission}? need 1 more', 'Help with {mission}? pls /t',
    'LF 2 for {mission}', '{mission} anyone? going now', 'Forming {mission} run, need {need}',
}
c.shout.endgame =
{
    '{endgame} tonight, need {need}', 'LF {endgame} group, {job}75', '{endgame} shout: need {need} /t', 'LFM {endgame} 75 only, need {need}',
    'Merit pt {camp}, need {need}', 'LFM merits {camp}, need {need}', '{job}75 LFP merits', 'LFP merits {job}75/{sub}37',
}

-- ---------------------------------------------------------------------------------------------------------------
-- Say (only when you are close). Small talk, pairs (one bot says A, a neighbour answers B), outposts, greetings.
-- ---------------------------------------------------------------------------------------------------------------
c.say =
{
    'anyone know where the guild is?', 'brb, food', 'so laggy today', 'ugh, my party broke', 'gotta go repair my gear... oh wait',
    'where do I get the Signet thing?', 'AH prices are crazy today', 'anyone have a spare Echo Drops?', 'need to farm some gil',
    'my LS is dead tonight', 'just got my subjob!', 'finally hit {lvl}', 'who wants to go to {camp}?', 'k, ready', 'hmm',
    'anyone seen my party leader?', 'chocobo or walk... chocobo', 'I should skill up my {job} stuff', 'need a Teleport anyone?',
    'gonna buy {item} I think', 'zzz', 'nice weather in here', 'lol', 'one more party and I sleep', 'waiting on my LS',
}
c.pairs =
{
    { 'anyone have Raise?', 'not yet, WHM {lvl}' }, { 'where is everyone?', 'Jeuno probably' }, { 'u going to {camp}?', 'ya, after food' },
    { 'is {item} good?', 'for that level yes' }, { 'how much is {item}?', 'like {price}' }, { 'lfp?', 'ya, shouting now' },
    { 'did you get your AF?', 'still farming the coffer' }, { 'ready?', 'one sec, buying drinks' }, { 'gz on the level!', 'ty :)' },
    { 'any parties?', 'not for {job} lol' }, { 'you have a chocobo?', 'license only' }, { 'what sub should I level?', '{sub} for sure' },
}
c.outpost =
{
    'pulling', 'inc', 'resting', 'need a tank?', 'mp', 'one more pull', 'anyone selling Echo Drops?', 'heading back to town',
    'lol that crab', 'TP burn?', 'careful, aggro', 'oops, link', 'anyone want to duo?', 'sigh, no parties', 'camping here',
    'need a heal pls', 'ty for the cure', 'gonna sell this stuff', 'waiting on my pt', 'good exp here',
}
c.greet = { 'o/', 'hi', 'hey', 'hello', 'heya', '\\o', 'yo', 'sup', 'hi {name}', 'o/ {name}' }
c.react = { 'hi?', 'need something?', 'o/', 'hey there', '?', 'can I help?', 'hi {name}', 'sorry, afk', 'not selling, sorry', 'yes?' }

return c
