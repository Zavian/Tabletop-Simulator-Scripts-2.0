-- Board Mirror
--
-- Mirrors tokens tagged movement_measurement from one board onto others, as
-- flat shadows that follow the token while it is carried. Neither the boards
-- nor the tokens get any script: everything lives here, in Global.
--
-- Pins. Give any object the script in src/modules/mirror_pin.lua and drop it on
-- a board: that object is now a master pin and the board a master. Right-click
-- the master pin and "Spawn slave" (a script-free copy of the master), drop the
-- slave on another board: tokens on the master board now get a shadow on that
-- board. A master can have any number of slaves, and a board can carry any
-- number of pins. The board a pin belongs to is the first locked object under it
-- (a ray cast straight down), so moving a pin to another board re-links it.
-- Every master has a color worked out from its GUID and each of its slaves gets
-- its own: pins are tinted with theirs and named after the other end,
-- "Master (red, teal)" and "Slave (navy)".
--
-- Shadows. A flat disc the size of the token's footprint, in the token's color
-- brought to full brightness: blue for player tokens, the token's own tint
-- (enemy, ally, neutral) for the rest, mixed with pink when it is face down. It
-- carries the token's name, is locked, not interactable and has its colliders
-- turned off. It exists while its token is over the master board, and is
-- highlighted in the holder's color while the token is carried. It is
-- invisible to whoever its token is invisible to, and a slave can be set to
-- "GM only", hiding its shadows from everyone but Black as well.
--
-- Pings. Pinging a shadow pings its token and the other way round; pinging a
-- slave pin pings its master and the other way round.
--
-- Updates. Picking up, dropping, flipping or spinning a token follows it every
-- TICK until it settles. A HEARTBEAT catches the rest: tokens moved, spawned,
-- renamed or retinted by scripts, boards that moved, and stray shadows brought
-- back by undo.
--
-- Mapping. A position is taken into the master board's local space and back out
-- of the slave board's, so the two boards can sit anywhere, at any rotation and
-- scale. Height is not mapped: the shadow lies on the slave board's surface,
-- raised by however far the token was resting above the master board's surface
-- (stairs, platforms inside a diorama).
--
-- Links are kept in SAVED_DATA.BOARD_MIRROR, keyed by pin GUID. Shadows are not
-- saved: on load the old ones are deleted and rebuilt.

local utils = require("src.core.utils")
require("src.data.config")

local BoardMirror = {}

-- Click target for the ghosts' name labels, which are buttons owned by Global.
function boardMirror_noop() end

local TICK = 0.05
local SHADOW_THICKNESS = 0.05
local LABEL_HEIGHT = 0.15
local HEARTBEAT = 1

-- Pin colors: bright hues, so pins and names read well on dark boards.
local PIN_COLORS = {
    { name = "red",     hex = "#FF4040" },
    { name = "orange",  hex = "#FF9A2E" },
    { name = "yellow",  hex = "#FFE53B" },
    { name = "lime",    hex = "#B6FF3B" },
    { name = "green",   hex = "#3BFF6A" },
    { name = "mint",    hex = "#3BFFC4" },
    { name = "cyan",    hex = "#3BE8FF" },
    { name = "sky",     hex = "#3B9DFF" },
    { name = "blue",    hex = "#5B5BFF" },
    { name = "violet",  hex = "#A35BFF" },
    { name = "magenta", hex = "#F03BFF" },
    { name = "pink",    hex = "#FF5BA8" },
}
local PIN_COLOR_BY_NAME = {}
for _, c in ipairs(PIN_COLORS) do PIN_COLOR_BY_NAME[c.name] = c end

local PLAYER_COLOR = CONFIG.palette.blue.rgb
local FLIPPED_COLOR = CONFIG.palette.fuchsia.rgb

-- Saved state:
--   masters[pinGuid] = { board = boardGuid }
--   slaves[pinGuid]  = { master = pinGuid, board = boardGuid, color = PIN_COLORS name,
--                        gm_only = true when only Black sees its shadows }
--   hidden[boardGuid] = true when that board's pins are hidden
local state = nil

-- Runtime only:
--   ghosts[tokenGuid][slavePinGuid] = { obj = Object|nil, name = string, color = hex string,
--                                       highlight = player color it is highlighted in,
--                                       scale = token scale it was sized for }
--   timers[tokenGuid] = Wait id of the follow loop
--   rest_offset[tokenGuid] = how far the token last rested above its master board
--   last_seen[guid] = what a token or board looked like when last synced
--   ghost_hidden[ghostGuid] = the player colors a shadow is invisible to
local ghosts = {}
local timers = {}
local rest_offset = {}
local last_seen = {}
local ghost_hidden = {}
local board_menus = {}
local echoing = false

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------

local function isPin(obj)
    return obj.hasTag(OBJECT_TAGS.board_mirror_master) or obj.hasTag(OBJECT_TAGS.board_mirror_slave)
end

local function isGhost(obj)
    return obj.hasTag(OBJECT_TAGS.board_mirror_ghost)
end

local function isTracked(obj)
    return obj.hasTag(OBJECT_TAGS.movement_measurement) and not isGhost(obj)
end

local function save()
    SAVED_DATA.BOARD_MIRROR = state
end

local function castDown(origin)
    local hits = Physics.cast({
        origin = origin,
        direction = { 0, -1, 0 },
        type = 1,
        max_distance = 200,
    }) or {}
    table.sort(hits, function(a, b) return a.distance < b.distance end)
    return hits
end

-- The board a pin sits on: the first locked object under it that is not a
-- pin, a ghost, a tracked token or the table itself.
local function boardUnderPin(pin)
    local tableObj = Tables.getTableObject()
    for _, hit in ipairs(castDown(pin.getPosition() + Vector(0, 0.5, 0))) do
        local o = hit.hit_object
        if o and o ~= pin and o ~= tableObj and not isPin(o) and not isGhost(o)
            and not isTracked(o) and o.getLock() then
            return o
        end
    end
    return nil
end

-- The closest master board under a token, and the point where the ray met it.
local function masterBoardUnder(token)
    local masters = {}
    for _, m in pairs(state.masters) do
        if m.board then masters[m.board] = true end
    end
    for _, hit in ipairs(castDown(token.getPosition() + Vector(0, 0.5, 0))) do
        local o = hit.hit_object
        if o and o ~= token and masters[o.getGUID()] then
            return o, hit.point
        end
    end
    return nil, nil
end

-- Where a ray straight down at (x, z) meets a given board.
local function surfaceOf(board, x, z)
    local b = board.getBounds()
    local top = b.center.y + b.size.y / 2 + 1
    for _, hit in ipairs(castDown(Vector(x, top, z))) do
        if hit.hit_object == board then
            return hit.point.y
        end
    end
    return nil
end

local function bottomOffset(obj)
    -- Distance from the object's pivot down to its lowest point.
    local b = obj.getBounds()
    return obj.getPosition().y - (b.center.y - b.size.y / 2)
end

local function disableColliders(obj)
    pcall(function()
        local function walk(go)
            for _, c in ipairs(go.getComponents() or {}) do
                if string.find(c.name, "Collider") then
                    pcall(function() c.set("enabled", false) end)
                end
            end
            for _, child in ipairs(go.getChildren() or {}) do
                walk(child)
            end
        end
        walk(obj)
    end)
end

-- Scales a color up until its strongest channel is full: same hue and
-- saturation, as bright as it goes. Black and near-black become light gray.
local function brighten(r, g, b)
    local top = math.max(r, g, b)
    if top < 0.05 then return Color(0.9, 0.9, 0.9) end
    return Color(r / top, g / top, b / top)
end

-- A flipped token's shadow is its color mixed halfway with pink, so it stands
-- out from the ones still face up.
local function tokenColor(token)
    local c = token.hasTag(OBJECT_TAGS.player) and PLAYER_COLOR or token.getColorTint()
    if token.is_face_down then
        return brighten(
            (c.r + FLIPPED_COLOR.r) / 2,
            (c.g + FLIPPED_COLOR.g) / 2,
            (c.b + FLIPPED_COLOR.b) / 2
        )
    end
    return brighten(c.r, c.g, c.b)
end

-- The player colors a token is invisible to. TTS's own list when this build
-- exposes it; otherwise the monster UI's is_visible(), the same source the
-- flying module uses: hidden means hidden from everyone but Black.
local function tokenHiddenFrom(token)
    local ok, list = pcall(function() return token.getInvisibleTo() end)
    if ok and type(list) == "table" then return list end
    if token.getVar("is_visible") then
        local called, visible = pcall(function() return token.call("is_visible") end)
        if called and visible == false then return utils.hideFromPlayersArray() end
    end
    return {}
end

-- A shadow is hidden from whoever its token is hidden from, plus every player
-- but Black when its slave is GM only.
local function shadowHiddenFrom(token, link)
    local seen, list = {}, {}
    local function add(colors)
        for _, c in ipairs(colors) do
            if not seen[c] then
                seen[c] = true
                table.insert(list, c)
            end
        end
    end
    add(tokenHiddenFrom(token))
    if link and link.gm_only then add(utils.hideFromPlayersArray()) end
    table.sort(list)
    return list
end

local function tokenName(token)
    local name = token.getName()
    if name == nil or name == "" then return "" end
    return name
end

------------------------------------------------------------------------------
-- Ghosts
------------------------------------------------------------------------------

local function setLabel(ghost, name)
    ghost.clearButtons()
    if name == "" then return end
    local scale = ghost.getScale()
    local b = ghost.getBoundsNormalized()
    local top = (b.center.y - ghost.getPosition().y + b.size.y / 2) / scale.y
    ghost.createButton({
        click_function = "boardMirror_noop",
        function_owner = Global,
        label = name,
        position = { 0, top + LABEL_HEIGHT / scale.y, 0 },
        rotation = { 0, 180, 0 },
        scale = { 0.5 / scale.x, 1 / scale.y, 0.5 / scale.z },
        width = 0,
        height = 0,
        font_size = 300,
        font_color = { 1, 1, 1 },
    })
end

local function destroyGhost(tokenGuid, slaveGuid)
    local byToken = ghosts[tokenGuid]
    if not byToken or not byToken[slaveGuid] then return end
    local g = byToken[slaveGuid]
    byToken[slaveGuid] = nil
    if g.obj and not g.obj.isDestroyed() then
        ghost_hidden[g.obj.getGUID()] = nil
        g.obj.destruct()
    end
end

local function destroyGhostsOfToken(tokenGuid)
    if not ghosts[tokenGuid] then return end
    for slaveGuid in pairs(ghosts[tokenGuid]) do
        destroyGhost(tokenGuid, slaveGuid)
    end
    ghosts[tokenGuid] = nil
end

local function destroyGhostsOfSlave(slaveGuid)
    for tokenGuid in pairs(ghosts) do
        destroyGhost(tokenGuid, slaveGuid)
    end
end

local function scaleFactor(masterBoard, slaveBoard)
    return slaveBoard.getScale().x / masterBoard.getScale().x
end

-- Moves an existing ghost to mirror the token.
local function placeGhost(g, token, masterBoard, slaveBoard, link)
    local obj = g.obj
    if not obj or obj.isDestroyed() then return end

    local hidden = shadowHiddenFrom(token, link)
    local hiddenKey = table.concat(hidden, ",")
    if g.hidden ~= hiddenKey then
        g.hidden = hiddenKey
        obj.setInvisibleTo(hidden)
        ghost_hidden[obj.getGUID()] = hidden
    end

    local pos = token.getPosition()
    local world = slaveBoard.positionToWorld(masterBoard.positionToLocal(pos))
    local factor = scaleFactor(masterBoard, slaveBoard)
    local floor = surfaceOf(slaveBoard, world.x, world.z) or world.y
    local raise = (rest_offset[token.getGUID()] or 0) * factor
    world.y = floor + raise + g.bottom + 0.01

    local rot = token.getRotation()
    local yaw = rot.y - masterBoard.getRotation().y + slaveBoard.getRotation().y
    obj.setRotation(Vector(0, yaw, 0))
    obj.setPosition(world)

    -- Highlighted in the holder's color for as long as the token is carried.
    local holder = token.held_by_color
    if holder and g.highlight ~= holder then
        g.highlight = holder
        obj.highlightOn(Color.fromString(holder))
    elseif holder == nil and g.highlight then
        g.highlight = nil
        obj.highlightOff()
    end

    local color = tokenColor(token)
    if g.color ~= color:toHex() then
        g.color = color:toHex()
        obj.setColorTint(color)
    end

    local name = tokenName(token)
    if name ~= g.name then
        g.name = name
        setLabel(obj, name)
    end
end

local function spawnGhost(token, slaveGuid, masterBoard, slaveBoard)
    local tokenGuid = token.getGUID()
    local factor = scaleFactor(masterBoard, slaveBoard)
    local g = { obj = nil, name = nil, color = nil, bottom = 0, scale = token.getScale().x }
    ghosts[tokenGuid] = ghosts[tokenGuid] or {}
    ghosts[tokenGuid][slaveGuid] = g

    spawnObject({
        type = "Checker_white",
        position = slaveBoard.positionToWorld(masterBoard.positionToLocal(token.getPosition())),
        sound = false,
        callback_function = function(obj)
            -- The link, the token or this ghost entry may be gone by now.
            if ghosts[tokenGuid] == nil or ghosts[tokenGuid][slaveGuid] ~= g or token.isDestroyed() then
                obj.destruct()
                return
            end
            obj.addTag(OBJECT_TAGS.board_mirror_ghost)
            obj.setName(tokenName(token))
            obj.setLock(true)
            obj.interactable = false
            obj.use_gravity = false
            disableColliders(obj)
            -- Hidden until placeGhost() sets who may see it.
            obj.setInvisibleTo(utils.allPlayersArray())

            -- Size the disc to the token's footprint.
            local tb = token.getBoundsNormalized()
            local want = math.max(tb.size.x, tb.size.z) * factor
            local have = obj.getBoundsNormalized()
            if have.size.x > 0 then
                local s = want / have.size.x
                obj.setScale(Vector(s, SHADOW_THICKNESS / math.max(have.size.y, 0.001), s))
            end

            g.obj = obj
            g.bottom = bottomOffset(obj)
            BoardMirror.sync(token)
        end,
    })
end

-- Brings a token's ghosts up to date: creates the missing ones, moves them,
-- and removes the ones for boards it is no longer over.
function BoardMirror.sync(token)
    if state == nil or token == nil or token.isDestroyed() then return end
    local tokenGuid = token.getGUID()
    local masterBoard, hitPoint = masterBoardUnder(token)

    if masterBoard and hitPoint and token.held_by_color == nil and token.resting then
        local b = token.getBounds()
        rest_offset[tokenGuid] = math.max(0, (b.center.y - b.size.y / 2) - hitPoint.y)
    end

    local wanted = {}
    if masterBoard then
        local masterBoardGuid = masterBoard.getGUID()
        for slaveGuid, link in pairs(state.slaves) do
            local master = state.masters[link.master]
            if master and master.board == masterBoardGuid and link.board and link.board ~= masterBoardGuid then
                local slaveBoard = getObjectFromGUID(link.board)
                if slaveBoard then
                    wanted[slaveGuid] = true
                    local g = ghosts[tokenGuid] and ghosts[tokenGuid][slaveGuid]
                    -- A shadow's size is set when it spawns: respawn it on a rescale.
                    if g and math.abs(g.scale - token.getScale().x) > 0.001 then
                        destroyGhost(tokenGuid, slaveGuid)
                        g = nil
                    end
                    if g == nil then
                        spawnGhost(token, slaveGuid, masterBoard, slaveBoard)
                    else
                        placeGhost(g, token, masterBoard, slaveBoard, link)
                    end
                end
            end
        end
    end

    if ghosts[tokenGuid] then
        for slaveGuid in pairs(ghosts[tokenGuid]) do
            if not wanted[slaveGuid] then destroyGhost(tokenGuid, slaveGuid) end
        end
    end
end

function BoardMirror.syncAll()
    for _, obj in ipairs(getObjectsWithTag(OBJECT_TAGS.movement_measurement)) do
        if not isGhost(obj) then BoardMirror.sync(obj) end
    end
end

local function stopFollowing(tokenGuid)
    if timers[tokenGuid] then
        Wait.stop(timers[tokenGuid])
        timers[tokenGuid] = nil
    end
end

-- What a token looks like, as far as its shadows care.
local function tokenSignature(token)
    local p, r = token.getPosition(), token.getRotation()
    return string.format("%.2f %.2f %.2f %.0f %.0f %.0f %.3f %s %s %s %s",
        p.x, p.y, p.z, r.x, r.y, r.z, token.getScale().x,
        token.getColorTint():toHex(), tostring(token.is_face_down), token.getName(),
        table.concat(tokenHiddenFrom(token), ","))
end

local function boardSignature(board)
    local p, r = board.getPosition(), board.getRotation()
    return string.format("%.2f %.2f %.2f %.0f %.0f %.0f %.3f",
        p.x, p.y, p.z, r.x, r.y, r.z, board.getScale().x)
end

-- Follows a token every TICK while it is held, falling or smooth-moving.
local function follow(token)
    local tokenGuid = token.getGUID()
    if timers[tokenGuid] then return end
    timers[tokenGuid] = Wait.time(function()
        if token.isDestroyed() then
            stopFollowing(tokenGuid)
            destroyGhostsOfToken(tokenGuid)
            return
        end
        BoardMirror.sync(token)
        if token.held_by_color == nil and token.resting and not token.isSmoothMoving() then
            stopFollowing(tokenGuid)
            last_seen[tokenGuid] = tokenSignature(token)
        end
    end, TICK, -1)
end

-- Once a second, catches what the pick-up/drop events miss: tokens moved,
-- spawned, renamed or retinted by scripts, boards that were moved, and shadows
-- brought back by undo. Only compares cheap signatures; tokens that changed are
-- handed to follow().
local function heartbeat()
    if state == nil or next(state.masters) == nil then return end

    local boardMoved = false
    local boards = {}
    for _, entry in pairs(state.masters) do if entry.board then boards[entry.board] = true end end
    for _, entry in pairs(state.slaves) do if entry.board then boards[entry.board] = true end end
    for guid in pairs(boards) do
        local board = getObjectFromGUID(guid)
        if board then
            local sig = boardSignature(board)
            if last_seen[guid] ~= nil and last_seen[guid] ~= sig then boardMoved = true end
            last_seen[guid] = sig
        end
    end

    for _, token in ipairs(getObjectsWithTag(OBJECT_TAGS.movement_measurement)) do
        local guid = token.getGUID()
        if not isGhost(token) and timers[guid] == nil then
            local sig = tokenSignature(token)
            if boardMoved or last_seen[guid] ~= sig then
                last_seen[guid] = sig
                follow(token)
            end
        end
    end

    local known = {}
    for _, byToken in pairs(ghosts) do
        for _, g in pairs(byToken) do
            if g.obj and not g.obj.isDestroyed() then known[g.obj.getGUID()] = true end
        end
    end
    for _, obj in ipairs(getObjectsWithTag(OBJECT_TAGS.board_mirror_ghost)) do
        if not known[obj.getGUID()] then obj.destruct() end
    end
end

------------------------------------------------------------------------------
-- Pins and menus
------------------------------------------------------------------------------

local addPinMenu
local addBoardMenu

local function masterColor(masterGuid)
    local hash = 0
    for i = 1, #masterGuid do
        hash = (hash * 31 + string.byte(masterGuid, i)) % 1000003
    end
    return PIN_COLORS[(hash % #PIN_COLORS) + 1].name
end

-- The first color not taken by the master or by its other slaves.
local function freeSlaveColor(masterGuid)
    local used = { [masterColor(masterGuid)] = true }
    for _, link in pairs(state.slaves) do
        if link.master == masterGuid and link.color then used[link.color] = true end
    end
    for _, c in ipairs(PIN_COLORS) do
        if not used[c.name] then return c.name end
    end
    return PIN_COLORS[1].name
end

local function colored(key, text)
    return "[" .. string.sub(PIN_COLOR_BY_NAME[key].hex, 2) .. "]" .. text .. "[-]"
end

local function tintPin(pin, key)
    pin.setColorTint(Color.fromHex(PIN_COLOR_BY_NAME[key].hex))
end

-- Names and tints a master and all its slaves.
local function refreshPins(masterGuid)
    local own = masterColor(masterGuid)
    local slaveGuids = {}
    for guid, link in pairs(state.slaves) do
        if link.master == masterGuid then table.insert(slaveGuids, guid) end
    end
    table.sort(slaveGuids)

    local names = {}
    for _, guid in ipairs(slaveGuids) do
        local link = state.slaves[guid]
        table.insert(names, colored(link.color, link.color))
        local pin = getObjectFromGUID(guid)
        if pin then
            local suffix = link.gm_only and " - GM only" or ""
            pin.setName(colored(link.color, "Slave") .. " (" .. colored(own, own) .. ")" .. suffix)
            pin.setDescription("Board mirror slave. Drop it on the board the "
                .. colored(own, own) .. " master's tokens should show up on.")
            tintPin(pin, link.color)
        end
    end

    local master = getObjectFromGUID(masterGuid)
    if master then
        master.setName(colored(own, "Master") .. " (" .. table.concat(names, ", ") .. ")")
        master.setDescription("Board mirror master. Drop it on a board, then right-click "
            .. "> Spawn slave and drop the slave on the board to mirror onto.")
        tintPin(master, own)
    end
end

local function applyHidden(pin, hidden)
    if hidden then
        pin.setLock(true)
        pin.interactable = false
        pin.setInvisibleTo(utils.allPlayersArray())
    else
        pin.interactable = true
        pin.setInvisibleTo({})
    end
end

local function boardLabel(board)
    local name = board.getName()
    if name == nil or name == "" then return "board " .. board.getGUID() end
    return name
end

-- Works out which board a pin is on. With a player color, tells that player
-- when the pin's board changed, or that it found none.
local function placePin(pin, player_color)
    local board = boardUnderPin(pin)
    local guid = pin.getGUID()
    local entry = state.masters[guid] or state.slaves[guid]
    if not entry then return end
    local before = entry.board
    entry.board = board and board.getGUID() or nil
    if player_color then
        local what = state.masters[guid] and "Master" or "Slave"
        if board == nil then
            utils.warning(what .. " pin is not on a board: drop it on a locked board to link it.", player_color)
        elseif entry.board ~= before then
            utils.success(what .. " pin linked to " .. boardLabel(board) .. ".", player_color)
        end
    end
    if board then
        addBoardMenu(board)
        if state.hidden[entry.board] then applyHidden(pin, true) end
    end
    save()
end

-- A slave is a copy of its master without the script, so it cannot register
-- itself as a master too.
local function spawnSlave(masterPin)
    local masterGuid = masterPin.getGUID()
    local data = masterPin.getData()
    data.GUID = nil
    data.LuaScript = ""
    data.LuaScriptState = ""
    data.XmlUI = ""
    data.Tags = { OBJECT_TAGS.board_mirror_slave }
    data.Locked = false
    data.States = nil
    data.ChildObjects = nil
    spawnObjectData({
        data = data,
        position = masterPin.getPosition() + Vector(1.5, 1, 0),
        callback_function = function(pin)
            state.slaves[pin.getGUID()] = {
                master = masterGuid,
                board = nil,
                color = freeSlaveColor(masterGuid),
            }
            refreshPins(masterGuid)
            addPinMenu(pin)
            save()
        end,
    })
end

local function setGmOnly(slaveGuid, gm_only)
    local link = state.slaves[slaveGuid]
    if not link then return end
    link.gm_only = gm_only or nil
    destroyGhostsOfSlave(slaveGuid)
    refreshPins(link.master)
    local pin = getObjectFromGUID(slaveGuid)
    if pin then addPinMenu(pin) end
    save()
    BoardMirror.syncAll()
end

local function removeSlave(slaveGuid)
    local link = state.slaves[slaveGuid]
    if not link then return end
    state.slaves[slaveGuid] = nil
    destroyGhostsOfSlave(slaveGuid)
    local pin = getObjectFromGUID(slaveGuid)
    if pin then pin.destruct() end
    refreshPins(link.master)
    save()
end

local function removeMaster(masterGuid)
    for slaveGuid, link in pairs(state.slaves) do
        if link.master == masterGuid then removeSlave(slaveGuid) end
    end
    state.masters[masterGuid] = nil
    save()
end

addPinMenu = function(pin)
    pin.clearContextMenu()
    local guid = pin.getGUID()
    if state.masters[guid] then
        pin.addContextMenuItem("Spawn slave", function() spawnSlave(pin) end)
        pin.addContextMenuItem("Remove all slaves", function()
            for slaveGuid, link in pairs(state.slaves) do
                if link.master == guid then removeSlave(slaveGuid) end
            end
        end)
    elseif state.slaves[guid] then
        if state.slaves[guid].gm_only then
            pin.addContextMenuItem("Shadows: show to all", function() setGmOnly(guid, false) end)
        else
            pin.addContextMenuItem("Shadows: GM only", function() setGmOnly(guid, true) end)
        end
        pin.addContextMenuItem("Unlink", function() removeSlave(guid) end)
    end
end

local function pinsOnBoard(boardGuid)
    local pins = {}
    for guid, m in pairs(state.masters) do
        if m.board == boardGuid then table.insert(pins, guid) end
    end
    for guid, s in pairs(state.slaves) do
        if s.board == boardGuid then table.insert(pins, guid) end
    end
    return pins
end

local function setBoardHidden(boardGuid, hidden)
    state.hidden[boardGuid] = hidden or nil
    for _, guid in ipairs(pinsOnBoard(boardGuid)) do
        local pin = getObjectFromGUID(guid)
        if pin then applyHidden(pin, hidden) end
    end
    save()
end

-- Global can add menu items to any object; the callbacks run here, so the
-- boards themselves never need a script. Script-added items do not survive a
-- reload, which is why init() adds them again.
addBoardMenu = function(board)
    local guid = board.getGUID()
    if board_menus[guid] then return end
    board_menus[guid] = true
    board.addContextMenuItem("Mirror: hide pins", function() setBoardHidden(guid, true) end)
    board.addContextMenuItem("Mirror: show pins", function() setBoardHidden(guid, false) end)
end

------------------------------------------------------------------------------
-- Entry points (called from main.lua)
------------------------------------------------------------------------------

function BoardMirror.init()
    state = SAVED_DATA.BOARD_MIRROR or {}
    state.masters = state.masters or {}
    state.slaves = state.slaves or {}
    state.hidden = state.hidden or {}

    -- Ghosts are rebuilt rather than restored.
    for _, obj in ipairs(getObjectsWithTag(OBJECT_TAGS.board_mirror_ghost)) do
        obj.destruct()
    end

    for guid in pairs(state.masters) do
        if getObjectFromGUID(guid) == nil then state.masters[guid] = nil end
    end
    -- Objects that got the pin script while Global was not listening.
    for _, obj in ipairs(getObjectsWithTag(OBJECT_TAGS.board_mirror_master)) do
        if state.masters[obj.getGUID()] == nil then
            state.masters[obj.getGUID()] = { board = nil }
        end
    end
    for guid, link in pairs(state.slaves) do
        if getObjectFromGUID(guid) == nil or state.masters[link.master] == nil then
            state.slaves[guid] = nil
        elseif type(link.color) ~= "string" or PIN_COLOR_BY_NAME[link.color] == nil then
            link.color = nil
            link.color = freeSlaveColor(link.master)
        end
    end

    local function restore(guid, entry)
        local pin = getObjectFromGUID(guid)
        addPinMenu(pin)
        if entry.board == nil then placePin(pin) end
        if entry.board then
            local board = getObjectFromGUID(entry.board)
            if board then addBoardMenu(board) end
            if state.hidden[entry.board] then applyHidden(pin, true) end
        end
    end
    for guid, entry in pairs(state.masters) do restore(guid, entry) end
    for guid, entry in pairs(state.slaves) do restore(guid, entry) end
    for guid in pairs(state.masters) do refreshPins(guid) end
    save()

    -- Let the deleted ghosts finish going before spawning new ones.
    Wait.frames(BoardMirror.syncAll, 2)

    if BoardMirror.heartbeat_id == nil then
        BoardMirror.heartbeat_id = Wait.time(heartbeat, HEARTBEAT, -1)
    end
end

-- Called by an object running the mirror pin script, from its onLoad. Before
-- init() has run this is a no-op: init() finds the pin by its tag instead.
function BoardMirror.registerMaster(guid)
    if state == nil then return end
    local pin = getObjectFromGUID(guid)
    if pin == nil then return end
    if state.masters[guid] == nil then
        state.masters[guid] = { board = nil }
    end
    addPinMenu(pin)
    refreshPins(guid)
    Wait.condition(function()
        if pin.isDestroyed() then return end
        placePin(pin)
        BoardMirror.syncAll()
    end, function() return pin.isDestroyed() or pin.resting end, 5)
end

function BoardMirror.onPickUp(obj)
    if state == nil then return end
    if isTracked(obj) then follow(obj) end
end

function BoardMirror.onDrop(obj, player_color)
    if state == nil then return end
    if isTracked(obj) then
        follow(obj)
    elseif isPin(obj) then
        -- Re-detect the board once the pin has landed.
        Wait.condition(function()
            if obj.isDestroyed() then return end
            placePin(obj, player_color)
            BoardMirror.syncAll()
        end, function() return obj.isDestroyed() or obj.resting end, 5)
    end
end

------------------------------------------------------------------------------
-- Pings
------------------------------------------------------------------------------

-- Whether a ping landed on an object: within its footprint across, and no
-- further than a little above its top or below its bottom. A shadow has no
-- collider, so a ping on it lands on the board right under it.
local function pingHits(position, obj)
    if obj == nil or obj.isDestroyed() then return false end
    local b = obj.getBounds()
    local dx, dz = position.x - b.center.x, position.z - b.center.z
    local radius = math.max(b.size.x, b.size.z) / 2
    local half = b.size.y / 2 + 0.5
    return dx * dx + dz * dz <= radius * radius and math.abs(position.y - b.center.y) <= half
end

-- Our own pings may come back through onPlayerPing; ignore them for a moment.
-- Pings are not echoed onto anything the pinging player cannot see.
local function hiddenFromPlayer(obj, player_color)
    local list = ghost_hidden[obj.getGUID()]
    if list == nil and isTracked(obj) then list = tokenHiddenFrom(obj) end
    for _, c in ipairs(list or {}) do
        if c == player_color then return true end
    end
    return false
end

local function echoPing(player_color, targets)
    echoing = true
    for _, obj in ipairs(targets) do
        if not hiddenFromPlayer(obj, player_color) then
            utils.pingObject(player_color, obj.getGUID())
        end
    end
    Wait.frames(function() echoing = false end, 10)
end

-- The pin a ping landed on, if any. Hidden pins do not count.
local function pingedPin(position, object)
    local function visible(guid)
        local entry = state.masters[guid] or state.slaves[guid]
        return entry and not (entry.board and state.hidden[entry.board])
    end
    if object and visible(object.getGUID()) then
        return object.getGUID()
    end
    for guid in pairs(state.masters) do
        if visible(guid) and pingHits(position, getObjectFromGUID(guid)) then return guid end
    end
    for guid in pairs(state.slaves) do
        if visible(guid) and pingHits(position, getObjectFromGUID(guid)) then return guid end
    end
    return nil
end

-- Pinging a shadow pings its token; pinging a token pings all its shadows.
-- Pinging a slave pin pings its master; pinging a master pings all its slaves.
function BoardMirror.onPing(player, position, object)
    if state == nil or echoing then return end
    position = Vector(position)

    local pinGuid = pingedPin(position, object)
    if pinGuid then
        local targets = {}
        if state.slaves[pinGuid] then
            table.insert(targets, getObjectFromGUID(state.slaves[pinGuid].master))
        else
            for guid, link in pairs(state.slaves) do
                if link.master == pinGuid then table.insert(targets, getObjectFromGUID(guid)) end
            end
        end
        if #targets > 0 then echoPing(player.color, targets) end
        return
    end

    for tokenGuid, byToken in pairs(ghosts) do
        for _, g in pairs(byToken) do
            if pingHits(position, g.obj) then
                local token = getObjectFromGUID(tokenGuid)
                if token then echoPing(player.color, { token }) end
                return
            end
        end
    end

    local tokenGuid = nil
    if object and ghosts[object.getGUID()] then
        tokenGuid = object.getGUID()
    else
        for guid in pairs(ghosts) do
            if pingHits(position, getObjectFromGUID(guid)) then
                tokenGuid = guid
                break
            end
        end
    end
    if tokenGuid == nil then return end

    local targets = {}
    for _, g in pairs(ghosts[tokenGuid]) do
        if g.obj and not g.obj.isDestroyed() then table.insert(targets, g.obj) end
    end
    if #targets > 0 then echoPing(player.color, targets) end
end

-- The monster UI's visibility toggle, relayed by main.lua.
function BoardMirror.onVisibilityChanged(guid)
    if state == nil then return end
    local token = getObjectFromGUID(guid)
    if token and isTracked(token) then BoardMirror.sync(token) end
end

-- Flipping or spinning a token does not pick it up, so follow it from here.
function BoardMirror.onRotate(obj)
    if state == nil then return end
    if isTracked(obj) then follow(obj) end
end

function BoardMirror.onDestroy(obj)
    if state == nil or isGhost(obj) then return end
    local guid = obj.getGUID()
    if state.masters[guid] then
        -- Saving a script on the pin reloads it, which also lands here: only
        -- remove the master if it has not come back under the same GUID.
        Wait.time(function()
            if getObjectFromGUID(guid) == nil then removeMaster(guid) end
        end, 1)
    elseif state.slaves[guid] then
        local master = state.slaves[guid].master
        state.slaves[guid] = nil
        destroyGhostsOfSlave(guid)
        refreshPins(master)
        save()
    else
        stopFollowing(guid)
        destroyGhostsOfToken(guid)
        last_seen[guid] = nil
        rest_offset[guid] = nil
    end
end

return BoardMirror
