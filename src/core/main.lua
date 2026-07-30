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
        local table = Tables.getTable()

        print("Table loading complete")

        if table ~= "Table_RPG" then return end
        local newBoss = utils.getObjectByTag(OBJECT_TAGS.boss_token)
        utils.swapObjectInBagByTag(COMPONENTS.npc_commander, OBJECT_TAGS.boss_token, newBoss)

        local newMonster = utils.getObjectByTag(OBJECT_TAGS.monster_token)
        utils.swapObjectInBagByTag(COMPONENTS.npc_commander, OBJECT_TAGS.monster_token, newMonster)

        local newNote = utils.getObjectByTag(OBJECT_TAGS.clever_notecard)
        utils.swapObjectInBagByTag(COMPONENTS.npc_commander, OBJECT_TAGS.clever_notecard, newNote)

        -- Scan and initialize any existing flying tokens
        local all_objs = getAllObjects()
        for _, obj in ipairs(all_objs) do
            if obj.hasTag(OBJECT_TAGS.flying) then
                if obj.getVar("flyOffset") == nil then
                    flying.create(obj)
                end
            end
        end
    end)

    if saved_data then SAVED_DATA = JSON.decode(saved_data) end
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
end

function onSave()
    local saved_data = JSON.encode(SAVED_DATA)
    self.script_state = saved_data
    return self.script_state
end