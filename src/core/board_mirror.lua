-- Board Mirror
--
-- Mirrors tokens tagged movement_measurement from one board onto others, as
-- ghosts that follow the token while it is carried. Neither the boards nor the
-- tokens get any script: everything lives here, in Global.
--
-- Pins. Give any object the script in src/modules/mirror_pin.lua and drop it on a
-- board: that object is now a master pin and the board a master. Right-click
-- the master pin and "Spawn slave" (a script-free copy of the master), drop the
-- slave on another board: tokens on the master board now get a shadow on that
-- board. A master can have any number of slaves, and a board can carry any
-- number of pins. The board
-- a pin belongs to is whatever it was dropped on (a ray cast straight down), so
-- moving a pin to another board re-links it.
--
-- Shadows. A flat disc the size of the token's footprint, in the token's color:
-- blue for player tokens, the token's own tint (enemy, ally, neutral) for the
-- rest. It carries the token's name, is locked, not interactable and has its
-- colliders turned off, so nothing can grab or bump it. A shadow exists while
-- its token is over the master board and goes away when the token leaves it.
--
-- Mapping. A position is taken into the master board's local space and back out
-- of the slave board's, so the two boards can sit anywhere, at any rotation and
-- scale. Height is not mapped: the shadow lies on the slave board's surface,
-- raised by however far the token was resting above the master board's surface
-- (stairs, platforms inside a diorama).
--
-- Links are kept in SAVED_DATA.BOARD_MIRROR, keyed by pin GUID. Ghosts are not
-- saved: on load the old ones are deleted and rebuilt.

local utils = require("src.core.utils")
require("src.data.config")

local BoardMirror = {}

-- Click target for the ghosts' name labels, which are buttons owned by Global.
function boardMirror_noop() end

local TICK = 0.05
local SHADOW_THICKNESS = 0.05
local LABEL_HEIGHT = 0.15

local PLAYER_COLOR = CONFIG.palette.blue.rgb
local FLIPPED_COLOR = CONFIG.palette.fuchsia.rgb

-- Saved state:
--   masters[pinGuid] = { board = boardGuid }
--   slaves[pinGuid]  = { master = pinGuid, board = boardGuid }
--   hidden[boardGuid] = true when that board's pins are hidden
local state = nil

-- Runtime only:
--   ghosts[tokenGuid][slavePinGuid] = { obj = Object|nil, name = string, color = hex string }
--   timers[tokenGuid] = Wait id of the follow loop
--   rest_offset[tokenGuid] = how far the token last rested above its master board
local ghosts = {}
local timers = {}
local rest_offset = {}
local board_menus = {}

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

-- Every board that has at least one pin on it.
local function knownBoards()
    local boards = {}
    for _, m in pairs(state.masters) do
        if m.board then boards[m.board] = true end
    end
    for _, s in pairs(state.slaves) do
        if s.board then boards[s.board] = true end
    end
    return boards
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

-- A flipped token's shadow is its color mixed halfway with pink, so it stands
-- out from the ones still face up.
local function tokenColor(token)
    local c = token.hasTag(OBJECT_TAGS.player) and PLAYER_COLOR or token.getColorTint()
    if token.is_face_down then
        return Color(
            (c.r + FLIPPED_COLOR.r) / 2,
            (c.g + FLIPPED_COLOR.g) / 2,
            (c.b + FLIPPED_COLOR.b) / 2
        )
    end
    return Color(c.r, c.g, c.b)
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
local function placeGhost(g, token, masterBoard, slaveBoard)
    local obj = g.obj
    if not obj or obj.isDestroyed() then return end

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
    local g = { obj = nil, name = nil, color = nil, bottom = 0 }
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
                    if g == nil then
                        spawnGhost(token, slaveGuid, masterBoard, slaveBoard)
                    else
                        placeGhost(g, token, masterBoard, slaveBoard)
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

-- Follows a token every TICK while it is held or still settling.
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
        if token.held_by_color == nil and token.resting then
            stopFollowing(tokenGuid)
        end
    end, TICK, -1)
end

------------------------------------------------------------------------------
-- Pins and menus
------------------------------------------------------------------------------

local addPinMenu
local addBoardMenu

-- Masters keep their own look; only slaves are renamed.
local function stylePin(pin)
    if state.slaves[pin.getGUID()] then
        pin.setName("Mirror slave")
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

local function placePin(pin)
    local board = boardUnderPin(pin)
    local guid = pin.getGUID()
    local entry = state.masters[guid] or state.slaves[guid]
    if not entry then return end
    entry.board = board and board.getGUID() or nil
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
            state.slaves[pin.getGUID()] = { master = masterGuid, board = nil }
            stylePin(pin)
            addPinMenu(pin)
            save()
        end,
    })
end

local function removeSlave(slaveGuid)
    if not state.slaves[slaveGuid] then return end
    state.slaves[slaveGuid] = nil
    destroyGhostsOfSlave(slaveGuid)
    local pin = getObjectFromGUID(slaveGuid)
    if pin then pin.destruct() end
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
        end
    end

    local function restore(guid, entry)
        local pin = getObjectFromGUID(guid)
        stylePin(pin)
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
    save()

    -- Let the deleted ghosts finish going before spawning new ones.
    Wait.frames(BoardMirror.syncAll, 2)
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

function BoardMirror.onDrop(obj)
    if state == nil then return end
    if isTracked(obj) then
        follow(obj)
    elseif isPin(obj) then
        -- Re-detect the board once the pin has landed.
        Wait.condition(function()
            if obj.isDestroyed() then return end
            placePin(obj)
            BoardMirror.syncAll()
        end, function() return obj.isDestroyed() or obj.resting end, 5)
    end
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
        state.slaves[guid] = nil
        destroyGhostsOfSlave(guid)
        save()
    elseif ghosts[guid] then
        stopFollowing(guid)
        destroyGhostsOfToken(guid)
    end
end

return BoardMirror
