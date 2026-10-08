-- Mirror Pin
--
-- Object script for a board mirror master pin. Drop the object on a board, then
-- right-click it for "Spawn slave" / "Spawn shadow slave". All the logic lives
-- in Global (src/core/board_mirror.lua); this only tags the object and tells
-- Global about it.

require("src.data.config")

function onLoad()
    self.addTag(OBJECT_TAGS.board_mirror_master)
    Global.call("boardMirror_registerMaster", { guid = self.getGUID() })
end
