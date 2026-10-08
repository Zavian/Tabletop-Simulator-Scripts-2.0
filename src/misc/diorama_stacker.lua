-- Diorama Stacker
--
-- Stacks the layer PNGs exported by Scriptorium's diorama workspace into a
-- diorama of Custom Tokens. Put this script on any object; its UI lets the GM
-- paste the layer links, give each layer a height and a Y position, set the
-- point everything is measured from, and build or clear the stack.
--
-- Units. Height and Y are both in token-thickness units: a layer of height 1 is
-- one Custom Token of thickness 1, and a layer at Y 1 sits on top of a height-1
-- layer. Heights above 1 are built from several identical copies stacked on top
-- of each other, each ceil(height) of them with thickness height / count, so no
-- copy ever falls under the 0.1 minimum (2.05 is three copies of ~0.68, not two
-- of 1 plus a 0.05 sliver).
--
-- What is measured rather than assumed. The API documents what `thickness`
-- means only as "how thick the token is", and nothing about where a token's
-- pivot sits relative to its faces. So every piece is spawned, left to finish
-- loading its image, and then measured with getBounds(): each copy is stacked by
-- its own measured height, a layer's Y is converted to world units with the
-- ratio measured on that layer's first piece, and each piece is placed by its
-- measured bottom face rather than by its pivot.
--
-- The one thing taken on trust is registration in X/Z: every piece is put at the
-- same pivot position. Scriptorium exports every layer at the full map size with
-- the shape in place, so pieces line up exactly when TTS builds each token's mesh
-- in the full image's frame. If layers ever appear offset from each other in
-- game, that assumption is the place to look.
--
-- Pieces are tagged with this object's GUID in `memo`, so CLEAR finds them even
-- after a reload or a copy/paste of the controller.

-- Where the panel sits on the object. Object UI is drawn relative to the object,
-- so these may need adjusting for the object the script is put on.
local UI_POSITION = "0 0 -30"
local UI_ROTATION = "0 0 0"
local UI_SCALE = "1 1 1"
local UI_VISIBILITY = "Black|Admin"

local MIN_THICKNESS = 0.1
local MAX_THICKNESS = 1
local MAX_COPIES = 20 -- a typo of 200 should not spawn 200 tokens
local LOAD_TIMEOUT = 60 -- seconds to wait for every image to load
local PANEL_WIDTH = 560
local ROW_HEIGHT = 30

local state = {
    layers = {}, -- { url, name, height, y }
    origin = { x = 0, y = 1, z = 0 },
    rotation = 0,
    scale = 1,
    merge = 15, -- TTS's own default merge distance
}

local pasteBuffer = ""
local buildId = 0 -- bumped on every build/clear so a stale build stops placing
local status = "Paste links and press ADD."

-------------------------------------------------------------------------------
-- LIFECYCLE
-------------------------------------------------------------------------------

function onLoad(saved)
    if saved and saved ~= "" then
        local ok, data = pcall(JSON.decode, saved)
        if ok and type(data) == "table" then
            for k, v in pairs(data) do state[k] = v end
        end
    end
    rebuildUI()
end

function onSave()
    return JSON.encode(state)
end

-------------------------------------------------------------------------------
-- HELPERS
-------------------------------------------------------------------------------

local function isAuthorized(player)
    return player ~= nil and (player.color == "Black" or player.admin)
end

local function tell(player, msg, color)
    status = msg
    self.UI.setValue("txt_status", msg)
    if player then
        broadcastToColor("[Diorama] " .. msg, player.color, color or { 1, 1, 1 })
    end
end

local function fmt(n)
    return string.format("%g", n)
end

local function xmlEscape(s)
    return (tostring(s)
        :gsub("&", "&amp;")
        :gsub("<", "&lt;")
        :gsub(">", "&gt;")
        :gsub('"', "&quot;"))
end

local function indexFromId(id)
    return tonumber(id:match("_(%d+)$"))
end

-- Scriptorium names a layer file `<map>__<layer>__h<height>.png`, with the
-- height's dot written as a dash. When a link still carries that filename the
-- layer's name and height come from it; a Steam Cloud link carries neither.
local function describeUrl(url, index)
    local file = url:gsub("[?#].*$", ""):match("([^/\\]+)$") or ""
    local layer, h = file:match("^.-__(.-)__h([%d%-]+)%.[pP][nN][gG]$")
    local height = h and tonumber((h:gsub("%-", "."))) or nil
    return layer or ("Layer " .. index), height
end

-- Height -> number of copies and the thickness of each.
local function splitHeight(height)
    if height <= MAX_THICKNESS then
        return 1, math.max(height, MIN_THICKNESS)
    end
    local count = math.min(math.ceil(height / MAX_THICKNESS - 1e-9), MAX_COPIES)
    return count, math.min(height / count, MAX_THICKNESS)
end

-------------------------------------------------------------------------------
-- UI
-------------------------------------------------------------------------------

local function input(id, value, width, handler, validation)
    return string.format(
        '<InputField id="%s" text="%s" preferredWidth="%d" onValueChanged="%s" onEndEdit="%s" characterValidation="%s" fontSize="13" />',
        id, xmlEscape(value), width, handler, handler .. "End", validation or "Decimal")
end

local function label(text, width, extra)
    return string.format('<Text preferredWidth="%d" %s>%s</Text>', width, extra or "", xmlEscape(text))
end

function rebuildUI()
    local rows = {}
    for i, layer in ipairs(state.layers) do
        local count = splitHeight(layer.height)
        rows[#rows + 1] = string.format([[
<HorizontalLayout preferredHeight="%d" spacing="6" childForceExpandWidth="false">
    %s
    %s
    %s
    %s
    <Button id="rm_%d" text="X" preferredWidth="30" onClick="onRemoveLayer" colors="#EF4444|#DC2626|#B91C1C|#EF444480" />
</HorizontalLayout>]],
            ROW_HEIGHT,
            label(i .. ". " .. layer.name, 250, 'alignment="MiddleLeft" tooltip="' .. xmlEscape(layer.url) .. '"'),
            input("h_" .. i, fmt(layer.height), 80, "onLayerHeight"),
            input("y_" .. i, fmt(layer.y), 80, "onLayerY"),
            label(count > 1 and ("x" .. count) or "", 50, 'class="dim"'),
            i)
    end

    local height = 330 + #state.layers * (ROW_HEIGHT + 6)

    local xml = string.format([[
<Defaults>
    <Text color="#F3F4F6" fontSize="13" alignment="MiddleCenter" />
    <Text class="dim" color="#9CA3AF" fontSize="12" />
    <Text class="title" fontSize="18" fontStyle="Bold" />
    <Button textColor="#FFFFFF" fontStyle="Bold" fontSize="13" colors="#272A34|#3B3E4D|#1A1C23|#272A3480" />
</Defaults>
<Panel id="root" visibility="%s" position="%s" rotation="%s" scale="%s" width="%d" height="%d" color="#0F1015F2" padding="10 10 10 10">
<VerticalLayout spacing="6" childForceExpandHeight="false">
    <Text class="title" preferredHeight="26">DIORAMA STACKER</Text>
    <InputField id="paste" preferredHeight="70" lineType="MultiLineNewLine" fontSize="12" placeholder="Paste layer image links here, one per line" onValueChanged="onPasteChanged" />
    <HorizontalLayout preferredHeight="32" spacing="6">
        <Button text="ADD LINKS" onClick="onAddLinks" colors="#3B82F6|#2563EB|#1D4ED8|#3B82F680" />
        <Button text="BUILD" onClick="onBuild" colors="#10B981|#059669|#047857|#10B98180" />
        <Button text="CLEAR PIECES" onClick="onClearPieces" colors="#F59E0B|#D97706|#B45309|#F59E0B80" />
    </HorizontalLayout>
    <Text class="dim" preferredHeight="18" alignment="MiddleLeft">Position 0 (world) - everything is measured from here</Text>
    <HorizontalLayout preferredHeight="30" spacing="6" childForceExpandWidth="false">
        %s %s %s %s %s %s
        <Button text="FROM OBJECT" preferredWidth="130" onClick="onOriginFromObject" />
    </HorizontalLayout>
    <HorizontalLayout preferredHeight="30" spacing="6" childForceExpandWidth="false">
        %s %s %s %s %s %s
    </HorizontalLayout>
    <HorizontalLayout preferredHeight="20" spacing="6" childForceExpandWidth="false">
        %s %s %s %s
    </HorizontalLayout>
    %s
    <Text id="txt_status" class="dim" preferredHeight="36">%s</Text>
</VerticalLayout>
</Panel>]],
        UI_VISIBILITY, UI_POSITION, UI_ROTATION, UI_SCALE, PANEL_WIDTH, height,
        label("X", 20), input("ox", fmt(state.origin.x), 90, "onOriginX"),
        label("Y", 20), input("oy", fmt(state.origin.y), 90, "onOriginY"),
        label("Z", 20), input("oz", fmt(state.origin.z), 90, "onOriginZ"),
        label("Rot Y", 50), input("rot", fmt(state.rotation), 80, "onRotation"),
        label("Scale", 50), input("scale", fmt(state.scale), 80, "onScale"),
        label("Merge px", 70), input("merge", fmt(state.merge), 80, "onMerge", "Integer"),
        label("Layer", 250, 'class="dim" alignment="MiddleLeft"'),
        label("Height", 80, 'class="dim"'),
        label("Y", 80, 'class="dim"'),
        label("", 50),
        table.concat(rows, "\n"),
        xmlEscape(status))

    self.UI.setXml(xml)
end

-------------------------------------------------------------------------------
-- UI HANDLERS
--
-- Text typed into an InputField can only be read from its handler's arguments,
-- so every change is stored as it is typed (onValueChanged, keeping the last
-- valid number) and the field is tidied when it loses focus (onEndEdit).
-------------------------------------------------------------------------------

function onPasteChanged(player, value)
    pasteBuffer = value or ""
end

function onAddLinks(player)
    if not isAuthorized(player) then return end
    local added = 0
    for url in pasteBuffer:gmatch("%S+") do
        local index = #state.layers + 1
        local name, height = describeUrl(url, index)
        state.layers[index] = { url = url, name = name, height = height or 1, y = 0 }
        added = added + 1
    end
    pasteBuffer = ""
    if added == 0 then
        tell(player, "Nothing to add: paste one or more links first.", { 1, 0.6, 0.2 })
    else
        status = "Added " .. added .. " layer(s). Set heights and Y, then BUILD."
    end
    rebuildUI()
end

function onRemoveLayer(player, _, id)
    if not isAuthorized(player) then return end
    local i = indexFromId(id)
    if i and state.layers[i] then
        table.remove(state.layers, i)
        rebuildUI()
    end
end

local function numberField(setter, sanitise)
    return function(player, value, id)
        if not isAuthorized(player) then return end
        local n = tonumber(value)
        if n then setter(id, sanitise and sanitise(n) or n) end
    end
end

local function endField(getter)
    return function(player, _, id)
        if not isAuthorized(player) then return end
        self.UI.setAttribute(id, "text", fmt(getter(id)))
    end
end

local function layerAt(id) return state.layers[indexFromId(id)] end

local function clampHeight(n)
    return math.min(math.max(n, MIN_THICKNESS), MAX_THICKNESS * MAX_COPIES)
end

onLayerHeight = numberField(function(id, n)
    local layer = layerAt(id)
    if layer then layer.height = n end
end)
onLayerHeightEnd = function(player, value, id)
    if not isAuthorized(player) then return end
    local layer = layerAt(id)
    if not layer then return end
    local before = splitHeight(layer.height)
    layer.height = clampHeight(layer.height)
    -- The copy count is shown next to the row, so a change in it redraws.
    if splitHeight(layer.height) ~= before or tonumber(value) ~= layer.height then
        rebuildUI()
    end
end

onLayerY = numberField(function(id, n)
    local layer = layerAt(id)
    if layer then layer.y = n end
end)
onLayerYEnd = endField(function(id)
    local layer = layerAt(id)
    return layer and layer.y or 0
end)

onOriginX = numberField(function(_, n) state.origin.x = n end)
onOriginY = numberField(function(_, n) state.origin.y = n end)
onOriginZ = numberField(function(_, n) state.origin.z = n end)
onOriginXEnd = endField(function() return state.origin.x end)
onOriginYEnd = endField(function() return state.origin.y end)
onOriginZEnd = endField(function() return state.origin.z end)

onRotation = numberField(function(_, n) state.rotation = n end)
onRotationEnd = endField(function() return state.rotation end)

onScale = numberField(function(_, n) if n > 0 then state.scale = n end end)
onScaleEnd = endField(function() return state.scale end)

onMerge = numberField(function(_, n) if n >= 0 then state.merge = n end end, math.floor)
onMergeEnd = endField(function() return state.merge end)

function onOriginFromObject(player)
    if not isAuthorized(player) then return end
    local p = self.getPosition()
    state.origin = { x = p.x, y = p.y, z = p.z }
    status = "Position 0 set to this object's position."
    rebuildUI()
end

function onBuild(player)
    if not isAuthorized(player) then return end
    build(player)
end

function onClearPieces(player)
    if not isAuthorized(player) then return end
    local removed = clearPieces()
    tell(player, "Removed " .. removed .. " piece(s).")
end

-------------------------------------------------------------------------------
-- BUILDING
-------------------------------------------------------------------------------

function clearPieces()
    buildId = buildId + 1
    local guid = self.getGUID()
    local removed = 0
    for _, obj in ipairs(getObjects()) do
        if obj.memo == guid then
            obj.destruct()
            removed = removed + 1
        end
    end
    return removed
end

function build(player)
    if #state.layers == 0 then
        tell(player, "No layers to build.", { 1, 0.6, 0.2 })
        return
    end

    clearPieces()
    local thisBuild = buildId
    local o, s = state.origin, state.scale

    -- Spawned locked at position 0 so nothing falls or collides while images
    -- load; everything is moved into place once it can be measured.
    local pieces = {}
    for i, layer in ipairs(state.layers) do
        local count, thickness = splitHeight(layer.height)
        for c = 1, count do
            local obj = spawnObject({
                type = "Custom_Token",
                position = { o.x, o.y, o.z },
                rotation = { 0, state.rotation, 0 },
                scale = { s, s, s },
                sound = false,
            })
            obj.setCustomObject({
                image = layer.url,
                thickness = thickness,
                merge_distance = state.merge,
                stackable = false,
            })
            obj.setLock(true)
            obj.setName(count > 1 and string.format("%s (%d/%d)", layer.name, c, count) or layer.name)
            obj.memo = self.getGUID()
            pieces[#pieces + 1] = { obj = obj, layer = i, thickness = thickness }
        end
    end

    tell(player, "Loading " .. #pieces .. " piece(s)...")

    local function loaded()
        for _, p in ipairs(pieces) do
            if p.obj ~= nil and (p.obj.spawning or p.obj.loading_custom) then return false end
        end
        return true
    end

    Wait.condition(
        -- One more frame so the bounds reflect the finished mesh.
        function() Wait.frames(function() place(player, pieces, thisBuild) end, 1) end,
        function() return buildId ~= thisBuild or loaded() end,
        LOAD_TIMEOUT,
        function()
            if buildId == thisBuild then
                tell(player, "Timed out waiting for images to load. Check the links and BUILD again.", { 1, 0.3, 0.3 })
            end
        end)
end

function place(player, pieces, thisBuild)
    if buildId ~= thisBuild then return end -- cleared or rebuilt meanwhile
    local o = state.origin
    local nextBottom = {} -- per layer: where its next copy's bottom face goes
    local missing = 0

    for _, p in ipairs(pieces) do
        local obj = p.obj
        if obj == nil then
            missing = missing + 1
        else
            local bounds = obj.getBounds()
            local h = bounds.size.y
            local pivotAboveBottom = obj.getPosition().y - (bounds.center.y - h / 2)
            if nextBottom[p.layer] == nil then
                -- Y is in thickness units; this piece says what one unit is.
                local worldPerUnit = h / p.thickness
                nextBottom[p.layer] = o.y + state.layers[p.layer].y * worldPerUnit
            end
            obj.setPosition({ o.x, nextBottom[p.layer] + pivotAboveBottom, o.z })
            nextBottom[p.layer] = nextBottom[p.layer] + h
        end
    end

    local msg = "Built " .. (#pieces - missing) .. " piece(s) from " .. #state.layers .. " layer(s)."
    if missing > 0 then msg = msg .. " " .. missing .. " were deleted before placing." end
    tell(player, msg, { 0.4, 1, 0.5 })
end
