-----------------------------------
-- Goomba XI: living-world settings (read by crowds.lua).
-- Edit, then: sudo goomba apply && sudo goomba restart game. In game you can also change these for
-- the current run with !crowd (towns) and !crowd field (field parties); this file sets the defaults.
-----------------------------------
return
{
    enabled      = true,     -- ambient crowds in towns and outposts
    per_zone     = 24,       -- crowd size in a big town (small towns 60%, outposts 25%); max 40
    turnover     = 0.012,    -- chance per decision that one leaves and someone new arrives
    emote_text   = false,    -- false: emotes are motion only; true: also a chat line ("X waves.")

    chat         = true,     -- the crowd shouts and chatters (canned lines, crowds_chat_data.lua)
    chat_amount  = 'normal', -- 'quiet' | 'normal' | 'busy'
    chat_ai      = false,    -- AI-written lines (needs the Ollama sidecar); off on this server

    field        = true,     -- field parties: adventurer camps that pull, tank, heal and skillchain
    field_parties = 1,       -- camps per field area (0-3)

    disabled     = {},       -- zone ids to leave out, e.g. { [230] = true } for Southern San d'Oria
}
