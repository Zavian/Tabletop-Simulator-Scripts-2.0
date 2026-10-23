-- Moves the GM to the Black seat whenever they join the table. Put this script
-- on a small token left on the table. The GM is matched by Steam ID, and
-- nobody is moved if someone else is already sitting in Black.
local GM_STEAM_ID = "76561197999974068"
local CHECK_SECONDS = 2

local function claimBlack()
    if Player["Black"].seated then return end
    for _, p in ipairs(Player.getPlayers()) do
        if p.steam_id == GM_STEAM_ID and p.color ~= "Black" then
            p.changeColor("Black")
        end
    end
end

function onLoad()
    Wait.time(claimBlack, CHECK_SECONDS, -1)
end
