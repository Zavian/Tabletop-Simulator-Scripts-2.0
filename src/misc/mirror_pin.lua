-- Mirror Pin
--
-- Put this script on any object to make it a board mirror master pin. Drop it
-- on a board, then right-click it for "Spawn slave" / "Spawn shadow slave".
-- All the logic lives in Global (src/core/board_mirror.lua); this only tags the
-- object and tells Global about it.

function onLoad()
    self.addTag("board_mirror_master")
    Global.call("boardMirror_registerMaster", { guid = self.getGUID() })
end
