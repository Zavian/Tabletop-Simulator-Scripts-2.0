local utils = require("src.core.utils")
require("src.data.config")

local MovementMeasurement = {}

MovementMeasurement.my_token = nil
move_token = nil
MovementMeasurement.measuring = { }
MovementMeasurement.timers = {}

local ENABLE_AUTO_SNAP = (SAVED_DATA.PLAYER[player_color] and SAVED_DATA.PLAYER[player_color].autoSnap ~= nil) or true
local SNAP_THRESHOLD = 10

local MEASUREMENT_TIMEOUT = 5

function MovementMeasurement.create(target)
    target.addTag(OBJECT_TAGS.movement_measurement)
    MovementMeasurement.measuring[target.guid] = false
    target.addContextMenuItem("Toggle measurement", 
    function(player_color)
        MovementMeasurement.measuring[target.guid] = not MovementMeasurement.measuring[target.guid]
        if MovementMeasurement.measuring[target.guid] then
            MovementMeasurement.createMoveToken(target, player_color, true)
            MovementMeasurement.resetTimer(target, player_color)
        else 
            MovementMeasurement.destroyMoveToken(target)
            MovementMeasurement.cancelTimer(target.guid)
        end
    end)

    target.addContextMenuItem("Toggle auto snap",
    function(player_color)
        ENABLE_AUTO_SNAP = not ENABLE_AUTO_SNAP
        if ENABLE_AUTO_SNAP then
            Utils.success("Auto snap enabled", player_color)
        else
            Utils.error("Auto snap disabled", player_color)
        end

        -- TODO: Implement the global save function
        -- Utils.updateGlobalSave({player_color .. ".autoSnap", ENABLE_AUTO_SNAP})
        SAVED_DATA.PLAYER[player_color] = SAVED_DATA.PLAYER[player_color] or {}
        SAVED_DATA.PLAYER[player_color].autoSnap = ENABLE_AUTO_SNAP
    end)
end

function MovementMeasurement.onPickUp(obj, player_color)
    if MovementMeasurement.measuring[obj.guid] then
        MovementMeasurement.resetTimer(obj, player_color)
        return
    end
    MovementMeasurement.createMoveToken(obj, player_color, true)
    MovementMeasurement.resetTimer(obj, player_color)
end

function MovementMeasurement.onDrop(obj, player_color)
    if MovementMeasurement.measuring[obj.guid] then return end
    MovementMeasurement.destroyMoveToken(obj, player_color)
    MovementMeasurement.cancelTimer(obj.guid)
    obj.use_snap_points = false
end


function MovementMeasurement.resetTimer(obj, player_color)
    MovementMeasurement.cancelTimer(obj.guid)
    local guid = obj.guid
    local timerId = Wait.time(function()
        -- only auto-clear if still in measuring mode
        if MovementMeasurement.measuring[guid] then
            MovementMeasurement.measuring[guid] = false
            local target = getObjectFromGUID(guid)
            if target then
                MovementMeasurement.destroyMoveToken(target, player_color)
            end
        end
        MovementMeasurement.timers[guid] = nil
    end, MEASUREMENT_TIMEOUT)
    MovementMeasurement.timers[guid] = timerId
end

function MovementMeasurement.cancelTimer(guid)
    if MovementMeasurement.timers[guid] then
        Wait.stop(MovementMeasurement.timers[guid])
        MovementMeasurement.timers[guid] = nil
    end
end

function MovementMeasurement.createMoveToken(my_token, player_color, show_only_to_player)
    local tokenRot = Player[player_color].getPointerRotation()
    local movetokenparams = {
        image = "http://cloud-3.steamusercontent.com/ugc/1021697601906583980/C63D67188FAD8B02F1B58E17C7B1DB304B7ECBE3/",
        thickness = 0.1,
        type = 2
    }
    local startloc = my_token.getPosition() + Vector(0, 0.1, 0)
    local hitList =
        Physics.cast(
        {
            origin = my_token.getBounds().center,
            direction = {0, -1, 0},
            type = 1,
            max_distance = 10,
            debug = false
        }
    )
    for _, hitTable in ipairs(hitList) do
        if hitTable ~= nil and hitTable.point ~= nil and hitTable.hit_object ~= my_token then
            startloc = hitTable.point
            break
        end
    end
    local tokenScale = {
        x = Grid.sizeX / 4.7,
        y = 1,
        z = Grid.sizeX / 4.7,
    }
    local spawnparams = {
        type = "Custom_Token",
        position = startloc,
        rotation = {x = 0, y = 0, z = 0},
        scale = tokenScale,
        sound = false
    }

    local move_token = spawnObject(spawnparams)
    move_token.ignore_fog_of_war = true

    move_token.setSnapPoints({
        { position = {0,0,0} }
    })

    my_token.setVar("moveToken", move_token)

    move_token.setLock(true)
    move_token.setCustomObject(movetokenparams)
    move_token.setVar("measuredObject", my_token)
    move_token.setVar("myPlayer", player_color)
    move_token.setVar("className", "MeasurementToken_Move")

    move_token.getComponent("BoxCollider").set("enabled",false)

    if not ENABLE_AUTO_SNAP then
        SNAP_THRESHOLD = math.huge
    end


    move_token.setVar("snapThreshold", SNAP_THRESHOLD)

    if show_only_to_player then
        move_token.setInvisibleTo(utils.hideFromAllButPlayer(player_color))
    end
    local moveButtonParams = {
        click_function = "onLoad",
        function_owner = self,
        label = "00",
        position = {x = 0, y = 0.1, z = 0},
        width = 0,
        height = 0,
        font_size = 600
    }
    move_token.createButton(moveButtonParams)

    local luaScript = [[
    local gridSize = Grid.sizeX or 2
local measuredObject = nil
local currentRange = nil
local snapThreshold = nil
local snappingEnabled = false

local ranges = {
    veryClose = {
        radius = 3.5,
        color = {0, 0.659, 0.976}
    },
    close = {
        radius = 6.5,
        color = {0.204, 0.91, 0}
    },
    far = {
        radius = 12.5,
        color = {0.918, 0.416, 0}
    }
}

local rangeOrder = {"veryClose", "close", "far"}

function onLoad()
    measuredObject = self.getVar("measuredObject")
    snapThreshold = self.getVar("snapThreshold") or 5
    drawCircles("far")
    currentRange = "far"
end

function onUpdate()
    if measuredObject == nil or measuredObject.held_by_color == nil then
        return
    end
    
    local mypos = self.getPosition()
    local opos = measuredObject.getPosition()
    
    local mdiff = mypos - opos
    local mDistance = math.abs(mdiff.x)
    local zDistance = math.abs(mdiff.z)
    
    if zDistance > mDistance then
        mDistance = zDistance
    end
    
    mDistance = mDistance * gridSize

    local rawDistance = math.sqrt(mdiff.x * mdiff.x + mdiff.z * mdiff.z)
    if rawDistance >= snapThreshold and not snappingEnabled then
        measuredObject.use_snap_points = true
        snappingEnabled = true
    end

    if mDistance <= 8.9 then 
        self.editButton({index = 0, label = "Very\nClose"})
        self.setColorTint(ranges.veryClose.color)
    elseif mDistance > 8.9 and mDistance <= 17.7 then
        self.editButton({index = 0, label = "Close"})
        self.setColorTint(ranges.close.color)
    elseif mDistance > 17.7 then
        self.editButton({index = 0, label = "Far"})
        self.setColorTint(ranges.far.color)
    end
end

function drawCircles(maxRange)
    local lines = {}
    local scale = self.getScale()
    
    local maxIndex = 1
    for i, rangeName in ipairs(rangeOrder) do
        if rangeName == maxRange then
            maxIndex = i
            break
        end
    end
    
    for i = 1, maxIndex do
        local rangeName = rangeOrder[i]
        local range = ranges[rangeName]
        local adjustedRadius = (range.radius * gridSize) / scale.x
        local points = generateCirclePoints({x = 0, y = 0, z = 0}, adjustedRadius)
        
        table.insert(lines, {
            points = points,
            color = range.color,
            rotation = {0, 0, 0},
            fill = true
        })
    end
    
    self.setVectorLines(lines)
end

function generateCirclePoints(center, radius)
    local numSegments = 360
    local angleIncrement = 360 / numSegments
    local points = {}
    for i = 0, numSegments do
        local radians = math.rad(i * angleIncrement)
        local x = center.x + radius * math.cos(radians)
        local z = center.z + radius * math.sin(radians)
        table.insert(points, {x, center.y, z})
    end
    return points
end]]
        
    move_token.setLuaScript(luaScript)
end

function MovementMeasurement.destroyMoveToken(obj, player_color)
    local move_token = obj.getVar("moveToken")
    if move_token then
        move_token.destroy()
    end
end

return MovementMeasurement