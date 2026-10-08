-- Mirror Pin
--
-- Object script for a board mirror master pin. Drop the object on a board, then
-- right-click it for "Spawn slave". All the linking logic lives in Global
-- (src/core/board_mirror.lua); this tags the object, hides it from everyone but
-- Black as soon as it loads (taken out of a bag, pasted, unbundled or on game
-- load), and tells Global about it.

require("src.data.config")

local utils = require("src.core.utils")

function onLoad()
    self.addTag(OBJECT_TAGS.board_mirror_master)
    self.setInvisibleTo(utils.hideFromPlayersArray())
    Global.call("boardMirror_registerMaster", { guid = self.getGUID() })
end
