-- Mirror Pin
--
-- Object script for a board mirror master pin. Drop the object on a board, then
-- right-click it for "Spawn slave". All the linking logic lives in Global
-- (src/core/board_mirror.lua); this tags the object, hides it from everyone but
-- Black as soon as it loads, and gives it "Mirror: initialize" to set up its
-- link (e.g. after unbundling).

require("src.data.config")

local utils = require("src.core.utils")

function onLoad()
    self.addTag(OBJECT_TAGS.board_mirror_master)
    self.setInvisibleTo(utils.hideFromPlayersArray())
    -- Once initialized, Global replaces this menu with the full one (which
    -- keeps "Mirror: initialize").
    self.addContextMenuItem("Mirror: initialize", function(player_color)
        Global.call("boardMirror_init", { guid = self.getGUID(), player_color = player_color })
    end)
end
