-----------------------------------
-- GOOMBA XI: LOGIN SETTINGS
-----------------------------------
-- Only the keys Goomba XI changes. Defaults: settings/default/login.lua.
-----------------------------------

xi = xi or {}
xi.settings = xi.settings or {}

xi.settings.login =
{
    -- Accounts are created on the website (<website>/register), which
    -- checks the e-mail address and the rules agreement first.
    ACCOUNT_CREATION = false,

    -- 0 = no limit on characters logged in from the same IP.
    LOGIN_LIMIT = 0,
}
