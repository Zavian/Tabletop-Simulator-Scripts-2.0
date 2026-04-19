local ranges = {
    -- the .5 is to account for the grid and show at the edge of the square
    veryClose = {
        radius = 3.5,
        color = {0, 0.659, 0.976},
        color_hex = "00A8F9"
    },
    close = {
        radius = 6.5,
        color = {0.204, 0.91, 0},
        color_hex = "34E800"
    },
    far = {
        radius = 12.5,
        color = {0.918, 0.416, 0},
        color_hex = "EA6A00"
    }
}

local rangeOrder = {"veryClose", "close", "far"}

function onLoad()
    self.addContextMenuItem("[".. ranges.veryClose.color_hex .."] Very Close", toggleVeryClose, true)
    self.addContextMenuItem("[".. ranges.close.color_hex .."] Close", toggleClose, true)
    self.addContextMenuItem("[".. ranges.far.color_hex .."] Far", toggleFar, true)
    self.addContextMenuItem("Clear", function() self.setColorTint({1, 1, 1}); drawCircles(nil) end, true)
end

function toggleVeryClose()
    self.setColorTint(ranges.veryClose.color)
    drawCircles("veryClose")
end
function toggleClose()
    self.setColorTint(ranges.close.color)
    drawCircles("close")
end
function toggleFar()
    self.setColorTint(ranges.far.color)
    drawCircles("far")
end

function drawCircles(maxRange)
    if maxRange == nil then
        self.setVectorLines({})
        return
    end

    local lines = {}
    local scale = self.getScale()
    local gridSize = Grid.sizeX or 2
    
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