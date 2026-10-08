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
-- A height can also be written "thickness*count" (or "thicknessxcount"): 0.1*3
-- is three copies 0.1 thick, total 0.3, where plain 0.3 is one copy 0.3 thick.
-- The layer keeps `copies` for that, and the JSON carries it the same way.
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
-- Pieces are tagged in `memo` with this object's GUID and their layer's id
-- ("<guid>|<id>"), so CLEAR finds them even after a reload or a copy/paste of
-- the controller, and clicking a layer's name highlights and pings its pieces.
-- The id is stable, not the row number: removing a row would otherwise point
-- every row below it at its neighbour's pieces.
--
-- Stack JSON. Scriptorium's diorama export can upload every layer to
-- upload.zaes.dev and hand back a JSON document; paste it in the box and press
-- ADD to replace the layer list with it (ADD tells JSON from links by the "{"):
--   { "format": "scriptorium-diorama-stack", "version": 1, "map": "...",
--     "layers": [ { "name", "url", "height", "y" }, ... ] }   -- bottom first
-- Heights in it are already token thickness (Scriptorium's height / 10). EDIT AS
-- JSON puts the current list in the box in the same format, so many heights can
-- be edited in a text editor and pasted back instead of field by field. SAVE TO
-- NOTE spawns a Notecard holding the same JSON, plus a "stacker" block with the
-- position 0, rotation, scale and merge distance, so a finished stack can be
-- kept and rebuilt later by pasting the note's text into the box and pressing ADD.

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
    nextId = 1, -- for layer ids; see the header
    map = nil, -- name/size from the last imported stack JSON, carried into saves
    mapWidth = nil,
    mapHeight = nil,
}

local pasteBuffer = ""
local clearLayersArmed = false
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

local HIGHLIGHT_COLOR = { 1, 0.85, 0.1 }
local HIGHLIGHT_SECONDS = 3
-- The name button's normal look, and the look it takes while its pieces are
-- highlighted, so the row and the table say the same thing for the same time.
local NAME_COLORS = "#00000000|#FFFFFF1A|#FFFFFF33|#00000000"
local NAME_TEXT_COLOR = "#F3F4F6"
local NAME_LIT_COLORS = "#FFD91A40|#FFD91A60|#FFD91A80|#FFD91A40"
local NAME_LIT_TEXT_COLOR = "#FFD91A"
local nameLitToken = {} -- per row: the latest highlight, so an older timer cannot unlight a newer one

-- Every layer gets an id once, whichever way it arrived (links, JSON, an old save).
local function ensureLayerIds()
    for _, layer in ipairs(state.layers) do
        if layer.id == nil then
            layer.id = state.nextId
            state.nextId = state.nextId + 1
        end
    end
end

local function pieceTag(layer)
    return self.getGUID() .. "|" .. layer.id
end

-- True for anything this controller spawned. A bare GUID is what builds made
-- before pieces carried their layer id.
local function isOurPiece(obj)
    local guid = self.getGUID()
    local memo = obj.memo
    return memo == guid or (type(memo) == "string" and memo:sub(1, #guid + 1) == guid .. "|")
end

local function indexFromId(id)
    return tonumber(id:match("_(%d+)$"))
end

-- Scriptorium names a layer file `<map>__<layer>__h<height>.png`, with the
-- height's dot written as a dash. When a link still carries that filename the
-- layer's name and height come from it; a Steam Cloud link carries neither.
-- Scriptorium heights are ten times token thickness (a thickness of 1 is huge in
-- TTS), hence the division -- the same conversion its stack JSON applies.
local SCRIPTORIUM_HEIGHT_TO_THICKNESS = 0.1
local DEFAULT_HEIGHT = 0.1

local function describeUrl(url, index)
    local file = url:gsub("[?#].*$", ""):match("([^/\\]+)$") or ""
    local layer, h = file:match("^.-__(.-)__h([%d%-]+)%.[pP][nN][gG]$")
    local height = h and tonumber((h:gsub("%-", "."))) or nil
    return layer or ("Layer " .. index), height and height * SCRIPTORIUM_HEIGHT_TO_THICKNESS
end

local function clampHeight(n)
    return math.min(math.max(n, MIN_THICKNESS), MAX_THICKNESS * MAX_COPIES)
end

-- "0.1*3" -> total 0.3, 3 copies; "0.3" -> 0.3, nil. Nil when it is neither.
local function parseHeight(text)
    text = tostring(text or ""):gsub("%s", "")
    local t, n = text:match("^([%d%.]+)[%*xX](%d+)$")
    if t then
        t, n = tonumber(t), tonumber(n)
        if not t or not n or n < 1 then return nil end
        t = math.min(math.max(t, MIN_THICKNESS), MAX_THICKNESS)
        n = math.min(n, MAX_COPIES)
        return t * n, n
    end
    local plain = tonumber(text)
    if plain and plain > 0 then return plain, nil end
    return nil
end

-- Height -> number of copies and the thickness of each.
local function splitHeight(height)
    if height <= MAX_THICKNESS then
        return 1, math.max(height, MIN_THICKNESS)
    end
    local count = math.min(math.ceil(height / MAX_THICKNESS - 1e-9), MAX_COPIES)
    return count, math.min(height / count, MAX_THICKNESS)
end

-- A layer's copies and thickness: its explicit count when it has one.
local function splitLayer(layer)
    if layer.copies then return layer.copies, layer.height / layer.copies end
    return splitHeight(layer.height)
end

-- What the Height field shows: the form it was typed in.
local function heightText(layer)
    if layer.copies then return fmt(layer.height / layer.copies) .. "*" .. layer.copies end
    return fmt(layer.height)
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
    ensureLayerIds()
    local rows = {}
    for i, layer in ipairs(state.layers) do
        local count = splitLayer(layer)
        rows[#rows + 1] = string.format([[
<HorizontalLayout preferredHeight="%d" spacing="6" childForceExpandWidth="false">
    %s
    %s
    %s
    %s
    <Button id="rm_%d" text="X" preferredWidth="30" onClick="onRemoveLayer" colors="#EF4444|#DC2626|#B91C1C|#EF444480" />
</HorizontalLayout>]],
            ROW_HEIGHT,
            string.format(
                '<Button id="nm_%d" preferredWidth="250" textAlignment="MiddleLeft" fontStyle="Normal" colors="' .. NAME_COLORS .. '" textColor="' .. NAME_TEXT_COLOR .. '" onClick="onSelectLayer" tooltip="Click to highlight and ping its pieces. %s">%s</Button>',
                i, xmlEscape(layer.url), xmlEscape(i .. ". " .. layer.name)),
            input("h_" .. i, heightText(layer), 80, "onLayerHeight", "None"),
            input("y_" .. i, fmt(layer.y), 80, "onLayerY"),
            label(count > 1 and ("x" .. count) or "", 50, 'class="dim"'),
            i)
    end

    local height = 368 + #state.layers * (ROW_HEIGHT + 6)

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
    <InputField id="paste" preferredHeight="70" lineType="MultiLineNewLine" fontSize="12" placeholder="Paste layer image links (one per line) or a Scriptorium stack JSON" onValueChanged="onPasteChanged" />
    <HorizontalLayout preferredHeight="32" spacing="6">
        <Button text="ADD" onClick="onAdd" colors="#3B82F6|#2563EB|#1D4ED8|#3B82F680" tooltip="Links are added to the list; a stack JSON replaces it" />
        <Button text="EDIT AS JSON" onClick="onEditAsJson" />
        <Button text="SAVE TO NOTE" onClick="onSaveToNote" colors="#8B5CF6|#7C3AED|#6D28D9|#8B5CF680" />
    </HorizontalLayout>
    <HorizontalLayout preferredHeight="32" spacing="6">
        <Button text="BUILD" onClick="onBuild" colors="#10B981|#059669|#047857|#10B98180" />
        <Button text="CLEAR PIECES" onClick="onClearPieces" colors="#F59E0B|#D97706|#B45309|#F59E0B80" />
        <Button id="btn_clear_layers" text="CLEAR LAYERS" onClick="onClearLayers" colors="#EF4444|#DC2626|#B91C1C|#EF444480" />
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

-- One button for the paste box: text that starts with "{" is a stack JSON and
-- replaces the list; anything else is links, added to it. A link never starts
-- with "{", so the two cannot be confused.
function onAdd(player)
    if not isAuthorized(player) then return end
    if pasteBuffer:match("^%s*{") then
        onImportJson(player)
    else
        onAddLinks(player)
    end
end

function onAddLinks(player)
    if not isAuthorized(player) then return end
    local added = 0
    for url in pasteBuffer:gmatch("%S+") do
        local index = #state.layers + 1
        local name, height = describeUrl(url, index)
        state.layers[index] = { url = url, name = name, height = height or DEFAULT_HEIGHT, y = 0 }
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

-- Replaces the layer list with a Scriptorium stack JSON (format in the header).
-- Validated whole before anything changes: a half-imported stack is worse than
-- none, because it builds and looks almost right.
function onImportJson(player)
    if not isAuthorized(player) then return end
    local ok, data = pcall(JSON.decode, pasteBuffer)
    if not ok or type(data) ~= "table" or type(data.layers) ~= "table" or #data.layers == 0 then
        tell(player, "That is not a stack JSON: expected an object with a non-empty \"layers\" list.", { 1, 0.6, 0.2 })
        return
    end
    local layers = {}
    for i, entry in ipairs(data.layers) do
        -- "height" may be a number or "0.1*3"; an explicit "copies" splits a number.
        local height, copies
        if type(entry) == "table" then height, copies = parseHeight(entry.height) end
        if type(entry) ~= "table" or type(entry.url) ~= "string" or entry.url == "" or not height then
            tell(player, "Layer " .. i .. " in the JSON needs a \"url\" and a positive \"height\".", { 1, 0.6, 0.2 })
            return
        end
        local n = tonumber(entry.copies)
        if not copies and n and n >= 1 then
            copies = math.min(math.floor(n), MAX_COPIES)
            height = math.min(math.max(height / copies, MIN_THICKNESS), MAX_THICKNESS) * copies
        end
        layers[i] = {
            url = entry.url,
            name = type(entry.name) == "string" and entry.name ~= "" and entry.name or ("Layer " .. i),
            height = copies and height or clampHeight(height),
            copies = copies,
            y = tonumber(entry.y) or 0,
        }
    end
    state.layers = layers
    state.map = type(data.map) == "string" and data.map or nil
    state.mapWidth = tonumber(data.width)
    state.mapHeight = tonumber(data.height)
    -- A note saved by SAVE TO NOTE also carries where and how it was built.
    local saved = type(data.stacker) == "table" and data.stacker or {}
    local o = type(saved.origin) == "table" and saved.origin or {}
    if tonumber(o.x) and tonumber(o.y) and tonumber(o.z) then
        state.origin = { x = tonumber(o.x), y = tonumber(o.y), z = tonumber(o.z) }
    end
    if tonumber(saved.rotation) then state.rotation = tonumber(saved.rotation) end
    if tonumber(saved.scale) and tonumber(saved.scale) > 0 then state.scale = tonumber(saved.scale) end
    if tonumber(saved.merge) and tonumber(saved.merge) >= 0 then state.merge = math.floor(tonumber(saved.merge)) end
    pasteBuffer = ""
    clearLayersArmed = false
    status = "Imported " .. #layers .. " layer(s)" .. (type(data.map) == "string" and (" of " .. data.map) or "") .. ". Press BUILD."
    rebuildUI()
end

-- Puts the current list in the paste box as stack JSON, to copy out, edit in bulk
-- and paste back with ADD.
-- The current list and settings as stack JSON: what EDIT AS JSON and SAVE TO
-- NOTE both write, and what ADD reads back.
local function stackJson()
    local layers = {}
    for i, layer in ipairs(state.layers) do
        -- A split layer goes out as "0.1*3", the way it was typed, rather than as
        -- 0.30000000000000004 plus a count; ADD reads either.
        local height = layer.copies and heightText(layer) or tonumber(fmt(layer.height))
        layers[i] = { name = layer.name, url = layer.url, height = height, y = layer.y }
    end
    return JSON.encode_pretty({
        format = "scriptorium-diorama-stack",
        version = 1,
        map = state.map,
        width = state.mapWidth,
        height = state.mapHeight,
        layers = layers,
        stacker = {
            origin = state.origin,
            rotation = state.rotation,
            scale = state.scale,
            merge = state.merge,
        },
    })
end

function onEditAsJson(player)
    if not isAuthorized(player) then return end
    pasteBuffer = stackJson()
    self.UI.setAttribute("paste", "text", pasteBuffer)
    tell(player, "Current layers are in the box above. Edit them and press ADD.")
end

-- Spawns a Notecard beside the controller holding the stack JSON, to keep a
-- finished stack. Its text pastes straight back into the box for ADD.
function onSaveToNote(player)
    if not isAuthorized(player) then return end
    if #state.layers == 0 then
        tell(player, "No layers to save.", { 1, 0.6, 0.2 })
        return
    end
    local p = self.getPosition()
    local title = "Diorama stack: " .. (state.map or "untitled") .. " (" .. os.date("%Y-%m-%d %H:%M") .. ")"
    local note = spawnObject({ type = "Notecard", position = { p.x + 3, p.y + 1, p.z }, sound = false })
    note.setName(title)
    note.setDescription(stackJson())
    tell(player, "Saved " .. #state.layers .. " layer(s) to the note \"" .. title .. "\".")
end

-- Two presses, because it throws away every height and Y typed so far. Spawned
-- pieces are untouched; that is CLEAR PIECES.
function onClearLayers(player)
    if not isAuthorized(player) then return end
    if not clearLayersArmed then
        clearLayersArmed = true
        self.UI.setAttribute("btn_clear_layers", "text", "SURE? PRESS AGAIN")
        Wait.time(function()
            if clearLayersArmed then
                clearLayersArmed = false
                self.UI.setAttribute("btn_clear_layers", "text", "CLEAR LAYERS")
            end
        end, 3)
        return
    end
    clearLayersArmed = false
    local removed = #state.layers
    state.layers = {}
    status = "Removed " .. removed .. " layer(s) from the list. Spawned pieces are untouched."
    rebuildUI()
end

-- Highlights every built piece of a layer and pings the top of the stack.
function onSelectLayer(player, _, id)
    if not isAuthorized(player) then return end
    local layer = state.layers[indexFromId(id)]
    if not layer then return end
    local tag = pieceTag(layer)
    local top, topY
    local count = 0
    for _, obj in ipairs(getObjects()) do
        if obj.memo == tag then
            obj.highlightOn(HIGHLIGHT_COLOR, HIGHLIGHT_SECONDS)
            count = count + 1
            local bounds = obj.getBounds()
            local y = bounds.center.y + bounds.size.y / 2
            if top == nil or y > topY then top, topY = bounds.center, y end
        end
    end
    if count == 0 then
        tell(player, layer.name .. " has no pieces. BUILD first.", { 1, 0.6, 0.2 })
        return
    end
    player.pingTable({ top.x, topY, top.z })

    local nameId = "nm_" .. indexFromId(id)
    local token = (nameLitToken[nameId] or 0) + 1
    nameLitToken[nameId] = token
    self.UI.setAttribute(nameId, "colors", NAME_LIT_COLORS)
    self.UI.setAttribute(nameId, "textColor", NAME_LIT_TEXT_COLOR)
    Wait.time(function()
        if nameLitToken[nameId] ~= token then return end
        self.UI.setAttribute(nameId, "colors", NAME_COLORS)
        self.UI.setAttribute(nameId, "textColor", NAME_TEXT_COLOR)
    end, HIGHLIGHT_SECONDS)
    tell(player, layer.name .. ": " .. count .. " piece(s).")
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

-- Not a numberField: "0.1*3" is not a number. Half-typed text ("0.1*") simply
-- does not parse and keeps the last valid value, like the number fields do.
function onLayerHeight(player, value, id)
    if not isAuthorized(player) then return end
    local layer = layerAt(id)
    local height, copies = parseHeight(value)
    if layer and height then
        layer.height, layer.copies = height, copies
    end
end

function onLayerHeightEnd(player, value, id)
    if not isAuthorized(player) then return end
    local layer = layerAt(id)
    if not layer then return end
    if not layer.copies then layer.height = clampHeight(layer.height) end
    -- Redrawn every time: the field is normalised and the copy count beside it
    -- may have changed. Focus has already left the field, so nothing is lost.
    rebuildUI()
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
    local removed = 0
    for _, obj in ipairs(getObjects()) do
        if isOurPiece(obj) then
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
        local count, thickness = splitLayer(layer)
        for c = 1, count do
            local obj = spawnObject({
                type = "Custom_Token",
                position = { o.x, o.y, o.z },
                rotation = { 0, state.rotation, 0 },
                -- Y stays 1: a piece's height comes from its thickness alone, so the
                -- Scale field only sizes the diorama across the table.
                scale = { s, 1, s },
                sound = false,
            })
            obj.setCustomObject({
                image = layer.url,
                thickness = thickness,
                merge_distance = state.merge,
                stackable = false,
            })
            obj.setLock(true)
            obj.memo = pieceTag(layer)
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
