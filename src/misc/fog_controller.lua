-- credits: https://steamcommunity.com/sharedfiles/filedetails/?id=2988772966
-- thanks max <3


--[[StartXML
<Defaults>
    <!-- General Defaults -->
    <Text color="#F3F4F6" fontStyle="Bold" alignment="MiddleCenter" />
    <Button colors="#272A34|#3B3E4D|#1A1C23|#272A3480" textColor="#FFFFFF" fontStyle="Bold" fontSize="11" />
    <Panel color="Transparent" />

    <!-- Custom Class Defaults -->
    <Text class="stat-label" fontSize="11" color="#9CA3AF" />
    <Text class="sub-label" fontSize="9" color="#6B7280" />
</Defaults>

<!-- Main Container Panel (Visible only to Black) -->
<Panel id="MainPanel" visibility="Black" position="0 140 -75" rotation="0 0 0" width="40" height="40" rectAlignment="MiddleCenter" color="#00000000" padding="0">
    <VerticalLayout spacing="6">
        
        <!-- Minimizable Content Area (Positioned ABOVE Minimize Button) -->
        <VerticalLayout id="ContentArea" spacing="6" active="false">
            <Text id="txt_point_count" text="VERTICES: 0" class="stat-label" height="16" alignment="MiddleCenter" />
            
            <!-- Row 1: Fog & Style Toggles -->
            <HorizontalLayout height="36" spacing="6">
                <Button id="btn_toggle_fog" text="TURN ON" onClick="xml_toggleOnOff" colors="#10B981|#059669|#047857|#10B98180" textColor="#FFFFFF" />
                <Button id="btn_toggle_style" text="STYLE: OUTLINE" onClick="xml_toggleStyle" colors="#3B82F6|#2563EB|#1D4ED8|#3B82F680" textColor="#FFFFFF" />
            </HorizontalLayout>

            <!-- Row 2: Handles Toggle & Name Area -->
            <HorizontalLayout height="36" spacing="6">
                <Button id="btn_toggle_handles" text="EDIT HANDLES: OFF" onClick="xml_toggleHandles" colors="#8B5CF6|#7C3AED|#6D28D9|#8B5CF680" textColor="#FFFFFF" />
                <Button id="btn_set_name" text="SET AREA NAME" onClick="xml_setName" colors="#EC4899|#DB2777|#BE185D|#EC489980" textColor="#FFFFFF" />
            </HorizontalLayout>

            <!-- Row 3: Undo & Clear Buttons -->
            <HorizontalLayout height="36" spacing="6">
                <Button id="btn_undo" text="UNDO POINT" onClick="xml_undo" colors="#F59E0B|#D97706|#B45309|#F59E0B80" textColor="#FFFFFF" />
                <Button id="btn_clear" text="CLEAR ALL" onClick="xml_clear" colors="#EF4444|#DC2626|#B91C1C|#EF444480" textColor="#FFFFFF" />
            </HorizontalLayout>
        </VerticalLayout>

        <!-- Small Square Minimize/Maximize Button -->
        
        <!-- High-Contrast Outlined Area Name Label (Below Minimize Button) -->
        
        </VerticalLayout>
        </Panel>
        
        <Button position="0 15 -75" id="btn_minimize" text="+" onClick="xml_toggleMinimize" width="40" height="40" colors="#FFEA00|#FFF566|#D4C400|#FFEA0080" textColor="#000000" fontSize="20" fontStyle="Bold" />
        <Text visibility="Black" id="txt_area_name" position="0 -25 -75" text="" fontSize="42" fontStyle="Bold" color="#FFEA00" outline="#000000" outlineSize="2 2" active="false" />
StopXML--xml]]

local vertices = {}
local resolution
local isTurnedOn = false
local hiddenVectorLines
local isLockedOnOff = false
local renderingStyle = 2
local isMinimized = true -- Starts minimized on load
local areaName = ""

local handles = {}
local handlesActive = false
local isCleaningHandles = false

-------------------------------------------------------------------------------
-- XML INTEGRATION & UI LOGIC
-------------------------------------------------------------------------------

function loadXMLFromScript()
    local script = self.getLuaScript()
    local start_tag = "StartXML"
    local stop_tag = "StopXML"

    local start_idx = script:find(start_tag, 1, true)
    local stop_idx = script:find(stop_tag, 1, true)

    if start_idx and stop_idx then
        local xml = script:sub(start_idx + #start_tag, stop_idx - 1)
        xml = xml:gsub("&", "&amp;")
        self.UI.setXml(xml)
    end
end

function updateXmlUI()
    if isLockedOnOff then
        self.UI.setAttribute("MainPanel", "active", "false")
        return
    else
        self.UI.setAttribute("MainPanel", "active", "true")
    end

    -- Counter-rotate UI panel to keep text right side up regardless of tile rotation
    local objRot = self.getRotation()
    self.UI.setAttribute("MainPanel", "rotation", "0 0 " .. string.format("%.1f", -objRot.y))

    -- Show Area Name label below minimize button if name is set
    local showLabel = (areaName ~= "")
    self.UI.setAttribute("txt_area_name", "active", showLabel and "true" or "false")
    self.UI.setValue("txt_area_name", areaName)

    -- Toggle between expanded panel and minimized square button
    if isMinimized then
        self.UI.setAttribute("ContentArea", "active", "false")
        self.UI.setAttribute("MainPanel", "color", "#00000000")
        self.UI.setAttribute("MainPanel", "padding", "0")
        self.UI.setAttribute("MainPanel", "width", "250")
        self.UI.setAttribute("MainPanel", "height", showLabel and "68" or "40")
        -- self.UI.setAttribute("MainPanel", "position", "0 15 -75")
        self.UI.setAttribute("MinimizeRow", "height", "40")
        -- self.UI.setAttribute("btn_minimize", "width", "40")
        -- self.UI.setAttribute("btn_minimize", "height", "40")
        self.UI.setAttribute("btn_minimize", "text", "+")
        -- self.UI.setAttribute("btn_minimize", "colors", "#FFEA00|#FFF566|#D4C400|#FFEA0080")
        -- self.UI.setAttribute("btn_minimize", "textColor", "#000000")
    else
        self.UI.setAttribute("ContentArea", "active", "true")
        self.UI.setAttribute("MainPanel", "color", "#0F1015F2")
        self.UI.setAttribute("MainPanel", "padding", "8")
        self.UI.setAttribute("MainPanel", "width", "320")
        self.UI.setAttribute("MainPanel", "height", showLabel and "238" or "210")
        -- self.UI.setAttribute("MainPanel", "position", showLabel and "0 114 -75" or "0 100 -75")
        self.UI.setAttribute("MinimizeRow", "height", "32")
        -- self.UI.setAttribute("btn_minimize", "width", "32")
        -- self.UI.setAttribute("btn_minimize", "height", "32")
        self.UI.setAttribute("btn_minimize", "text", "—")
        -- self.UI.setAttribute("btn_minimize", "colors", "#272A34|#3B3E4D|#1A1C23|#272A3480")
        -- self.UI.setAttribute("btn_minimize", "textColor", "#FFFFFF")
    end

    -- Turn On/Off Button State
    if isTurnedOn then
        self.UI.setAttribute("btn_toggle_fog", "text", "TURN OFF")
        self.UI.setAttribute("btn_toggle_fog", "colors", "#EF4444|#DC2626|#B91C1C|#EF444480")
        self.UI.setAttribute("btn_toggle_fog", "textColor", "#FFFFFF")
    else
        self.UI.setAttribute("btn_toggle_fog", "text", "TURN ON")
        self.UI.setAttribute("btn_toggle_fog", "colors", "#10B981|#059669|#047857|#10B98180")
        self.UI.setAttribute("btn_toggle_fog", "textColor", "#FFFFFF")
    end

    -- Handles Button State
    if handlesActive then
        self.UI.setAttribute("btn_toggle_handles", "text", "EDIT HANDLES: ON")
        self.UI.setAttribute("btn_toggle_handles", "colors", "#10B981|#059669|#047857|#10B98180")
    else
        self.UI.setAttribute("btn_toggle_handles", "text", "EDIT HANDLES: OFF")
        self.UI.setAttribute("btn_toggle_handles", "colors", "#8B5CF6|#7C3AED|#6D28D9|#8B5CF680")
    end

    -- Set Area Name Button Text
    if areaName ~= "" then
        self.UI.setAttribute("btn_set_name", "text", "NAME: " .. areaName)
    else
        self.UI.setAttribute("btn_set_name", "text", "SET AREA NAME")
    end

    -- Render Style Button
    if renderingStyle == 1 then
        self.UI.setAttribute("btn_toggle_style", "text", "STYLE: FILL")
    else
        self.UI.setAttribute("btn_toggle_style", "text", "STYLE: OUTLINE")
    end

    -- Point Count Display
    self.UI.setAttribute("txt_point_count", "text", "VERTICES: " .. tostring(#vertices))
end

function isAuthorized(player)
    if type(player) == "userdata" or type(player) == "table" then
        return player.color == "Black" or player.admin
    elseif type(player) == "string" then
        return player == "Black" or (Player[player] and Player[player].admin)
    end
    return false
end

function getPlayerObject(player)
    if type(player) == "userdata" or type(player) == "table" then
        return player
    elseif type(player) == "string" then
        return Player[player]
    end
    return nil
end

-- XML Event Handlers
function xml_toggleMinimize(player, value, id)
    if not isAuthorized(player) then return end
    isMinimized = not isMinimized
    updateXmlUI()
end

function xml_toggleOnOff(player, value, id)
    if not isAuthorized(player) then return end
    if not isLockedOnOff then
        changeOnOffState(not isTurnedOn)
    end
end

function xml_toggleStyle(player, value, id)
    if not isAuthorized(player) then return end
    if not isLockedOnOff then
        changeRenderingStyle()
        updateXmlUI()
    end
end

function xml_toggleHandles(player, value, id)
    if not isAuthorized(player) then return end
    handlesActive = not handlesActive
    if handlesActive then
        spawnHandles()
    else
        removeHandles()
    end
    updateXmlUI()
end

function xml_setName(player, value, id)
    if not isAuthorized(player) then return end
    local p = getPlayerObject(player)
    if p then
        p.showInputDialog("Enter Area Name:", areaName or "", function(text, player_color)
            areaName = text or ""
            updateXmlUI()
        end)
    end
end

function xml_undo(player, value, id)
    if not isAuthorized(player) then return end
    if not isLockedOnOff and #vertices > 0 then
        table.remove(vertices)
        if #vertices == 0 then
            self.setVectorLines({})
        elseif renderingStyle == 1 then
            fillPolygon(vertices)
        else
            drawOutlinesOnly()
        end
        if handlesActive then
            spawnHandles()
        end
        updateXmlUI()
    end
end

function xml_clear(player, value, id)
    if not isAuthorized(player) then return end
    local p = getPlayerObject(player)
    if p then
        p.showConfirmDialog("Are you sure you want to clear all points?", function(player_color)
            vertices = {}
            areaName = ""
            self.setVectorLines({})
            removeHandles()
            updateXmlUI()
        end)
    end
end

-------------------------------------------------------------------------------
-- DYNAMIC HANDLE SCALING & DIRECTIONAL BUTTONS
-------------------------------------------------------------------------------

function calculateHandleScale(index)
    local baseScale = 0.35
    local minScale = 0.12
    local thresholdDist = 2.0

    if #vertices <= 1 then return baseScale end

    local v_i = vertices[index]
    local minDist = math.huge

    for j, v_j in ipairs(vertices) do
        if j ~= index then
            local dx = v_i.x - v_j.x
            local dz = v_i.z - v_j.z
            local dist = math.sqrt(dx * dx + dz * dz)
            if dist < minDist then
                minDist = dist
            end
        end
    end

    local factor = math.min(1.0, minDist / thresholdDist)
    return math.max(minScale, baseScale * factor)
end

function updateHandleScales()
    for i, handle in ipairs(handles) do
        if handle and not handle.isDestroyed() then
            local s = calculateHandleScale(i)
            handle.setScale({s, s, s})
        end
    end
end

function spawnHandles()
    removeHandles()
    for i, vert in ipairs(vertices) do
        local worldPos = self.positionToWorld({vert.x, getYPosition(), vert.z})
        local hScale = calculateHandleScale(i)

        local handle = spawnObject({
            type = "Checker_red",
            position = worldPos,
            scale = {hScale, hScale, hScale},
            sound = false,
            callback_function = function(obj)
                obj.use_grid = false
                obj.use_snap_points = false
            end
        })
        handle.setName("Vertex Handle #" .. i)

        -- OUTER RING: Extrude New Vertex (Radius 1.2)
        handle.createButton({
            click_function = "btn_add_north",
            function_owner = self,
            label          = "▲",
            position       = {0, 0.3, -1.2},
            rotation       = {0, 0, 0},
            width          = 250,
            height         = 250,
            font_size      = 150,
            color          = {0.15, 0.15, 0.2, 0.9},
            font_color     = {1, 1, 1}
        })
        handle.createButton({
            click_function = "btn_add_south",
            function_owner = self,
            label          = "▼",
            position       = {0, 0.3, 1.2},
            rotation       = {0, 0, 0},
            width          = 250,
            height         = 250,
            font_size      = 150,
            color          = {0.15, 0.15, 0.2, 0.9},
            font_color     = {1, 1, 1}
        })
        handle.createButton({
            click_function = "btn_add_west",
            function_owner = self,
            label          = "►",
            position       = {1.2, 0.3, 0},
            rotation       = {0, 0, 0},
            width          = 250,
            height         = 250,
            font_size      = 150,
            color          = {0.15, 0.15, 0.2, 0.9},
            font_color     = {1, 1, 1}
        })
        handle.createButton({
            click_function = "btn_add_east",
            function_owner = self,
            label          = "◄",
            position       = {-1.2, 0.3, 0},
            rotation       = {0, 0, 0},
            width          = 250,
            height         = 250,
            font_size      = 150,
            color          = {0.15, 0.15, 0.2, 0.9},
            font_color     = {1, 1, 1}
        })

        -- INNER RING: Nudge Existing Vertex (Radius 0.6)
        handle.createButton({
            click_function = "btn_nudge_north",
            function_owner = self,
            label          = "↑",
            position       = {0, 0.3, -0.6},
            rotation       = {0, 0, 0},
            width          = 180,
            height         = 180,
            font_size      = 120,
            color          = {0.25, 0.25, 0.35, 0.9},
            font_color     = {1, 1, 1}
        })
        handle.createButton({
            click_function = "btn_nudge_south",
            function_owner = self,
            label          = "↓",
            position       = {0, 0.3, 0.6},
            rotation       = {0, 0, 0},
            width          = 180,
            height         = 180,
            font_size      = 120,
            color          = {0.25, 0.25, 0.35, 0.9},
            font_color     = {1, 1, 1}
        })
        handle.createButton({
            click_function = "btn_nudge_west",
            function_owner = self,
            label          = "→",
            position       = {0.6, 0.3, 0},
            rotation       = {0, 0, 0},
            width          = 180,
            height         = 180,
            font_size      = 120,
            color          = {0.25, 0.25, 0.35, 0.9},
            font_color     = {1, 1, 1}
        })
        handle.createButton({
            click_function = "btn_nudge_east",
            function_owner = self,
            label          = "←",
            position       = {-0.6, 0.3, 0},
            rotation       = {0, 0, 0},
            width          = 180,
            height         = 180,
            font_size      = 120,
            color          = {0.25, 0.25, 0.35, 0.9},
            font_color     = {1, 1, 1}
        })

        handles[i] = handle
    end
end

function removeHandles()
    isCleaningHandles = true
    for i, handle in pairs(handles) do
        if handle and not handle.isDestroyed() then
            handle.destruct()
        end
    end
    handles = {}
    isCleaningHandles = false
end

function addVertexDirection(handleObj, dx, dz, player_color)
    if not isAuthorized(player_color) then return end

    local idx = nil
    for k, h in ipairs(handles) do
        if h == handleObj then
            idx = k
            break
        end
    end

    if not idx then return end

    local baseVert = vertices[idx]
    local offset = 1.0

    local newVert = {
        x = baseVert.x + (dx * offset),
        y = getYPosition(),
        z = baseVert.z + (dz * offset)
    }

    table.insert(vertices, idx + 1, newVert)

    if renderingStyle == 1 then
        fillPolygon(vertices)
    else
        drawOutlinesOnly()
    end

    spawnHandles()
    updateXmlUI()
end

function nudgeVertexDirection(handleObj, dx, dz, player_color)
    if not isAuthorized(player_color) then return end

    local idx = nil
    for k, h in ipairs(handles) do
        if h == handleObj then
            idx = k
            break
        end
    end

    if not idx then return end

    local baseVert = vertices[idx]
    local nudgeAmount = 0.1

    vertices[idx] = {
        x = baseVert.x + (dx * nudgeAmount),
        y = getYPosition(),
        z = baseVert.z + (dz * nudgeAmount)
    }

    if renderingStyle == 1 then
        fillPolygon(vertices)
    else
        drawOutlinesOnly()
    end

    local newWorldPos = self.positionToWorld({vertices[idx].x, getYPosition(), vertices[idx].z})
    handleObj.setPosition(newWorldPos)
    updateHandleScales()
end

-- Callbacks
function btn_add_north(obj, color) addVertexDirection(obj, 0, -1, color) end
function btn_add_south(obj, color) addVertexDirection(obj, 0, 1, color) end
function btn_add_east(obj, color)  addVertexDirection(obj, 1, 0, color) end
function btn_add_west(obj, color)  addVertexDirection(obj, -1, 0, color) end

function btn_nudge_north(obj, color) nudgeVertexDirection(obj, 0, -1, color) end
function btn_nudge_south(obj, color) nudgeVertexDirection(obj, 0, 1, color) end
function btn_nudge_east(obj, color)  nudgeVertexDirection(obj, 1, 0, color) end
function btn_nudge_west(obj, color)  nudgeVertexDirection(obj, -1, 0, color) end

function onUpdate()
    if not handlesActive or #handles == 0 then return end

    -- 1. Handle deletion by player
    if not isCleaningHandles then
        local deletedIdx = nil
        for i, handle in ipairs(handles) do
            if not handle or handle.isDestroyed() then
                deletedIdx = i
                break
            end
        end

        if deletedIdx then
            table.remove(vertices, deletedIdx)
            table.remove(handles, deletedIdx)

            if #vertices == 0 then
                self.setVectorLines({})
            elseif renderingStyle == 1 then
                fillPolygon(vertices)
            else
                drawOutlinesOnly()
            end

            spawnHandles()
            updateXmlUI()
            return
        end
    end

    -- 2. Handle grab transparency & movement
    local changed = false
    local controllerMoved = self.held_by_color ~= nil or self.getVelocity():magnitude() > 0.01

    for i, handle in ipairs(handles) do
        if handle and not handle.isDestroyed() then
            -- Make handle transparent while grabbed to avoid fidgety obstruction
            if handle.held_by_color ~= nil then
                handle.setColorTint({1, 1, 1, 0})
            else
                handle.setColorTint({1, 1, 1, 1})
            end

            if controllerMoved and handle.held_by_color == nil then
                local worldPos = self.positionToWorld({vertices[i].x, getYPosition(), vertices[i].z})
                handle.setPosition(worldPos)
            else
                local localPos = self.positionToLocal(handle.getPosition())
                local dx = math.abs(localPos.x - vertices[i].x)
                local dz = math.abs(localPos.z - vertices[i].z)

                if dx > 0.01 or dz > 0.01 then
                    vertices[i] = {
                        x = localPos.x,
                        y = getYPosition(),
                        z = localPos.z
                    }
                    changed = true
                end
            end
        end
    end

    if changed then
        if renderingStyle == 1 then
            fillPolygon(vertices)
        else
            drawOutlinesOnly()
        end
        updateHandleScales()
    end
end

function onDestroy()
    removeHandles()
end

-------------------------------------------------------------------------------
-- CONFIG & HELPERS
-------------------------------------------------------------------------------

function isObjectTransparent()
    local tp = self.getGMNotes():match("transparent%s*:%s*(%a+)")
    if tp == "false" then return false end

    local players = Player.getPlayers()
    if players and #players <= 1 then
        return false
    end

    return true
end

function getOffColor()
    color = self.getGMNotes():match("off%-color%s*:%s*{#?(%x+)}")
    if color == nil then color = "ff0000" end
    return color
end

function getOnColor()
    color = self.getGMNotes():match("on%-color%s*:%s*{#?(%x+)}")
    if color == nil then color = "00ff00" end
    return color
end

function getFlippedColor()
    color = self.getGMNotes():match("flipped%-color%s*:%s*{#?(%x+)}")
    if color == nil then color = "101010" end
    return color
end

function getFogColor()
    color = self.getGMNotes():match("fog%-color%s*:%s*{#?(%x+)}")
    if color == nil then color = "000000" end
    return color
end

function getYOffset()
    offset = self.getGMNotes():match("y%-offset%s*:%s*([-]?[%d.]+)%s*pt")
    if offset == nil then offset = 0 end
    return tonumber(offset)
end

function getResolution()
    res = self.getGMNotes():match("resolution%s*:%s*([%d.]+)%s*pt")
    if res ~= nil then
        resolution = tonumber(res)
    else
        resolution = 0.175
    end
    return resolution
end

function getOutlineEnabled()
    enabled = self.getGMNotes():match("outline%s*:%s*false")
    return enabled == nil
end

function getYPosition()
    return 0 + getYOffset()
end

function onSave()
    local data = {
        vertices = vertices,
        isTurnedOn = isTurnedOn,
        renderingStyle = renderingStyle,
        isMinimized = isMinimized,
        areaName = areaName
    }
    return JSON.encode(data)
end

function onLoad(save_state)
    self.max_typed_number = 9
    if save_state ~= "" then
        local loadedData = JSON.decode(save_state)
        vertices = loadedData.vertices or {}
        renderingStyle = loadedData.renderingStyle or 2
        areaName = loadedData.areaName or ""
    end
    
    isTurnedOn = false
    isMinimized = true

    loadXMLFromScript()
    changeOnOffState(false, true)
    Wait.frames(function()
        updateXmlUI()
    end, 3)
end

function onPlayerConnect(player_id)
    changeOnOffState(isTurnedOn)
end

function onPlayerDisconnect(player_id)
    changeOnOffState(isTurnedOn)
end

function onDrop(player_color)
    updateXmlUI()
end

-------------------------------------------------------------------------------
-- CORE LOGIC & EVENT HANDLERS
-------------------------------------------------------------------------------

function onPlayerPing(player, position)
    if player.color == "Black" and isTurnedOn then
        -- Native TTS local space conversion
        local localPos = self.positionToLocal(position)
        local vert = {
            x = localPos.x,
            y = getYPosition(),
            z = localPos.z
        }

        table.insert(vertices, vert)
        drawOutlinesOnly()
        
        if handlesActive then
            spawnHandles()
        end
        updateXmlUI()
    end
end

local previousFlipToggleState = false

function onRotate(spin, flip, player_color, old_spin, old_flip)
    if flip == 180 and old_flip == 0 and player_color == "Black" then
        isLockedOnOff = true
        previousFlipToggleState = isTurnedOn
        hiddenVectorLines = self.getVectorLines()
        self.setVectorLines({})
        changeOnOffState(false)
        
        local color = hexToVector(getFlippedColor())
        local alpha = isObjectTransparent() and 0 or color[4]
        self.setColorTint({color[1], color[2], color[3], alpha})
        self.setName("Fog Controller: " .. "[101010]FLIPPED[-]")
        removeHandles()
    elseif flip == 0 and old_flip == 180 and player_color == "Black" then
        isLockedOnOff = false
        self.setVectorLines(hiddenVectorLines)
        hiddenVectorLines = {}
        changeOnOffState(previousFlipToggleState)
    end
    self.setPosition({self.getPosition().x, self.getPosition().y, self.getPosition().z})
    self.setRotation({0, 0, flip})
    self.setVelocity({x = 0, y = 0, z = 0})
    updateXmlUI()
    return true
end

function onRandomize(player_color)
    self.setPosition({self.getPosition().x, self.getPosition().y, self.getPosition().z})
    self.setRotation({0, 0, self.getRotation().z})
    self.setVelocity({x = 0, y = 0, z = 0})
    updateXmlUI()
    return true
end

function onNumberTyped(player_color, number_typed)
    if player_color == "Black" then
        if number_typed == 1 and isTurnedOn and not isLockedOnOff then
            changeRenderingStyle()
        elseif number_typed == 2 and isTurnedOn and not isLockedOnOff then
            vertices = {}
            areaName = ""
            self.setVectorLines({})
            removeHandles()
        elseif number_typed == 3 and not isLockedOnOff then
            changeOnOffState(true)
        elseif number_typed == 4 and not isLockedOnOff then
            changeOnOffState(false)
        end
        updateXmlUI()
    end
end

function changeRenderingStyle()
    if renderingStyle == 1 then
        drawOutlinesOnly()
        renderingStyle = 2
    elseif renderingStyle == 2 then
        fillPolygon(vertices)
        renderingStyle = 1
    end
end

function changeOnOffState(stateOnOff, skipUI)
    if stateOnOff then
        isTurnedOn = true
        local color = hexToVector(getOnColor())
        local alpha = isObjectTransparent() and 0 or color[4]
        self.setColorTint({color[1], color[2], color[3], alpha})
        self.setName("Fog Controller: " .. "[00FF00]ON[-]")
    else
        isTurnedOn = false
        local color = hexToVector(getOffColor())
        local alpha = isObjectTransparent() and 0 or color[4]
        self.setColorTint({color[1], color[2], color[3], alpha})
        self.setName("Fog Controller: " .. "[FF0000]OFF[-]")
    end
    
    if not skipUI then
        updateXmlUI()
    end
end

function hexToVector(hexColor)
    local color = hexColor:gsub("#", "")
    local alpha, red, green, blue
    if #color == 8 then
        red = tonumber(color:sub(1, 2), 16)
        green = tonumber(color:sub(3, 4), 16)
        blue = tonumber(color:sub(5, 6), 16)
        alpha = tonumber(color:sub(7, 8), 16)
    else
        alpha = 255
        red = tonumber(color:sub(1, 2), 16)
        green = tonumber(color:sub(3, 4), 16)
        blue = tonumber(color:sub(5, 6), 16)
    end

    return {red / 255, green / 255, blue / 255, alpha / 255}
end

function drawOutlinesOnly()
    self.setVectorLines({})
    if #vertices <= 0 then return end

    local vectorLines = {}
    drawOutline(vectorLines, hexToVector(getOnColor()), getResolution() * 1.01)
    self.setVectorLines(vectorLines)
end

function fillPolygon(polygon)
    if #vertices <= 2 then return end
    self.setVectorLines({})

    local zmin, zmax = math.huge, -math.huge
    for _, point in ipairs(polygon) do
        if point.z < zmin then zmin = point.z end
        if point.z > zmax then zmax = point.z end
    end

    local vectorLines = {}

    for z = zmin, zmax, getResolution() do
        local intersections = {}

        for i = 1, #polygon do
            local p1, p2 = polygon[i], polygon[(i % #polygon) + 1]

            if (p1.z <= z and p2.z > z) or (p1.z > z and p2.z <= z) then
                local x = p1.x + ((z - p1.z) / (p2.z - p1.z)) * (p2.x - p1.x)
                table.insert(intersections, x)
            end
        end

        table.sort(intersections)

        for i = 1, #intersections - 1, 2 do
            local startX = intersections[i]
            local endX = intersections[i + 1]

            local vectorLine = {
                points = {
                    {startX, getYPosition(), z},
                    {endX, getYPosition(), z}
                },
                color = hexToVector(getFogColor()),
                thickness = getResolution() * 1.01
            }
            table.insert(vectorLines, vectorLine)
        end
    end

    if getOutlineEnabled() then
        drawOutline(vectorLines, hexToVector(getFogColor()), getResolution() * 1.01)
    end
    self.setVectorLines(vectorLines)
end

function drawOutline(tableToInsertInto, color, thickness)
    for i, position in ipairs(vertices) do
        local nextPosition = vertices[i + 1] or vertices[1]

        local vectorLine = {
            points = {
                {position.x, getYPosition(), position.z},
                {nextPosition.x, getYPosition(), nextPosition.z}
            },
            color = color,
            thickness = thickness
        }
        table.insert(tableToInsertInto, vectorLine)
    end
end