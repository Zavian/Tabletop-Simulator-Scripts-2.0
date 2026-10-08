-- Main entry point for the TTS script
-- Load config first
require('src.data.config')


-- Laod core modules
local EventDispatcher = require('src.core.event_dispatcher')
local utils = require('src.core.utils')
local updater = require('src.core.updater')
local promise = require('src.core.promise')
local movement_measurement = require('src.core.movement_measurement')
local flying = require('src.core.flying')
local board_mirror = require('src.core.board_mirror')

-- Load UI Manager

-- Load Feature Modules

-- Global Variables
local COMPONENTS = {
    npc_commander = nil,
    movement_objects = {},
}
local _SEARCHING = false

-- onload stuff
function onLoad(saved_data)
    promise.WaitFrames(35, function()

        initializeTableComponents()
        board_mirror.init()


        -- Scan and initialize any existing flying tokens
        local all_objs = getAllObjects()
        for _, obj in ipairs(all_objs) do
            if obj.hasTag(OBJECT_TAGS.flying) then
                if obj.getVar("flyOffset") == nil then
                    flying.create(obj)
                end
            end
        end

        -- DEBUG AREA
        -- This stuff never gets called unless i'm in my dev environment, so it's safe to leave it here for testing purposes
        local table = Tables.getTable()

        print("Table loading complete")

        if table ~= "Table_RPG" then return end
        local newBoss = utils.getObjectByTag(OBJECT_TAGS.boss_token)
        utils.swapObjectInBagByTag(COMPONENTS.npc_commander, OBJECT_TAGS.boss_token, newBoss)

        local newMonster = utils.getObjectByTag(OBJECT_TAGS.monster_token)
        utils.swapObjectInBagByTag(COMPONENTS.npc_commander, OBJECT_TAGS.monster_token, newMonster)

        local newNote = utils.getObjectByTag(OBJECT_TAGS.clever_notecard)
        utils.swapObjectInBagByTag(COMPONENTS.npc_commander, OBJECT_TAGS.clever_notecard, newNote)

        local fogController = getObjectFromGUID('ad04fe')
        local fogBag = getObjectFromGUID('5b06db')
        fogBag.reset()
        fogController.clone({
            position = fogBag.getPosition() + Vector(0, 2, 0),
            rotation = fogBag.getRotation(),
            sound = false
        })
    end)

    -- An empty or unreadable save decodes to nil: keep the defaults from config.
    if saved_data and saved_data ~= "" then
        local decoded = JSON.decode(saved_data)
        if type(decoded) == "table" then
            SAVED_DATA = decoded
            SAVED_DATA.PLAYER = SAVED_DATA.PLAYER or {}
        end
    end
end

-- Event Handlers for bags
-- Basically pseudo infinite containers that respawn their contents when something is taken out
function onObjectLeaveContainer(container, leave_object)
    if _SEARCHING then return end

    if not container.hasTag(OBJECT_TAGS.infinite_container) then
        return false
    end

    local newObj = leave_object.clone({
        sound = false,
        position = container.getPosition()
    })
    container.putObject(newObj)
end
function tryObjectEnterContainer(container, object)
    if container == COMPONENTS.npc_commander and not _SEARCHING then
        return false
    end
    return true
end

function onObjectSearchStart(object, player_color)
    _SEARCHING = true
end

function onObjectSearchEnd(object, player_color)
    _SEARCHING = false
end


function onObjectPickUp(player_color, pick_obj)
    if pick_obj.hasTag(OBJECT_TAGS.movement_measurement) then
        if movement_measurement.measuring[pick_obj.guid] == nil then
            movement_measurement.create(pick_obj)
        end
        movement_measurement.onPickUp(pick_obj, player_color)
    end

    if pick_obj.hasTag(OBJECT_TAGS.flying) then
        if pick_obj.getVar("flyOffset") == nil then
            flying.create(pick_obj)
        end
        flying.onPickUp(pick_obj, player_color)
    end

    board_mirror.onPickUp(pick_obj)
end

function onObjectDrop(player_color, drop_obj)
    drop_obj.setVar("last_held_by", player_color)
    _debug("Object with guid " .. drop_obj.guid .. " has variable last_held_by set to " .. player_color)

    if drop_obj.hasTag(OBJECT_TAGS.movement_measurement) then
        movement_measurement.onDrop(drop_obj)
    end

    if drop_obj.hasTag(OBJECT_TAGS.flying) then
        flying.onDrop(drop_obj)
    end

    board_mirror.onDrop(drop_obj, player_color)
end

function onObjectDestroy(obj)
    board_mirror.onDestroy(obj)
end

function onObjectSpawn(obj)
    board_mirror.onSpawn(obj)
end

function onObjectRotate(obj, spin, flip, player_color, old_spin, old_flip)
    board_mirror.onRotate(obj)
end

function onPlayerPing(player, position, object)
    board_mirror.onPing(player, position, object)
end

function boardMirror_registerMaster(params)
    if not params or not params.guid then return end
    board_mirror.registerMaster(params.guid)
end

function resetFlyButton(obj, color)
    flying.resetFlyButton(obj, color)
end

function initializeTableComponents()
    -- Here we initialize all the table items such as the npc commander or the player trackers
    local npc_commander = utils.getObjectByTag(OBJECT_TAGS.npc_commander)
    if npc_commander then
        COMPONENTS.npc_commander = npc_commander
    end
end

function event_subscribe(params)
    local eventName = params.eventName
    local guid = params.guid
    local functionName = params.functionName
    local object = getObjectFromGUID(guid)
    if object ~= nil then
        EventDispatcher.subscribe(eventName, function(...)
            object.call(functionName, {...})
        end)
    end
end

function event_broadcast(params)
    local eventName = params.eventName
    local args = params.args
    if args == nil then
        args = {}
    end
    EventDispatcher.broadcast(eventName, unpack(args))
end

function list()
    EventDispatcher.list()
end

function registerGroundIndicator(params)
    flying.registerGroundIndicator(params)
end

function initializeFlying(params)
    if not params or not params.guid then return end
    local target = getObjectFromGUID(params.guid)
    if target then
        if target.getVar("flyOffset") == nil then
            flying.create(target)
        end
    end
end

function updateFlyingVisibility(params)
    if not params or not params.guid then return end
    flying.updateVisibility(params.guid, params.visible)
    board_mirror.onVisibilityChanged(params.guid)
end

function onSave()
    local saved_data = JSON.encode(SAVED_DATA)
    self.script_state = saved_data
    return self.script_state
end