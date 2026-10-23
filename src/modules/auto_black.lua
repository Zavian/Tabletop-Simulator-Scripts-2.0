-- When the table loads, moves the GM to the Black seat. Put this script on a
-- small token left on the table. The GM is matched by Steam ID, and nobody is
-- moved if someone else is already sitting in Black. It runs once per load, so
-- changing color afterwards sticks.
local GM_STEAM_ID = "76561197999974068"
local LOAD_DELAY_SECONDS = 2

local function claimBlack()
    if Player["Black"].seated then return end
    for _, p in ipairs(Player.getPlayers()) do
        if p.steam_id == GM_STEAM_ID and p.color ~= "Black" then
            p.changeColor("Black")
        end
    end
end

function onLoad()
    Wait.time(claimBlack, LOAD_DELAY_SECONDS)
end
