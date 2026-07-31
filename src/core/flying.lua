local utils = require("src.core.utils")
require("src.data.config")

local Flying = {}

local OFFSET_VALUE = Grid.sizeX or 2

local RANGE_COLORS = {
    melee     = {0, 0.4550, 0.8510, 1},
    veryClose = {0, 0.659, 0.976, 1},
    close     = {0.204, 0.91, 0, 1},
    far       = {0.918, 0.416, 0, 1},
    veryFar   = {0.91, 0.169, 0.169, 1}
}

local RANGE_LABELS = {
    melee     = "Melee",
    veryClose = "Very\nClose",
    close     = "Close",
    far       = "Far",
    veryFar   = "Very\nFar"
}

function Flying.create(target)
    target.addTag(OBJECT_TAGS.flying)
    
    -- Add context menus
    target.addContextMenuItem("Fly Up", function(player_color)
        Flying.flyUp(target, player_color)
    end, true)
    target.addContextMenuItem("Fly Down", function(player_color)
        Flying.flyDown(target, player_color)
    end, true)

    -- Create fly height button if it doesn't exist
    if not Flying.getFlyButtonIndex(target) then
        local bounds = target.getBounds()
        local z_pos = bounds.size.z * 0.45
        if z_pos < 0.35 then z_pos = 0.35 end
        if z_pos > 1.3 then z_pos = 1.3 end
        
        target.createButton({
            click_function = "resetFlyButton",
            function_owner = self,
            label = "",
            position = {x = 1.3, y = 0.05, z = z_pos},
            rotation = {0, 0, 0},
            width = 600,
            height = 475,
            font_size = 300,
            color = {0, 0.4550, 0.8510, 0},
            font_color = {1, 1, 1, 0},
            tooltip = "Height",
            scale = {0.3, 0.3, 0.3}
        })
    end

    target.setVar("flyOffset", 0)
    target.setVar("isFloating", false)
    target.setVar("groundIndicator", nil)
end

function Flying.getFlyButtonIndex(target)
    local buttons = target.getButtons()
    if not buttons then return nil end
    for _, btn in ipairs(buttons) do
        if btn.click_function == "resetFlyButton" then
            return btn.index
        end
    end
    return nil
end

function Flying.flyUp(target, player_color)
    if not target.hasTag(OBJECT_TAGS.player) and player_color ~= "Black" then return end
    local currentOffset = target.getVar("flyOffset") or 0
    
    if currentOffset == 0 then
        local pos = target.getPosition()
        target.setPosition({pos.x, pos.y + 0.5, pos.z})
    end

    local nextOffset = currentOffset + OFFSET_VALUE
    target.setVar("flyOffset", nextOffset)
    Flying.setFloat(target, nextOffset)
end

function Flying.flyDown(target, player_color)
    if not target.hasTag(OBJECT_TAGS.player) and player_color ~= "Black" then return end
    local currentOffset = target.getVar("flyOffset") or 0
    if currentOffset > 0 then
        local nextOffset = currentOffset - OFFSET_VALUE
        target.setVar("flyOffset", nextOffset)
        Flying.setFloat(target, nextOffset)
    end
end

function Flying.resetFlyButton(target, player_color)
    if not target.hasTag(OBJECT_TAGS.player) and player_color ~= "Black" then return end
    target.setVar("flyOffset", 0)
    Flying.setFloat(target, 0)
end

function Flying.setFloat(target, offset)
    if offset == 0 then
        target.setVar("isFloating", false)
        target.use_gravity = true
        Flying.destroyGroundIndicator(target)
    else
        target.setVar("isFloating", true)
        target.use_gravity = false
        Flying.spawnGroundIndicator(target, offset)
    end
    Flying.updateHeightButton(target, offset)
end

function Flying.getRangeBand(squares)
    if squares <= 1.5 then return "melee"
    elseif squares <= 3 then return "veryClose"
    elseif squares <= 6 then return "close"
    elseif squares <= 12 then return "far"
    else return "veryFar"
    end
end

function Flying.updateHeightButton(target, offset)
    local btnIndex = Flying.getFlyButtonIndex(target)
    if not btnIndex then return end

    if offset == 0 then
        target.editButton({
            index = btnIndex,
            font_color = {1, 1, 1, 0},
            color = {0, 0.4550, 0.8510, 0}
        })
    else
        local squares = offset / OFFSET_VALUE
        local band = Flying.getRangeBand(squares)
        target.editButton({
            index = btnIndex,
            font_color = {1, 1, 1, 1},
            color = RANGE_COLORS[band],
            label = "+" .. math.floor(squares * 5)
        })
    end
end

function Flying.spawnGroundIndicator(target, offset)
    local guid = target.getGUID()
    local indicator = target.getVar("groundIndicator")
    if indicator then
        indicator.setVar("flyOffset", offset)
        indicator.call("updateLabel")
        return
    end

    local bounds = target.getBounds()
    local size = math.max(bounds.size.x, bounds.size.z) * 0.45
    local pos = target.getPosition()
    local groundY = Flying.getGroundHeight(target)

    local isVisible = true
    if target.getVar("is_visible") then
        local success, res = pcall(function() return target.call("is_visible") end)
        if success and res ~= nil then
            isVisible = res
        end
    end

    local invisible_players = {}
    if not isVisible then
        invisible_players = utils.hideFromPlayersArray()
    end

    spawnObject({
        type = "reversi_chip",
        position = {pos.x, groundY + 0.02, pos.z},
        rotation = {0, 0, 0},
        scale = {size, 0.02, size},
        sound = false,
        callback_function = function(obj)
            target.setVar("groundIndicator", obj)
            obj.setColorTint({0, 0, 0})
            obj.setName("Height Base")
            obj.sticky = false
            obj.setInvisibleTo(invisible_players)

            local originalTags = target.getTags()
            if originalTags then
                local filteredTags = {}
                for _, tag in ipairs(originalTags) do
                    if tag ~= OBJECT_TAGS.flying and tag ~= OBJECT_TAGS.movement_measurement then
                        table.insert(filteredTags, tag)
                    end
                end
                obj.setTags(filteredTags)
            end

            obj.addContextMenuItem("Fly Up", function(player_color)
                Flying.flyUp(target, player_color)
            end, true)
            obj.addContextMenuItem("Fly Down", function(player_color)
                Flying.flyDown(target, player_color)
            end, true)
            obj.addContextMenuItem("Reset Height", function(player_color)
                Flying.resetFlyButton(target, player_color)
            end, true)

            local rot = target.getRotation()
            obj.setRotation({0, rot.y, 0})

            local luaScript = [[
local targetGuid = "]] .. guid .. [["
local flyOffset = ]] .. offset .. [[
local ready = true

local RANGE_COLORS = {
    melee     = {0, 0.4550, 0.8510, 1},
    veryClose = {0, 0.659, 0.976, 1},
    close     = {0.204, 0.91, 0, 1},
    far       = {0.918, 0.416, 0, 1},
    veryFar   = {0.91, 0.169, 0.169, 1}
}
local RANGE_LABELS = {
    melee     = "Melee",
    veryClose = "Very\nClose",
    close     = "Close",
    far       = "Far",
    veryFar   = "Very\nFar"
}

function colorToHex(c)
    local function toHex(v)
        return string.format("%02X", math.floor((v or 1) * 255 + 0.5))
    end
    return "#" .. toHex(c[1]) .. toHex(c[2]) .. toHex(c[3]) .. toHex(c[4])
end

function getRangeBand(squares)
    if squares <= 1.5 then return "melee"
    elseif squares <= 3 then return "veryClose"
    elseif squares <= 6 then return "close"
    elseif squares <= 12 then return "far"
    else return "veryFar"
    end
end

function onLoad()
    local target = getObjectFromGUID(targetGuid)
    local labelText = ""
    local fontColor = {1, 1, 1, 1}
    
    if target then
        local currentOffset = self.getVar("flyOffset") or flyOffset
        local offsetVal = Grid.sizeX or 2
        local squares = currentOffset / offsetVal
        local band = getRangeBand(squares)
        labelText = RANGE_LABELS[band] or ""
        fontColor = RANGE_COLORS[band] or {1, 1, 1, 1}
    end

    self.UI.setXml('<Text id="rangeLabel" text="' .. labelText .. '" color="' .. colorToHex(fontColor) .. '" fontSize="22" fontStyle="Bold" alignment="MiddleCenter" width="600" height="600" position="0 0 -150" rotation="0 0 180" outline="#000000FF" outlineSize="3 -3" /> ')
    Global.call("registerGroundIndicator", {targetGuid = targetGuid, indicatorGuid = self.getGUID()})

end

function updateLabel()
    local target = getObjectFromGUID(targetGuid)
    if not target then return end
    
    local currentOffset = self.getVar("flyOffset") or flyOffset
    local offsetVal = Grid.sizeX or 2
    local squares = currentOffset / offsetVal
    local band = getRangeBand(squares)
    
    self.UI.setAttribute("rangeLabel", "text", RANGE_LABELS[band] or "")
    self.UI.setAttribute("rangeLabel", "color", colorToHex(RANGE_COLORS[band] or {1, 1, 1, 1}))
end

function onUpdate()
    if not ready or not targetGuid then return end
    local target = getObjectFromGUID(targetGuid)
    if not target then
        destroyObject(self)
        return
    end

    if self.getVar("isTargetPickedUp") then return end

    local currentOffset = self.getVar("flyOffset") or flyOffset

    local shadowPos = self.getPosition()
    local targetY = shadowPos.y + currentOffset
    local selfPos = target.getPosition()

    local isHeld = target.held_by_color ~= nil or self.held_by_color ~= nil
    if not isHeld then
        local players = Player.getPlayers()
        for _, p in ipairs(players) do
            local sel = p.getSelectedObjects()
            if sel then
                for _, sObj in ipairs(sel) do
                    if sObj == target or sObj == self then
                        isHeld = true
                        break
                    end
                end
            end
            if isHeld then break end
        end
    end

    if isHeld then
        target.setPosition({shadowPos.x, targetY, shadowPos.z})
        target.setVelocity({0, 0, 0})
        target.setAngularVelocity({0, 0, 0})
    else
        if math.abs(selfPos.x - shadowPos.x) > 0.01 
            or math.abs(selfPos.z - shadowPos.z) > 0.01 
            or math.abs(selfPos.y - targetY) > 0.01 
        then
            target.setPositionSmooth({shadowPos.x, targetY, shadowPos.z}, false, false)
        end
    end
end
]]
            obj.setLuaScript(luaScript)

            Wait.condition(function()
                obj.setLock(false)
                obj.interactable = true
                obj.use_gravity = true
                obj.use_grid = false
                obj.tooltip = true

                local col = obj.getComponent("BoxCollider") or obj.getComponent("MeshCollider") or obj.getComponent("CapsuleCollider")
                if col then
                    col.set("enabled", true)
                end
            end, function() return not obj.loading_custom end)
        end
    })
end

function Flying.destroyGroundIndicator(target)
    local indicator = target.getVar("groundIndicator")
    if indicator then
        destroyObject(indicator)
        target.setVar("groundIndicator", nil)
    end
end

function Flying.onPickUp(obj, player_color)
    local shadow = obj.getVar("groundIndicator")
    if shadow then
        shadow.setVar("isTargetPickedUp", true)
    end
end

function Flying.onDrop(obj, player_color)
    local shadow = obj.getVar("groundIndicator")
    if shadow then
        shadow.setVar("isTargetPickedUp", false)
        local pos = obj.getPosition()
        local groundY = Flying.getGroundHeight(obj)
        shadow.setPosition({pos.x, groundY + 0.02, pos.z})
    end
end

function Flying.getGroundHeight(obj)
    local pos = obj.getPosition()
    local origin = {
        x = pos.x,
        y = pos.y + 0.1,
        z = pos.z
    }
    local hitList = Physics.cast({
        origin = origin,
        direction = {0, -1, 0},
        type = 1,
        max_distance = 30,
        debug = false
    })
    for _, hit in ipairs(hitList) do
        if hit ~= nil and hit.hit_object ~= nil and hit.hit_object ~= obj then
            local shadow = obj.getVar("groundIndicator")
            if not shadow or hit.hit_object ~= shadow then
                return hit.point.y
            end
        end
    end
    return 0
end

function Flying.registerGroundIndicator(params)
    if not params or not params.targetGuid or not params.indicatorGuid then return end
    local target = getObjectFromGUID(params.targetGuid)
    local indicator = getObjectFromGUID(params.indicatorGuid)
    if target and indicator then
        target.setVar("groundIndicator", indicator)
    end
end

function Flying.updateVisibility(target_guid, visible)
    local target = getObjectFromGUID(target_guid)
    if target then
        local shadow = target.getVar("groundIndicator")
        if shadow then
            shadow.setInvisibleTo(visible and {} or utils.hideFromPlayersArray())
            shadow.setColorTint(visible and {0, 0, 0} or {0, 0, 0, 0.5})
            shadow.UI.setAttribute("rangeLabel", "visibility", visible and "" or "Black")
        end
    end
end

return Flying