local utils = require("src.core.utils")
require("src.data.config")

local MovementMeasurement = {}

MovementMeasurement.my_token = nil
move_token = nil
MovementMeasurement.measuring = { }

function MovementMeasurement.create(target)
    target.addTag(OBJECT_TAGS.movement_measurement)
    MovementMeasurement.measuring[target.guid] = false
    target.addContextMenuItem("Toggle measurement", 
    function(player_color)
        MovementMeasurement.measuring[target.guid] = not MovementMeasurement.measuring[target.guid]
        if MovementMeasurement.measuring[target.guid] then
            MovementMeasurement.createMoveToken(target, player_color, true)
        else 
            MovementMeasurement.destroyMoveToken(target)
        end
    end)
end

function MovementMeasurement.onPickUp(obj, player_color)
    if MovementMeasurement.measuring[obj.guid] then return end
    MovementMeasurement.createMoveToken(obj, player_color, true)
end

function MovementMeasurement.onDrop(obj, player_color)
    if MovementMeasurement.measuring[obj.guid] then return end
    MovementMeasurement.destroyMoveToken(obj, player_color)
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
        -- Find the first object directly below the mini
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

local ranges = {
    -- the .5 is to account for the grid and show at the edge of the square
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
    drawCircles("far")
    currentRange = "far"
end

function onUpdate()
    -- self.interactable = false
    -- self.locked = true
    
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
    -- mDistance = math.floor(mDistance)    
    -- Determine which range to activate based on distance
    -- mDistance is basically the squares travelled
    local newRange = nil
    if mDistance <= 8 then
        newRange = "veryClose"
    elseif mDistance > 7 and mDistance <= 14 then
        newRange = "close"
    elseif mDistance > 14 then
        newRange = "far"
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

    -- Only redraw if the range changed
    -- if newRange ~= currentRange then
    --     currentRange = newRange
    --     drawCircles(currentRange)
    -- end
    -- drawCircles('far')
end

function drawCircles(maxRange)
    local lines = {}
    local scale = self.getScale()
    
    -- Find the index of maxRange in rangeOrder
    local maxIndex = 1
    for i, rangeName in ipairs(rangeOrder) do
        if rangeName == maxRange then
            maxIndex = i
            break
        end
    end
    
    -- Draw all circles up to and including maxRange
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
    move_token.destroy()
end

return MovementMeasurement