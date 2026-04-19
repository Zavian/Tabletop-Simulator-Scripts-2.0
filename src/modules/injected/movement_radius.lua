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
end