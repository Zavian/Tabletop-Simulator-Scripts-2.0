-- Bundled by luabundle {"version":"1.7.0"}
local __bundle_require, __bundle_loaded, __bundle_register, __bundle_modules = (function(superRequire)
	local loadingPlaceholder = {[{}] = true}

	local register
	local modules = {}

	local require
	local loaded = {}

	register = function(name, body)
		if not modules[name] then
			modules[name] = body
		end
	end

	require = function(name)
		local loadedModule = loaded[name]

		if loadedModule then
			if loadedModule == loadingPlaceholder then
				return nil
			end
		else
			if not modules[name] then
				if not superRequire then
					local identifier = type(name) == 'string' and '\"' .. name .. '\"' or tostring(name)
					error('Tried to require ' .. identifier .. ', but no such module has been registered')
				else
					return superRequire(name)
				end
			end

			loaded[name] = loadingPlaceholder
			loadedModule = modules[name](require, loaded, register, modules)
			loaded[name] = loadedModule
		end

		return loadedModule
	end

	return require, loaded, register, modules
end)(require)
__bundle_register("__root", function(require, _LOADED, __bundle_register, __bundle_modules)
-- Main entry point for the TTS script
-- Load config first
require("src.data.config")


-- Laod core modules
local EventDispatcher = require("src.core.event_dispatcher")
local utils = require("src.core.utils")
local updater = require("src.core.updater")
local promise = require("src.core.promise")
local movement_measurement = require("src.core.movement_measurement")
local flying = require("src.core.flying")
local board_mirror = require("src.core.board_mirror")
local garden = require("src.core.garden")

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

-- Modules that hook Global's events themselves. Called last, so the handlers
-- above already exist and get chained rather than replaced.
board_mirror.attach()
garden.attach()

end)
__bundle_register("src.core.garden", function(require, _LOADED, __bundle_register, __bundle_modules)
-- Garden
--
-- A collapsible sidebar in Global's UI for browsing the digital garden
-- (https://dnd.zaes.dev) during play: an index grouped by section, a search
-- over titles and text, and every published note with its images and links.
--
-- Everything is fetched once, when the table loads, and every note is built
-- into the UI up front as a hidden page. Browsing never rebuilds the UI: each
-- page, index entry and the sidebar itself is shown per player through its
-- `visibility` attribute, so every player browses on their own. The sidebar
-- comes in a narrow and a wide size (Expand / Shrink), and clicking
-- an image opens it full screen, to zoom and drag around.
--
-- The UI is appended to whatever Global's XML already holds (from MARK on), so
-- the table's own Global UI is left alone. The note images are added to
-- Global's custom assets.
--
-- Wikilinks are resolved against the published notes by their last path part
-- (title, slug, or the title up to its first comma, so [[Elan]] finds "Elan,
-- Mother of the Gods"). TTS text cannot be clicked in parts, so links that
-- resolve are colored in the text and listed as buttons right under their
-- paragraph; the rest point into the private vault and are dimmed and slanted.

local Garden = {}

local SOURCE = "https://dnd.zaes.dev/garden.json"
local BASE = "https://dnd.zaes.dev"
-- Start of the garden's XML in Global's UI. TTS re-serializes the XML it hands
-- back (comments are dropped), so the first element's opening tag marks it.
local MARK = '<Panel id="garden_tab"'

local HEAD = 96       -- header height
local PAD = 18        -- page padding

-- Text colors follow the garden's theme (Tufte, dark; assets/garden-theme):
-- ink, muted and the unresolved-link color, with its accent for links. The
-- sidebar's own chrome (background, gold border and header) is the table's.
local INK = "#e8e6d9"
local MUTED = "#a59f8c"
local FAINT = "#908b7a"
local ACCENT = "#d97474"
local UNRESOLVED = "#877f6cb0"
local GOLD = "#d9b45b"
local BG = "#14161bf2"
local CARD = "#ffffff0d"

-- Blockquotes tagged with a color (color-blockquotes.css).
local QUOTE_COLORS = {
    red = "#e5484d", blue = "#3b82f6", cyan = "#22d3ee", green = "#4ade80",
    yellow = "#facc15", orange = "#fb923c", purple = "#a78bfa", pink = "#f472b6",
}

local notes = {}  -- { title, url, raw, section, haystack, blocks, links }
local byKey = {}  -- lowercased title / slug / title before its comma -> note index
local assets = {} -- image url -> image number
local imageList = {} -- image number -> custom asset name
local views = {}  -- color -> { open, wide, note, query, back, image, zoom }
local shown = {}  -- element id -> visibility last set, to skip repeat calls
local ready = false

------------------------------------------------------------------------------
-- Text helpers (plain finds only: patterns over whole notes hit "too complex")
------------------------------------------------------------------------------

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function split(s, sep)
    local out, i = {}, 1
    while true do
        local j = s:find(sep, i, true)
        if not j then
            out[#out + 1] = s:sub(i)
            return out
        end
        out[#out + 1] = s:sub(i, j - 1)
        i = j + #sep
    end
end

local function starts(s, prefix)
    return s:sub(1, #prefix) == prefix
end

-- For attribute values. TTS parses element content as markup and shows its
-- entities verbatim, so all text goes through `text` attributes instead.
local function esc(s)
    return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("\n", "&#10;"))
end

local function titleCase(slug)
    local words = {}
    for _, w in ipairs(split(slug, "-")) do
        if w == "and" or w == "of" or w == "the" and #words > 0 then
            words[#words + 1] = w
        else
            words[#words + 1] = w:sub(1, 1):upper() .. w:sub(2)
        end
    end
    return table.concat(words, " ")
end

------------------------------------------------------------------------------
-- Links and inline formatting
------------------------------------------------------------------------------

-- "Gods and Pantheons/Astravia/Abadar#Heading" -> "abadar"
local function linkKey(target)
    local hash = target:find("#", 1, true)
    if hash then target = target:sub(1, hash - 1) end
    local parts = split(target, "/")
    local name = trim(parts[#parts])
    if name:sub(-3) == ".md" then name = name:sub(1, -4) end
    return name:lower(), name
end

local function resolve(target)
    return byKey[(linkKey(target))]
end

-- Turns marker pairs (**bold**, *italic*, ~~struck~~) into rich text; an
-- unpaired marker stays as is.
local function emphasis(s, marker, pattern, open, close)
    local _, count = s:gsub(pattern, "")
    if count < 2 then return s end
    local n, last = 0, count - count % 2
    return (s:gsub(pattern, function()
        n = n + 1
        if n > last then return marker end
        return n % 2 == 1 and open or close
    end))
end

-- Markdown line(s) -> rich text. Resolved link targets are added to `links`.
local function inline(s, links)
    local out, i = {}, 1
    while true do
        local a = s:find("[[", i, true)
        local b = a and s:find("]]", a + 2, true)
        if not b then
            out[#out + 1] = s:sub(i)
            break
        end
        out[#out + 1] = s:sub(i, a - 1)
        local inner = s:sub(a + 2, b - 1)
        local target, label = inner, nil
        local bar = inner:find("|", 1, true)
        if bar then
            target, label = inner:sub(1, bar - 1), inner:sub(bar + 1)
            if target:sub(-1) == "\\" then target = target:sub(1, -2) end
        end
        local _, name = linkKey(target)
        label = label or name
        local idx = resolve(target)
        if idx then
            links[#links + 1] = idx
            out[#out + 1] = "<color=" .. ACCENT .. ">" .. label .. "</color>"
        else
            -- Points into the private vault: dim and slanted, like the site's.
            out[#out + 1] = "<i><color=" .. UNRESOLVED .. ">" .. label .. "</color></i>"
        end
        i = b + 2
    end
    local text = table.concat(out):gsub("\\([|*%[%]#_])", "%1")
    -- Unity text has no strikethrough: struck text is dimmed instead.
    text = emphasis(text, "~~", "~~", "<color=" .. FAINT .. "88>", "</color>")
    text = emphasis(text, "**", "%*%*", "<b>", "</b>")
    return emphasis(text, "*", "%*", "<i>", "</i>")
end

------------------------------------------------------------------------------
-- Markdown -> blocks
------------------------------------------------------------------------------

-- "![name\|opts](/img/user/x.png)" -> url, opts
local function parseImage(line)
    local close = line:find("](", 3, true)
    local stop = close and line:find(")", close + 2, true)
    if not stop then return nil end
    return line:sub(close + 2, stop - 1), line:sub(3, close - 1)
end

-- Splits a table row on bars that are not escaped (wikilink aliases are "\|").
local function cells(line)
    local out, cur, i = {}, {}, 1
    while i <= #line do
        local c = line:sub(i, i)
        if c == "\\" and line:sub(i + 1, i + 1) == "|" then
            cur[#cur + 1] = "\\|"
            i = i + 1
        elseif c == "|" then
            out[#out + 1] = trim(table.concat(cur))
            cur = {}
        else
            cur[#cur + 1] = c
        end
        i = i + 1
    end
    out[#out + 1] = trim(table.concat(cur))
    if out[1] == "" then table.remove(out, 1) end
    if out[#out] == "" then table.remove(out) end
    return out
end

local function isSeparatorRow(line)
    return line:gsub("[|:%-%s]", "") == ""
end

local parseBlocks

-- Strips one level of "> " from a run of callout lines and parses what is left.
local function parseCallout(lines)
    local inner = {}
    for _, l in ipairs(lines) do
        l = l:sub(2)
        if l:sub(1, 1) == " " then l = l:sub(2) end
        inner[#inner + 1] = l
    end
    local kind, title, tint = "note", nil, nil
    -- "#orange Title": a color tag on a plain quote, with an optional title.
    if inner[1] and inner[1]:match("^#%a") then
        local space = inner[1]:find(" ", 1, true)
        local tag = (space and inner[1]:sub(2, space - 1) or inner[1]:sub(2)):lower()
        tint = QUOTE_COLORS[tag]
        title = space and trim(inner[1]:sub(space + 1)) or nil
        if title == "" then title = nil end
        table.remove(inner, 1)
    elseif inner[1] and starts(inner[1], "[!") then
        local close = inner[1]:find("]", 3, true)
        if close then
            kind = inner[1]:sub(3, close - 1):lower()
            title = trim(inner[1]:sub(close + 1))
            if title == "" then title = nil end
            table.remove(inner, 1)
        end
    end
    return { kind = "box", style = kind, title = title, tint = tint, blocks = parseBlocks(inner) }
end

parseBlocks = function(lines)
    local blocks, para = {}, {}
    local function flush()
        if #para > 0 then
            blocks[#blocks + 1] = { kind = "text", md = table.concat(para, "\n") }
            para = {}
        end
    end

    local i = 1
    while i <= #lines do
        local line = lines[i]:gsub("\r$", "")
        local bare = trim(line)
        if starts(bare, ">") then
            flush()
            local run = {}
            while i <= #lines and starts(trim(lines[i]), ">") do
                run[#run + 1] = trim(lines[i]:gsub("\r$", ""))
                i = i + 1
            end
            blocks[#blocks + 1] = parseCallout(run)
            i = i - 1
        elseif starts(bare, "|") then
            flush()
            local rows = {}
            while i <= #lines and starts(trim(lines[i]), "|") do
                local row = trim(lines[i]:gsub("\r$", ""))
                if not isSeparatorRow(row) then rows[#rows + 1] = cells(row) end
                i = i + 1
            end
            blocks[#blocks + 1] = { kind = "table", rows = rows }
            i = i - 1
        elseif bare == "" then
            flush()
        elseif bare == "---" or bare == "***" then
            flush()
            blocks[#blocks + 1] = { kind = "rule" }
        elseif bare:match("^#+%s") then
            flush()
            local level = #bare:match("^#+")
            blocks[#blocks + 1] = { kind = "heading", level = level, md = trim(bare:sub(level + 1)) }
        elseif starts(bare, "#") then
            -- "#orange The Golden Spark": a tag (styling in the vault) leading a title line.
            local space = bare:find(" ", 1, true)
            if space then para[#para + 1] = "**" .. trim(bare:sub(space + 1)) .. "**" end
        elseif starts(bare, "![") and not starts(bare, "![[") then
            flush()
            local url, opts = parseImage(bare)
            if url then blocks[#blocks + 1] = { kind = "image", url = url, opts = opts } end
        elseif starts(bare, "![[") then
            flush() -- embedded vault note or attachment: not published
        elseif starts(bare, "- ") or starts(bare, "* ") or starts(bare, "+ ") then
            para[#para + 1] = "  –  " .. bare:sub(3) -- TTS's font has no bullet glyph
        else
            para[#para + 1] = bare
        end
        i = i + 1
    end
    flush()
    return blocks
end

------------------------------------------------------------------------------
-- Loading
------------------------------------------------------------------------------

local function assetFor(url)
    if not starts(url, "http") then url = BASE .. url end
    if not assets[url] then
        imageList[#imageList + 1] = "garden_img_" .. (#imageList + 1)
        assets[url] = #imageList
    end
    return imageList[assets[url]], assets[url]
end

local function collectImages(blocks)
    for _, b in ipairs(blocks) do
        if b.kind == "image" then b.asset, b.n = assetFor(b.url) end
        if b.kind == "box" then collectImages(b.blocks) end
    end
end

local function index(data)
    notes, byKey, assets, imageList = {}, {}, {}, {}
    for _, n in ipairs(data) do
        if type(n) == "table" and n.title and n.raw then
            local section = split(n.url or "", "/")[2] or ""
            notes[#notes + 1] = {
                title = n.title,
                url = n.url or "",
                raw = n.raw,
                section = section ~= "" and titleCase(section) or "Notes",
            }
        end
    end
    table.sort(notes, function(a, b)
        if a.section ~= b.section then return a.section < b.section end
        return a.title:lower() < b.title:lower()
    end)
    for i, n in ipairs(notes) do
        for _, key in ipairs({ n.title, split(n.url, "/")[#split(n.url, "/") - 1] or "", split(n.title, ",")[1] }) do
            key = trim(key):lower()
            if key ~= "" and not byKey[key] then byKey[key] = i end
        end
    end
    for _, n in ipairs(notes) do
        n.blocks = parseBlocks(split(n.raw, "\n"))
        collectImages(n.blocks)
        -- Search what readers see: link labels, not the vault paths behind them.
        local shownText = inline(n.raw, {}):gsub("<[^>]+>", "")
        n.haystack = (n.title .. "\n" .. shownText):lower()
    end
end

------------------------------------------------------------------------------
-- XML
------------------------------------------------------------------------------

-- The sidebar is built once per size and each player is shown the one they
-- picked: TTS lays out by attributes that are the same for everyone, so a
-- per-player width needs its own copy.
local SIZES = {
    { key = "n", W = 470, H = 880, image = 300, banner = 200, grid = 3, chips = 2, body = 15 },
    { key = "w", W = 860, H = 920, image = 520, banner = 320, grid = 4, chips = 3, body = 16 },
}

-- Lightbox: an image's base size on screen, and the zoom steps.
local LB_W, LB_H = 1700, 880
local ZOOMS = { 1, 1.5, 2, 3, 4 }

-- The tab's icon: "Open Book" by Icons8 (https://icons8.com), tinted gold.
local BOOK_ICON = "https://img.icons8.com/?size=100&id=38390&format=png&color=f2cf74"
-- (TTS fails to load the path form, .../ios-filled/100/f2cf74/open-book.png.)

local function id(L, name)
    return "garden_" .. L.key .. "_" .. name
end

-- raycastTarget lets the scroll wheel reach the page over plain text too.
local function text(rich, size, color, extra)
    extra = extra or ""
    local align = extra:find("alignment=", 1, true) and "" or ' alignment="UpperLeft"'
    return '<Text fontSize="' .. size .. '" color="' .. (color or INK) .. '"' .. align .. ' raycastTarget="true"'
        .. extra .. ' text="' .. esc(rich) .. '" />'
end

-- TTS tints a button's label with its `colors` too, so those stay opaque (a
-- see-through state fades the label) and the background comes from `color`.
-- TTS recolors a button's own label whenever its state changes (faded or
-- darkened after a hover), so labels are Text children of a label-less button,
-- and `colors` only washes the button's background: `bg` normally, `hover`
-- under the pointer.
local function btn(onClick, attrs, bg, hover, label, size, color, align)
    return '<Button onClick="' .. onClick .. '"' .. attrs
        .. ' colors="' .. bg .. "|" .. hover .. "|" .. hover .. "|" .. bg .. '">'
        .. '<Text text="' .. esc(label) .. '" fontSize="' .. size .. '" color="' .. color .. '"'
        .. (align == "left" and ' alignment="MiddleLeft" offsetXY="12 0"' or ' alignment="MiddleCenter"') .. " />"
        .. "</Button>"
end

-- A row in the index: plain text, washed with the accent under the pointer.
local function row(label, onClick, attrs)
    return btn(onClick, ' preferredHeight="30" minHeight="30"' .. (attrs or ""), "#00000000", "#d974742e", "    " .. label, 15, INK, "left")
end

-- The published notes a block links to, as a row of buttons under it.
-- `width` is the room the row has; `self` is the note being rendered.
local function chips(L, links, width, self)
    local seen, list = { [self] = true }, {}
    for _, idx in ipairs(links) do
        if not seen[idx] then
            seen[idx] = true
            list[#list + 1] = idx
        end
    end
    if #list == 0 then return "" end
    local cols = L.chips
    local cell = math.floor((width - 6 * (cols - 1)) / cols)
    local out = { '<GridLayout cellSize="' .. cell .. ' 28" spacing="6 6" constraint="FixedColumnCount" constraintCount="'
        .. cols .. '" preferredHeight="' .. (math.ceil(#list / cols) * 34 - 6) .. '">' }
    for _, idx in ipairs(list) do
        out[#out + 1] = btn("gardenOpen(" .. idx .. ")", "", "#d974741f", "#d9747452", "›  " .. notes[idx].title, 13, ACCENT, "left")
    end
    out[#out + 1] = "</GridLayout>"
    return table.concat(out)
end

local function image(asset, n, attrs)
    return '<Image image="' .. asset .. '" preserveAspect="true" raycastTarget="true" onClick="gardenImage(' .. n .. ')"'
        .. ' tooltip="Click to enlarge" tooltipPosition="Above"' .. (attrs or "") .. ' />'
end

local renderBlocks

local function renderTable(L, b, ctx)
    local head = b.rows[1] or {}
    local out = {}
    for r = 2, #b.rows do
        local row, lines, links = b.rows[r], {}, {}
        lines[1] = "<b>" .. inline(row[1] or "", links) .. "</b>"
        for c = 2, #row do
            local label = inline(head[c] or "", {}):gsub("</?b>", "")
            lines[#lines + 1] = "<color=" .. MUTED .. ">" .. label .. "</color>   " .. inline(row[c], links)
        end
        out[#out + 1] = '<VerticalLayout color="' .. CARD .. '" padding="12 12 8 8" spacing="6" childForceExpandHeight="false">'
            .. text(table.concat(lines, "\n"), L.body) .. chips(L, links, ctx.width - 24, ctx.self) .. "</VerticalLayout>"
    end
    return table.concat(out)
end

local function renderBox(L, b, ctx)
    -- An image-only callout ([!grid]) is a gallery.
    local images = {}
    for _, c in ipairs(b.blocks) do
        if c.kind == "image" then images[#images + 1] = c end
    end
    if b.style == "grid" and #images == #b.blocks and #images > 0 then
        local cols = L.grid
        local cell = math.floor((ctx.width - 6 * (cols - 1)) / cols)
        local out = { '<GridLayout cellSize="' .. cell .. " " .. cell .. '" spacing="6 6" constraint="FixedColumnCount" constraintCount="'
            .. cols .. '" preferredHeight="' .. (math.ceil(#images / cols) * (cell + 6)) .. '">' }
        for _, img in ipairs(images) do out[#out + 1] = image(img.asset, img.n) end
        out[#out + 1] = "</GridLayout>"
        return table.concat(out)
    end

    local inner = { self = ctx.self, width = ctx.width - 28, color = b.tint or ctx.color }
    local out = {}
    -- A colored quote is, as on the site, a wash of its color with italic text.
    local wash = b.tint and b.tint .. "0f" or CARD
    out[#out + 1] = '<VerticalLayout color="' .. wash .. '" padding="14 14 12 12" spacing="6" childForceExpandHeight="false">'
    if b.title then
        local links = {}
        out[#out + 1] = text("<i>" .. inline(b.title, links) .. "</i>", L.body + 1, inner.color)
        out[#out + 1] = chips(L, links, inner.width, ctx.self)
    end
    out[#out + 1] = renderBlocks(L, b.blocks, inner, b.style == "quote" or b.tint ~= nil)
    out[#out + 1] = "</VerticalLayout>"
    return table.concat(out)
end

-- Headings as on the site: italic, regular weight, in ink, well above the body.
local HEADING_SIZE = { 26, 22, 19, 17, 16, 15 }

-- ctx: { self = note index, width = room for content, color = text color or nil }
renderBlocks = function(L, blocks, ctx, italic)
    local out = {}
    for _, b in ipairs(blocks) do
        if b.kind == "text" or b.kind == "heading" then
            local links = {}
            local rich = inline(b.md, links)
            if b.kind == "heading" then
                -- Extra room above a heading, on top of the layout's spacing.
                if #out > 0 then out[#out + 1] = '<Panel preferredHeight="10" minHeight="10" />' end
                out[#out + 1] = text("<i>" .. rich .. "</i>", (HEADING_SIZE[b.level] or 15) + L.body - 15, ctx.color)
            else
                out[#out + 1] = text(italic and "<i>" .. rich .. "</i>" or rich, L.body, ctx.color)
            end
            out[#out + 1] = chips(L, links, ctx.width, ctx.self)
        elseif b.kind == "image" then
            local h = b.opts:find("banner", 1, true) and L.banner or L.image
            out[#out + 1] = image(b.asset, b.n, ' preferredHeight="' .. h .. '" minHeight="' .. h .. '"')
        elseif b.kind == "rule" then
            out[#out + 1] = '<Panel color="#ffffff22" preferredHeight="1" minHeight="1" />'
        elseif b.kind == "table" then
            out[#out + 1] = renderTable(L, b, ctx)
        elseif b.kind == "box" then
            out[#out + 1] = renderBox(L, b, ctx)
        end
    end
    return table.concat(out)
end

-- A thin gold rule with a star at its middle.
local function divider()
    local line = '<Panel color="#d9b45b40" preferredHeight="1" minHeight="1" flexibleWidth="1" />'
    return '<HorizontalLayout preferredHeight="16" minHeight="16" spacing="10" childAlignment="MiddleCenter"'
        .. ' childForceExpandWidth="false" childForceExpandHeight="false">'
        .. line .. '<Text text="✦" fontSize="11" color="' .. GOLD .. '" alignment="MiddleCenter" preferredWidth="12" />' .. line
        .. "</HorizontalLayout>"
end

-- Width the content of a page has, inside its padding and the scrollbar.
local function contentWidth(L)
    return L.W - 14 - 2 * PAD
end

-- A scrolling page in the sidebar's body, hidden until someone opens it. The
-- scroll view's all-but-transparent color makes it catch the wheel everywhere
-- on the page; fully transparent, the wheel fell through to the camera.
local function page(L, pageId, content, spacing)
    local h = L.H - HEAD
    return '<Panel id="' .. pageId .. '" active="false" rectAlignment="LowerCenter" width="' .. L.W .. '" height="' .. h .. '">'
        .. '<VerticalScrollView width="' .. L.W .. '" height="' .. h .. '" color="#00000001" raycastTarget="true"'
        .. ' verticalScrollbarVisibility="AutoHide" horizontalScrollbarVisibility="AutoHide"'
        .. ' scrollbarColors="#00000000|#d9b45b55|#d9b45b99|#00000000" scrollbarBackgroundColor="#00000000"'
        .. ' scrollSensitivity="40" movementType="Clamped">'
        .. '<VerticalLayout id="' .. pageId .. '_body" rectAlignment="UpperLeft" pivot="0 1" contentSizeFitter="vertical" width="' .. (L.W - 14) .. '"'
        .. ' padding="' .. PAD .. " " .. PAD .. ' 10 28" spacing="' .. (spacing or 10) .. '" childForceExpandHeight="false" childForceExpandWidth="true">'
        .. content .. "</VerticalLayout></VerticalScrollView></Panel>"
end

local function renderNote(L, i, n)
    local out = {
        text("<i>" .. n.title .. "</i>", 30, INK),
        text(n.section, 13, MUTED),
        divider(),
        renderBlocks(L, n.blocks, { self = i, width = contentWidth(L) }),
    }
    return page(L, id(L, "note_" .. i), table.concat(out))
end

-- The index is a tree, as on the site: sections fold open and shut per
-- player. Each section has an open and a shut heading (their arrows differ),
-- each shown to whoever has it that way.
local function renderIndex(L)
    local out, section = {}, nil
    for i, n in ipairs(notes) do
        if n.section ~= section then
            section = n.section
            for _, state in ipairs({ "shut", "open" }) do
                out[#out + 1] = btn("gardenSection(" .. i .. ")",
                    ' id="' .. id(L, "sec_" .. state .. "_" .. i) .. '" active="false" preferredHeight="32" minHeight="32"',
                    "#00000000", "#d9b45b26", (state == "open" and "▾  " or "▸  ") .. section, 15, MUTED, "left")
            end
        end
        out[#out + 1] = row(n.title, "gardenOpen(" .. i .. ")", ' id="' .. id(L, "item_" .. i) .. '" active="false"')
    end
    out[#out + 1] = text("No notes match.", 15, MUTED, ' id="' .. id(L, "none") .. '" active="false"')
    return page(L, id(L, "index"), table.concat(out), 2)
end

-- `align` is the corner the offset is from (UpperLeft / UpperRight).
local function headerButton(label, onClick, align, x, y, w, tooltip, base)
    local attrs = ' rectAlignment="' .. align .. '" offsetXY="' .. x .. " " .. y .. '" width="' .. w .. '" height="32"'
        .. (tooltip and ' tooltip="' .. tooltip .. '" tooltipPosition="Below"' or "")
    -- Single glyphs (‹, ✕) read small at text size.
    return btn(onClick, attrs, base or "#ffffff14", "#d9b45b55", label, #label <= 3 and 20 or 15, INK)
end

local function renderSide(L)
    local wide = L.key == "w"
    local out = {}
    out[#out + 1] = '<Panel id="' .. id(L, "side") .. '" active="false" rectAlignment="MiddleRight" offsetXY="-8 0" width="' .. L.W
        .. '" height="' .. L.H .. '" color="' .. BG .. '" outline="#d9b45b55" outlineSize="1 1">'
    -- Row one: the title, and closing on the right.
    out[#out + 1] = '<Text rectAlignment="UpperLeft" offsetXY="' .. PAD .. ' -12" width="' .. (L.W - 2 * PAD - 40) .. '" height="34"'
        .. ' fontSize="22" fontStyle="Italic" color="' .. GOLD .. '" alignment="MiddleLeft" text="Astravian Compendium" />'
    out[#out + 1] = headerButton("✕", "gardenToggle", "UpperRight", -PAD, -13, 32, "Hide the compendium", "#00000000")
    -- Row two: back, index, search, and this player's sidebar size.
    out[#out + 1] = headerButton("‹", "gardenBack", "UpperLeft", PAD, -52, 32, "Back")
    out[#out + 1] = headerButton("Index", "gardenHome", "UpperLeft", PAD + 38, -52, 60)
    out[#out + 1] = headerButton(wide and "Shrink" or "Expand", "gardenResize", "UpperRight", -PAD, -52, 76,
        wide and "Back to the narrow sidebar" or "A wider sidebar, with bigger pictures", "#d9b45b40")
    out[#out + 1] = '<InputField id="' .. id(L, "search") .. '" onValueChanged="gardenSearch" rectAlignment="UpperLeft" offsetXY="' .. (PAD + 104)
        .. ' -52" width="' .. (L.W - 2 * PAD - 104 - 82) .. '" height="32" fontSize="15" placeholder="Search..."'
        .. ' colors="#ffffff10|#ffffff18|#ffffff20|#ffffff08" textColor="' .. INK .. '" characterLimit="60" />'
    out[#out + 1] = '<Panel rectAlignment="UpperCenter" offsetXY="0 -' .. (HEAD - 1) .. '" width="' .. L.W .. '" height="1" color="#d9b45b40" />'
    out[#out + 1] = renderIndex(L)
    for i, n in ipairs(notes) do out[#out + 1] = renderNote(L, i, n) end
    out[#out + 1] = "</Panel>"
    return table.concat(out, "\n")
end

-- Full-screen image viewer, one draggable image per picture.
local function renderLightbox()
    local out = { '<Panel id="garden_lb" active="false" width="6000" height="6000" color="#000000f2" raycastTarget="true"' .. '>' }
    for n, asset in ipairs(imageList) do
        out[#out + 1] = '<Panel id="garden_lb_' .. n .. '" active="false" width="' .. LB_W .. '" height="' .. LB_H .. '"'
            .. ' allowDragging="true" returnToOriginalPositionWhenReleased="false" color="#00000001" raycastTarget="true">'
            .. '<Image id="garden_lb_img_' .. n .. '" image="' .. asset .. '" preserveAspect="true" width="' .. LB_W .. '" height="' .. LB_H .. '" />'
            .. "</Panel>"
    end
    -- The backdrop is far bigger than the screen, so the bar sits off its center.
    local function lbButton(label, onClick, x, w)
        return btn(onClick, ' offsetXY="' .. x .. ' 0" width="' .. w .. '" height="36"', "#ffffff14", "#d9b45b55", label, 17, INK)
    end
    out[#out + 1] = '<Panel offsetXY="0 -' .. (LB_H / 2 + 34) .. '" width="560" height="52" color="#14161bf2" outline="#d9b45b55" outlineSize="1 1">'
        .. '<Text offsetXY="-196 0" width="140" height="40" fontSize="14" color="' .. MUTED .. '" alignment="MiddleCenter" text="Drag to pan" />'
        .. lbButton("−", "gardenZoom(-1)", -86, 48) .. lbButton("+", "gardenZoom(1)", -32, 48)
        .. lbButton("Fit", "gardenZoom(0)", 36, 76) .. lbButton("Close", "gardenImageClose", 140, 112)
        .. "</Panel>"
    out[#out + 1] = "</Panel>"
    return table.concat(out)
end

local function renderXml()
    local out = {}
    -- The tab: a book on the right edge, for whoever has the sidebar closed.
    out[#out + 1] = MARK .. ' onClick="gardenToggle" rectAlignment="MiddleRight" width="46" height="54"'
        .. ' color="' .. BG .. '" outline="#d9b45b88" outlineSize="1 1" raycastTarget="true"'
        .. ' tooltip="The Garden" tooltipPosition="Left">'
        .. '<Image id="garden_tab_icon" image="garden_tab_book" width="30" height="30" raycastTarget="false" />'
        .. "</Panel>"
    for _, L in ipairs(SIZES) do out[#out + 1] = renderSide(L) end
    out[#out + 1] = renderLightbox()
    return table.concat(out, "\n")
end

------------------------------------------------------------------------------
-- Per-player views
------------------------------------------------------------------------------

local function view(color)
    if not views[color] then
        views[color] = { open = false, wide = false, note = nil, query = "", back = {}, image = nil, zoom = 1, unfolded = {} }
    end
    return views[color]
end

local function matches(n, query)
    return query == "" or n.haystack:find(query, 1, true) ~= nil
end

-- Shows `elementId` only to `colors` (players at the table); nobody at all
-- means hidden.
--
-- No show/hide animations: they only play through UI.show / UI.hide, which
-- ignore per-player visibility, and an element hidden by one and switched
-- back on through `active` stays where the animation left it (off-screen,
-- or faded out). Inside a hidden sidebar UI.hide never even finishes.
local function showTo(elementId, colors)
    local vis = table.concat(colors, "|")
    if shown[elementId] == vis then return end
    shown[elementId] = vis
    if vis == "" then
        UI.setAttribute(elementId, "active", "false")
    else
        UI.setAttributes(elementId, { visibility = vis, active = "true" })
    end
end

local function refresh()
    if not ready then return end
    local closed, onIndex, empty, viewing = {}, {}, {}, {}
    local side = { n = {}, w = {} }
    local onNote, itemTo, onImage = {}, {}, {}
    local sectionOpen, sectionShut = {}, {} -- section -> colors
    for i, n in ipairs(notes) do
        onNote[i], itemTo[i] = {}, {}
        sectionOpen[n.section], sectionShut[n.section] = {}, {}
    end
    for n in ipairs(imageList) do onImage[n] = {} end

    local seated = {}
    for _, p in ipairs(Player.getPlayers()) do seated[#seated + 1] = p.color end
    for _, c in ipairs(seated) do
        local v = view(c)
        if v.open then
            table.insert(side[v.wide and "w" or "n"], c)
        else
            table.insert(closed, c)
        end
        if v.image then
            table.insert(viewing, c)
            table.insert(onImage[v.image], c)
        end
        if v.note then
            table.insert(onNote[v.note], c)
        else
            table.insert(onIndex, c)
            -- Searching unfolds every section with a match and hides the rest.
            local searching, any, listed = v.query ~= "", false, {}
            for i, n in ipairs(notes) do
                local s = n.section
                if not listed[s] and (not searching or matches(n, v.query)) then
                    listed[s] = true
                    table.insert((searching or v.unfolded[s]) and sectionOpen[s] or sectionShut[s], c)
                end
                if (searching and matches(n, v.query)) or (not searching and v.unfolded[s]) then
                    table.insert(itemTo[i], c)
                    any = true
                end
            end
            if searching and not any then table.insert(empty, c) end
        end
    end

    showTo("garden_tab", closed)
    -- Below a sidebar, who sees what is the same for both sizes: whoever
    -- uses the other size has that whole sidebar hidden anyway.
    for _, L in ipairs(SIZES) do
        showTo(id(L, "side"), side[L.key])
        showTo(id(L, "index"), onIndex)
        showTo(id(L, "none"), empty)
        local section = nil
        for i, n in ipairs(notes) do
            showTo(id(L, "note_" .. i), onNote[i])
            showTo(id(L, "item_" .. i), itemTo[i])
            if n.section ~= section then
                section = n.section
                showTo(id(L, "sec_open_" .. i), sectionOpen[section])
                showTo(id(L, "sec_shut_" .. i), sectionShut[section])
            end
        end
    end
    showTo("garden_lb", viewing)
    for n in ipairs(imageList) do showTo("garden_lb_" .. n, onImage[n]) end
end

local function go(color, note)
    local v = view(color)
    if v.note == note then return end
    table.insert(v.back, v.note or 0)
    v.note = note
    refresh()
end

function gardenToggle(player)
    local v = view(player.color)
    v.open = not v.open
    refresh()
end

-- The two sizes have their own search fields, and a field's text lives on
-- each client, so the search is cleared rather than carried over.
function gardenResize(player)
    local v = view(player.color)
    v.wide = not v.wide
    v.query = ""
    refresh()
end

function gardenOpen(player, value)
    local idx = tonumber(value)
    if idx and notes[idx] then go(player.color, idx) end
end

-- Folds a section of the index open or shut; value is its first note.
function gardenSection(player, value)
    local n = notes[tonumber(value) or 0]
    if not n then return end
    local v = view(player.color)
    v.unfolded[n.section] = not v.unfolded[n.section] or nil
    refresh()
end

function gardenHome(player)
    go(player.color, nil)
end

function gardenBack(player)
    local v = view(player.color)
    local prev = table.remove(v.back)
    if prev == nil then return end
    v.note = prev ~= 0 and prev or nil
    refresh()
end

function gardenSearch(player, value)
    local v = view(player.color)
    v.query = trim((value or "")):lower()
    if v.note then
        table.insert(v.back, v.note)
        v.note = nil
    end
    refresh()
end

-- Size and position belong to the image's element, so two players viewing the
-- same picture share its zoom and pan.
local function placeImage(n, zoom)
    local w, h = math.floor(LB_W * zoom), math.floor(LB_H * zoom)
    UI.setAttributes("garden_lb_" .. n, { width = w, height = h, offsetXY = "0 0" })
    UI.setAttributes("garden_lb_img_" .. n, { width = w, height = h })
end

function gardenImage(player, value)
    local n = tonumber(value)
    if not (n and imageList[n]) then return end
    local v = view(player.color)
    v.image, v.zoom = n, 1
    placeImage(n, 1)
    refresh()
end

function gardenImageClose(player)
    view(player.color).image = nil
    refresh()
end

-- step: 1 zooms in, -1 out, 0 fits the screen again.
function gardenZoom(player, value)
    local v = view(player.color)
    if not v.image then return end
    local step, at = tonumber(value) or 0, 1
    for k, z in ipairs(ZOOMS) do
        if z == v.zoom then at = k end
    end
    at = step == 0 and 1 or math.max(1, math.min(#ZOOMS, at + step))
    v.zoom = ZOOMS[at]
    placeImage(v.image, v.zoom)
end

------------------------------------------------------------------------------
-- Building
------------------------------------------------------------------------------

-- Runs `fn` once the UI has started and finished loading whatever was just set.
local function afterLoading(fn)
    Wait.frames(function()
        Wait.condition(fn, function() return not UI.loading end)
    end, 2)
end

local function install()
    -- Keep the table's own assets, add the note images. They load before the
    -- XML is set: images that are not cached yet do not show otherwise.
    local list = {}
    for _, a in ipairs(UI.getCustomAssets() or {}) do
        if not starts(a.name, "garden_") then list[#list + 1] = a end
    end
    for url, n in pairs(assets) do list[#list + 1] = { name = imageList[n], url = url } end
    list[#list + 1] = { name = "garden_tab_book", url = BOOK_ICON }
    UI.setCustomAssets(list)
    shown, ready = {}, false

    afterLoading(function()
        local xml = UI.getXml() or ""
        local cut = xml:find(MARK, 1, true)
        if cut then xml = xml:sub(1, cut - 1) end
        UI.setXml(xml .. "\n" .. renderXml())
        afterLoading(function()
            ready = true
            refresh()
        end)
    end)
end

function Garden.load()
    WebRequest.get(SOURCE, function(req)
        if req.is_error or req.response_code ~= 200 then
            print("Garden: could not load " .. SOURCE .. " (" .. tostring(req.error or req.response_code) .. ")")
            return
        end
        local ok, data = pcall(JSON.decode, req.text)
        if not ok or type(data) ~= "table" then
            print("Garden: " .. SOURCE .. " is not a list of notes")
            return
        end
        index(data)
        Wait.condition(install, function() return not UI.loading end)
    end)
end

------------------------------------------------------------------------------
-- Wiring
------------------------------------------------------------------------------

local function hook(name, handler)
    local previous = _G[name]
    _G[name] = function(...)
        local result = nil
        if previous then result = previous(...) end
        handler(...)
        return result
    end
end

function Garden.attach()
    hook("onLoad", Garden.load)
    -- Who is at the table decides who is shown what; the list updates a frame later.
    local function later() Wait.frames(refresh, 1) end
    hook("onPlayerConnect", later)
    hook("onPlayerDisconnect", later)
    hook("onPlayerChangeColor", later)
end

return Garden

end)
__bundle_register("src.core.board_mirror", function(require, _LOADED, __bundle_register, __bundle_modules)
-- Board Mirror
--
-- Mirrors tokens tagged movement_measurement from one board onto others, as
-- flat shadows that follow the token while it is carried. Neither the boards
-- nor the tokens get any script: everything lives here and runs in Global.
-- main.lua only calls BoardMirror.attach(), which hooks the Global events this
-- module needs (see Wiring, at the bottom).
--
-- Pins. Give any object the script in src/modules/mirror_pin.lua and drop it on
-- a board: that object is now a master pin and the board a master. Right-click
-- the master pin and "Spawn slave" (a script-free copy of the master), drop the
-- slave on another board: tokens on the master board now get a shadow on that
-- board. A master can have any number of slaves, and a board can carry any
-- number of pins. The board a pin belongs to is the first locked object under it
-- (a ray cast straight down), so moving a pin to another board re-links it.
--
-- The link itself lives on the pins, in their memos: the master holds a link id
-- and each slave the id of its master. So links survive bags, copy/paste and the
-- map bundler (bundle-map.lua / map-positioner.lua): a pin that leaves the table
-- only drops out until it comes back and its slaves keep their pins. Pins are
-- set up on game load, when dropped, and with the master's "Mirror: initialize",
-- which sets up the master and all its slaves and finds their boards: use it
-- after unbundling. Deleting a master deletes its slaves. Pin descriptions are
-- left alone, since that is where the bundler keeps a piece's home transform.
-- Every master has a color worked out from its GUID and each of its slaves gets
-- its own: pins are tinted with theirs and named after the other end,
-- "Master (red, teal)" and "Slave (navy)".
--
-- Shadows. A flat disc the size of the token's footprint, in the token's color
-- brought to full brightness: blue for player tokens, the token's own tint
-- (enemy, ally, neutral) for the rest, mixed with pink when it is face down. It
-- carries the token's name, is locked, not interactable and has its colliders
-- turned off. It exists while its token is over the master board, and is
-- highlighted in the holder's color while the token is carried. It is
-- invisible to whoever its token is invisible to, and a slave can be set to
-- "GM only", hiding its shadows from everyone but Black as well.
--
-- Pings. Pinging a shadow pings its token and the other way round; pinging a
-- slave pin pings its master and the other way round.
--
-- Updates. Picking up, dropping, flipping or spinning a token follows it every
-- TICK until it settles. A HEARTBEAT catches the rest: tokens moved, spawned,
-- renamed or retinted by scripts, boards that moved, and stray shadows brought
-- back by undo.
--
-- Mapping. A position is taken into the master board's local space and back out
-- of the slave board's, so the two boards can sit anywhere, at any rotation and
-- scale. Height is not mapped: the shadow lies on the slave board's surface,
-- raised by however far the token was resting above the master board's surface
-- (stairs, platforms inside a diorama).
--
-- Only which boards have their pins hidden is kept in SAVED_DATA.BOARD_MIRROR;
-- links from older saves, which kept them there, are moved onto the pins' memos
-- on load. Shadows are not saved: on load the old ones are deleted and rebuilt.

local utils = require("src.core.utils")
require("src.data.config")

local BoardMirror = {}

-- Click target for the ghosts' name labels, which are buttons owned by Global.
function boardMirror_noop() end

local TICK = 0.05
local SHADOW_THICKNESS = 0.05
local LABEL_HEIGHT = 0.15
local HEARTBEAT = 1
local BOARD_GLOW = 2

-- Pin colors: bright hues, so pins and names read well on dark boards.
local PIN_COLORS = {
    { name = "red",     hex = "#FF4040" },
    { name = "orange",  hex = "#FF9A2E" },
    { name = "yellow",  hex = "#FFE53B" },
    { name = "lime",    hex = "#B6FF3B" },
    { name = "green",   hex = "#3BFF6A" },
    { name = "mint",    hex = "#3BFFC4" },
    { name = "cyan",    hex = "#3BE8FF" },
    { name = "sky",     hex = "#3B9DFF" },
    { name = "blue",    hex = "#5B5BFF" },
    { name = "violet",  hex = "#A35BFF" },
    { name = "magenta", hex = "#F03BFF" },
    { name = "pink",    hex = "#FF5BA8" },
}
local PIN_COLOR_BY_NAME = {}
for _, c in ipairs(PIN_COLORS) do PIN_COLOR_BY_NAME[c.name] = c end

local PLAYER_COLOR = CONFIG.palette.blue.rgb
local FLIPPED_COLOR = CONFIG.palette.fuchsia.rgb

-- State, rebuilt from the pins' memos (see registerPin):
--   masters[pinGuid] = { id = linkId, board = boardGuid }
--   slaves[pinGuid]  = { master_id = linkId, master = master pin GUID or nil,
--                        board = boardGuid, color = PIN_COLORS name,
--                        gm_only = true when only Black sees its shadows }
--   hidden[boardGuid] = true when that board's pins are hidden (the only part
--                       kept in SAVED_DATA.BOARD_MIRROR)
local state = nil
local master_by_id = {}

-- Runtime only:
--   ghosts[tokenGuid][slavePinGuid] = { obj = Object|nil, name = string, color = hex string,
--                                       highlight = player color it is highlighted in,
--                                       size = token scale x board ratio it was sized for }
--   timers[tokenGuid] = Wait id of the follow loop
--   rest_offset[tokenGuid] = how far the token last rested above its master board
--   last_seen[guid] = what a token or board looked like when last synced
--   ghost_hidden[ghostGuid] = the player colors a shadow is invisible to
local ghosts = {}
local timers = {}
local rest_offset = {}
local last_seen = {}
local ghost_hidden = {}
local board_menus = {}
local echoing = false
local stashed = {}

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------

local function isPin(obj)
    return obj.hasTag(OBJECT_TAGS.board_mirror_master) or obj.hasTag(OBJECT_TAGS.board_mirror_slave)
end

local function isGhost(obj)
    return obj.hasTag(OBJECT_TAGS.board_mirror_ghost)
end

local function isTracked(obj)
    return obj.hasTag(OBJECT_TAGS.movement_measurement) and not isGhost(obj)
end

-- Done moving: not held, not smooth-moving, and either resting or locked. A
-- locked object never reports resting, and the map bundler's positioner locks
-- every piece it puts back.
local function settled(obj)
    return obj.held_by_color == nil and not obj.isSmoothMoving() and (obj.resting or obj.getLock())
end

local function save()
    SAVED_DATA.BOARD_MIRROR = { hidden = state.hidden }
end

local function castDown(origin)
    local hits = Physics.cast({
        origin = origin,
        direction = { 0, -1, 0 },
        type = 1,
        max_distance = 200,
    }) or {}
    table.sort(hits, function(a, b) return a.distance < b.distance end)
    return hits
end

-- The board a pin sits on: the first locked object under it that is not a
-- pin, a ghost, a tracked token or the table itself.
local function boardUnderPin(pin)
    local tableObj = Tables.getTableObject()
    for _, hit in ipairs(castDown(pin.getPosition() + Vector(0, 0.5, 0))) do
        local o = hit.hit_object
        if o and o ~= pin and o ~= tableObj and not isPin(o) and not isGhost(o)
            and not isTracked(o) and o.getLock() then
            return o
        end
    end
    return nil
end

-- The closest master board under a token, and the point where the ray met it.
local function masterBoardUnder(token)
    local masters = {}
    for _, m in pairs(state.masters) do
        if m.board then masters[m.board] = true end
    end
    for _, hit in ipairs(castDown(token.getPosition() + Vector(0, 0.5, 0))) do
        local o = hit.hit_object
        if o and o ~= token and masters[o.getGUID()] then
            return o, hit.point
        end
    end
    return nil, nil
end

-- Where a ray straight down at (x, z) meets a given board.
local function surfaceOf(board, x, z)
    local b = board.getBounds()
    local top = b.center.y + b.size.y / 2 + 1
    for _, hit in ipairs(castDown(Vector(x, top, z))) do
        if hit.hit_object == board then
            return hit.point.y
        end
    end
    return nil
end

local function bottomOffset(obj)
    -- Distance from the object's pivot down to its lowest point.
    local b = obj.getBounds()
    return obj.getPosition().y - (b.center.y - b.size.y / 2)
end

local function disableColliders(obj)
    pcall(function()
        local function walk(go)
            for _, c in ipairs(go.getComponents() or {}) do
                if string.find(c.name, "Collider") then
                    pcall(function() c.set("enabled", false) end)
                end
            end
            for _, child in ipairs(go.getChildren() or {}) do
                walk(child)
            end
        end
        walk(obj)
    end)
end

-- Scales a color up until its strongest channel is full: same hue and
-- saturation, as bright as it goes. Black and near-black become light gray.
local function brighten(r, g, b)
    local top = math.max(r, g, b)
    if top < 0.05 then return Color(0.9, 0.9, 0.9) end
    return Color(r / top, g / top, b / top)
end

-- A flipped token's shadow is its color mixed halfway with pink, so it stands
-- out from the ones still face up.
local function tokenColor(token)
    local c = token.hasTag(OBJECT_TAGS.player) and PLAYER_COLOR or token.getColorTint()
    if token.is_face_down then
        return brighten(
            (c.r + FLIPPED_COLOR.r) / 2,
            (c.g + FLIPPED_COLOR.g) / 2,
            (c.b + FLIPPED_COLOR.b) / 2
        )
    end
    return brighten(c.r, c.g, c.b)
end

-- The player colors a token is invisible to. TTS's own list when this build
-- exposes it; otherwise the monster UI's is_visible(), the same source the
-- flying module uses: hidden means hidden from everyone but Black.
-- Whether this TTS build has getInvisibleTo(): tried once, then remembered,
-- since a failing pcall throws, and that is too costly to repeat every tick.
local has_get_invisible = nil

local function tokenHiddenFrom(token)
    if has_get_invisible ~= false then
        local ok, list = pcall(function() return token.getInvisibleTo() end)
        has_get_invisible = ok and type(list) == "table"
        if has_get_invisible then return list end
    end
    if token.getVar("is_visible") then
        local called, visible = pcall(function() return token.call("is_visible") end)
        if called and visible == false then return utils.hideFromPlayersArray() end
    end
    return {}
end

-- A shadow is hidden from whoever its token is hidden from, plus every player
-- but Black when its slave is GM only.
local function shadowHiddenFrom(token, link)
    local seen, list = {}, {}
    local function add(colors)
        for _, c in ipairs(colors) do
            if not seen[c] then
                seen[c] = true
                table.insert(list, c)
            end
        end
    end
    add(tokenHiddenFrom(token))
    if link and link.gm_only then add(utils.hideFromPlayersArray()) end
    table.sort(list)
    return list
end

local function tokenName(token)
    local name = token.getName()
    if name == nil or name == "" then return "" end
    return name
end

------------------------------------------------------------------------------
-- Ghosts
------------------------------------------------------------------------------

local function setLabel(ghost, name)
    ghost.clearButtons()
    if name == "" then return end
    local scale = ghost.getScale()
    local b = ghost.getBoundsNormalized()
    local top = (b.center.y - ghost.getPosition().y + b.size.y / 2) / scale.y
    ghost.createButton({
        click_function = "boardMirror_noop",
        function_owner = Global,
        label = name,
        position = { 0, top + LABEL_HEIGHT / scale.y, 0 },
        rotation = { 0, 180, 0 },
        scale = { 0.5 / scale.x, 1 / scale.y, 0.5 / scale.z },
        width = 0,
        height = 0,
        font_size = 300,
        font_color = { 1, 1, 1 },
    })
end

local function destroyGhost(tokenGuid, slaveGuid)
    local byToken = ghosts[tokenGuid]
    if not byToken or not byToken[slaveGuid] then return end
    local g = byToken[slaveGuid]
    byToken[slaveGuid] = nil
    if g.obj and not g.obj.isDestroyed() then
        ghost_hidden[g.obj.getGUID()] = nil
        g.obj.destruct()
    end
end

local function destroyGhostsOfToken(tokenGuid)
    if not ghosts[tokenGuid] then return end
    for slaveGuid in pairs(ghosts[tokenGuid]) do
        destroyGhost(tokenGuid, slaveGuid)
    end
    ghosts[tokenGuid] = nil
end

local function destroyGhostsOfSlave(slaveGuid)
    for tokenGuid in pairs(ghosts) do
        destroyGhost(tokenGuid, slaveGuid)
    end
end

local function scaleFactor(masterBoard, slaveBoard)
    return slaveBoard.getScale().x / masterBoard.getScale().x
end

-- Moves an existing ghost to mirror the token.
local function placeGhost(g, token, masterBoard, slaveBoard, link)
    local obj = g.obj
    if not obj or obj.isDestroyed() then return end

    local hidden = shadowHiddenFrom(token, link)
    local hiddenKey = table.concat(hidden, ",")
    if g.hidden ~= hiddenKey then
        g.hidden = hiddenKey
        obj.setInvisibleTo(hidden)
        ghost_hidden[obj.getGUID()] = hidden
    end

    local pos = token.getPosition()
    local world = slaveBoard.positionToWorld(masterBoard.positionToLocal(pos))
    local factor = scaleFactor(masterBoard, slaveBoard)
    local floor = surfaceOf(slaveBoard, world.x, world.z) or world.y
    local raise = (rest_offset[token.getGUID()] or 0) * factor
    world.y = floor + raise + g.bottom + 0.01

    local rot = token.getRotation()
    local yaw = rot.y - masterBoard.getRotation().y + slaveBoard.getRotation().y
    obj.setRotation(Vector(0, yaw, 0))
    obj.setPosition(world)

    -- Highlighted in the holder's color for as long as the token is carried.
    local holder = token.held_by_color
    if holder and g.highlight ~= holder then
        g.highlight = holder
        obj.highlightOn(Color.fromString(holder))
    elseif holder == nil and g.highlight then
        g.highlight = nil
        obj.highlightOff()
    end

    local color = tokenColor(token)
    if g.color ~= color:toHex() then
        g.color = color:toHex()
        obj.setColorTint(color)
    end

    local name = tokenName(token)
    if name ~= g.name then
        g.name = name
        setLabel(obj, name)
    end
end

local function spawnGhost(token, slaveGuid, masterBoard, slaveBoard)
    local tokenGuid = token.getGUID()
    local factor = scaleFactor(masterBoard, slaveBoard)
    local g = { obj = nil, name = nil, color = nil, bottom = 0, size = token.getScale().x * factor }
    ghosts[tokenGuid] = ghosts[tokenGuid] or {}
    ghosts[tokenGuid][slaveGuid] = g

    spawnObject({
        type = "Checker_white",
        position = slaveBoard.positionToWorld(masterBoard.positionToLocal(token.getPosition())),
        sound = false,
        callback_function = function(obj)
            -- The link, the token or this ghost entry may be gone by now.
            if ghosts[tokenGuid] == nil or ghosts[tokenGuid][slaveGuid] ~= g or token.isDestroyed() then
                obj.destruct()
                return
            end
            obj.addTag(OBJECT_TAGS.board_mirror_ghost)
            obj.setName(tokenName(token))
            obj.setLock(true)
            obj.interactable = false
            obj.use_gravity = false
            disableColliders(obj)
            -- Hidden until placeGhost() sets who may see it.
            obj.setInvisibleTo(utils.allPlayersArray())

            -- Size the disc to the token's footprint.
            local tb = token.getBoundsNormalized()
            local want = math.max(tb.size.x, tb.size.z) * factor
            local have = obj.getBoundsNormalized()
            if have.size.x > 0 then
                local s = want / have.size.x
                obj.setScale(Vector(s, SHADOW_THICKNESS / math.max(have.size.y, 0.001), s))
            end

            g.obj = obj
            g.bottom = bottomOffset(obj)
            BoardMirror.sync(token)
        end,
    })
end

-- Brings a token's ghosts up to date: creates the missing ones, moves them,
-- and removes the ones for boards it is no longer over.
function BoardMirror.sync(token)
    if state == nil or token == nil or token.isDestroyed() then return end
    local tokenGuid = token.getGUID()
    local masterBoard, hitPoint = masterBoardUnder(token)

    if masterBoard and hitPoint and settled(token) then
        local b = token.getBounds()
        rest_offset[tokenGuid] = math.max(0, (b.center.y - b.size.y / 2) - hitPoint.y)
    end

    local wanted = {}
    if masterBoard then
        local masterBoardGuid = masterBoard.getGUID()
        for slaveGuid, link in pairs(state.slaves) do
            local master = state.masters[link.master]
            if master and master.board == masterBoardGuid and link.board and link.board ~= masterBoardGuid then
                local slaveBoard = getObjectFromGUID(link.board)
                if slaveBoard then
                    wanted[slaveGuid] = true
                    local g = ghosts[tokenGuid] and ghosts[tokenGuid][slaveGuid]
                    -- A shadow's size is set when it spawns, from the token's
                    -- scale and the two boards' scale ratio: respawn it when
                    -- either changes, e.g. the map positioner growing boards
                    -- back from their bundled 0.25 one by one.
                    local size = token.getScale().x * scaleFactor(masterBoard, slaveBoard)
                    if g and math.abs(g.size - size) > 0.01 * size then
                        destroyGhost(tokenGuid, slaveGuid)
                        g = nil
                    end
                    if g == nil then
                        spawnGhost(token, slaveGuid, masterBoard, slaveBoard)
                    else
                        placeGhost(g, token, masterBoard, slaveBoard, link)
                    end
                end
            end
        end
    end

    if ghosts[tokenGuid] then
        for slaveGuid in pairs(ghosts[tokenGuid]) do
            if not wanted[slaveGuid] then destroyGhost(tokenGuid, slaveGuid) end
        end
    end
end

function BoardMirror.syncAll()
    for _, obj in ipairs(getObjectsWithTag(OBJECT_TAGS.movement_measurement)) do
        if not isGhost(obj) then BoardMirror.sync(obj) end
    end
end

local function stopFollowing(tokenGuid)
    if timers[tokenGuid] then
        Wait.stop(timers[tokenGuid])
        timers[tokenGuid] = nil
    end
end

-- What a token looks like, as far as its shadows care.
local function tokenSignature(token)
    local p, r = token.getPosition(), token.getRotation()
    return string.format("%.2f %.2f %.2f %.0f %.0f %.0f %.3f %s %s %s %s",
        p.x, p.y, p.z, r.x, r.y, r.z, token.getScale().x,
        token.getColorTint():toHex(), tostring(token.is_face_down), token.getName(),
        table.concat(tokenHiddenFrom(token), ","))
end

local function boardSignature(board)
    local p, r = board.getPosition(), board.getRotation()
    return string.format("%.2f %.2f %.2f %.0f %.0f %.0f %.3f",
        p.x, p.y, p.z, r.x, r.y, r.z, board.getScale().x)
end

-- Follows a token every TICK while it is held, falling or smooth-moving.
local function follow(token)
    local tokenGuid = token.getGUID()
    if timers[tokenGuid] then return end
    timers[tokenGuid] = Wait.time(function()
        if token.isDestroyed() then
            stopFollowing(tokenGuid)
            destroyGhostsOfToken(tokenGuid)
            return
        end
        BoardMirror.sync(token)
        if settled(token) then
            stopFollowing(tokenGuid)
            last_seen[tokenGuid] = tokenSignature(token)
        end
    end, TICK, -1)
end

-- Defined with the pins, further down.
local addPinMenu
local addBoardMenu

-- Once a second, catches what the pick-up/drop events miss: tokens moved,
-- spawned, renamed or retinted by scripts, boards that were moved, and shadows
-- brought back by undo. Only compares cheap signatures; tokens that changed are
-- handed to follow().
local function heartbeat()
    if state == nil or next(state.masters) == nil then return end

    -- A linked board that moved, rescaled, or just appeared (unbundled after
    -- its pins) resyncs every token.
    local boardMoved = false
    local boards = {}
    for _, entry in pairs(state.masters) do if entry.board then boards[entry.board] = true end end
    for _, entry in pairs(state.slaves) do if entry.board then boards[entry.board] = true end end
    for guid in pairs(boards) do
        local board = getObjectFromGUID(guid)
        if board then
            local sig = boardSignature(board)
            if last_seen[guid] ~= sig then
                if last_seen[guid] == nil then addBoardMenu(board) end
                boardMoved = true
                last_seen[guid] = sig
            end
        else
            last_seen[guid] = nil
        end
    end

    for _, token in ipairs(getObjectsWithTag(OBJECT_TAGS.movement_measurement)) do
        local guid = token.getGUID()
        if not isGhost(token) and timers[guid] == nil then
            local sig = tokenSignature(token)
            if boardMoved or last_seen[guid] ~= sig then
                last_seen[guid] = sig
                follow(token)
            end
        end
    end

    local known = {}
    for _, byToken in pairs(ghosts) do
        for _, g in pairs(byToken) do
            if g.obj and not g.obj.isDestroyed() then known[g.obj.getGUID()] = true end
        end
    end
    for _, obj in ipairs(getObjectsWithTag(OBJECT_TAGS.board_mirror_ghost)) do
        if not known[obj.getGUID()] then obj.destruct() end
    end
end

------------------------------------------------------------------------------
-- Pins and menus
------------------------------------------------------------------------------


-- A pin's link lives in its own memo, which TTS keeps through bags, bundles,
-- copy/paste and saves:
--   master: { mirror = "master", id = linkId, board = boardGuid }
--   slave:  { mirror = "slave", master = linkId, board = boardGuid,
--             color = PIN_COLORS name, gm_only = bool }
-- The board is saved too: board GUIDs survive bags and bundles, so a pin that
-- comes back relinks to its board at once, wherever it lands and whether or
-- not the board is back yet.
local function readMemo(pin)
    local memo = pin.memo
    if memo == nil or memo == "" then return nil end
    local ok, data = pcall(function() return JSON.decode(memo) end)
    if ok and type(data) == "table" and data.mirror then return data end
    return nil
end

local function writeMemo(pin, data)
    pin.memo = JSON.encode(data)
end

-- A link id starts with the GUID the master had when it got the id, which is
-- unique on the table at that moment; the random tail keeps two ids apart even
-- if that GUID is reused later in another save.
local function newLinkId(pin)
    local id
    repeat
        id = pin.getGUID() .. "-"
        for _ = 1, 4 do
            id = id .. string.char(math.random(97, 122))
        end
    until master_by_id[id] == nil
    return id
end

local function colorOfId(id)
    local hash = 0
    for i = 1, #id do
        hash = (hash * 31 + string.byte(id, i)) % 1000003
    end
    return PIN_COLORS[(hash % #PIN_COLORS) + 1].name
end

local function slavesOf(id)
    local list = {}
    for guid, link in pairs(state.slaves) do
        if link.master_id == id then table.insert(list, guid) end
    end
    table.sort(list)
    return list
end

-- The first color not taken by the master or by its other slaves.
local function freeSlaveColor(id, exceptGuid)
    local used = { [colorOfId(id)] = true }
    for guid, link in pairs(state.slaves) do
        if guid ~= exceptGuid and link.master_id == id and link.color then used[link.color] = true end
    end
    for _, c in ipairs(PIN_COLORS) do
        if not used[c.name] then return c.name end
    end
    return PIN_COLORS[1].name
end

local function saveSlaveMemo(guid)
    local link = state.slaves[guid]
    local pin = getObjectFromGUID(guid)
    if link and pin then
        writeMemo(pin, {
            mirror = "slave",
            master = link.master_id,
            board = link.board,
            color = link.color,
            gm_only = link.gm_only or nil,
        })
    end
end

local function saveMasterMemo(guid)
    local entry = state.masters[guid]
    local pin = getObjectFromGUID(guid)
    if entry and pin then
        writeMemo(pin, { mirror = "master", id = entry.id, board = entry.board })
    end
end

local function colored(key, text)
    return "[" .. string.sub(PIN_COLOR_BY_NAME[key].hex, 2) .. "]" .. text .. "[-]"
end

local function tintPin(pin, key)
    pin.setColorTint(Color.fromHex(PIN_COLOR_BY_NAME[key].hex))
end

-- Names and tints a master and all its slaves. Pin descriptions are left to
-- the map bundler, which keeps a piece's home transform there.
local function refreshLink(id)
    if id == nil then return end
    local own = colorOfId(id)
    local names = {}
    for _, guid in ipairs(slavesOf(id)) do
        local link = state.slaves[guid]
        table.insert(names, colored(link.color, link.color))
        local pin = getObjectFromGUID(guid)
        if pin then
            local suffix = link.gm_only and " - GM only" or ""
            pin.setName(colored(link.color, "Slave") .. " (" .. colored(own, own) .. ")" .. suffix)
            tintPin(pin, link.color)
        end
    end

    local master = master_by_id[id] and getObjectFromGUID(master_by_id[id])
    if master then
        master.setName(colored(own, "Master") .. " (" .. table.concat(names, ", ") .. ")")
        tintPin(master, own)
    end
end

-- Pins are only ever seen by Black; "hide pins" hides them from Black too.
local function applyHidden(pin, hidden)
    if hidden then
        pin.setLock(true)
        pin.interactable = false
        pin.setInvisibleTo(utils.allPlayersArray())
    else
        pin.interactable = true
        pin.setInvisibleTo(utils.hideFromPlayersArray())
    end
end

local function boardLabel(board)
    local name = board.getName()
    if name == nil or name == "" then return "board " .. board.getGUID() end
    return name
end

-- Works out which board a pin is on (a ray cast straight down), saves it on the
-- pin and returns whether it changed. Only needed when a pin is dropped by hand
-- or has no board saved yet. With a player color, tells that player when the
-- board changed, or that it found none.
local function placePin(pin, player_color)
    local guid = pin.getGUID()
    local entry = state.masters[guid] or state.slaves[guid]
    if not entry then return false end
    local board = boardUnderPin(pin)
    local before = entry.board
    entry.board = board and board.getGUID() or nil
    if player_color then
        local what = state.masters[guid] and "Master" or "Slave"
        if board == nil then
            utils.warning(what .. " pin is not on a board: drop it on a locked board to link it.", player_color)
        elseif entry.board ~= before then
            utils.success(what .. " pin linked to " .. boardLabel(board) .. ".", player_color)
        end
    end
    if board then
        addBoardMenu(board)
        if state.hidden[entry.board] then applyHidden(pin, true) end
    end
    if entry.board ~= before then
        if state.masters[guid] then saveMasterMemo(guid) else saveSlaveMemo(guid) end
    end
    return entry.board ~= before
end

-- Reads a pin's memo and (re)builds its entry. Safe to call again for a pin
-- that is already known. A master whose id is already used by another master
-- on the table (a copy, or the infinite bag's spare) gets a fresh id, so it
-- starts without slaves instead of sharing them.
local function registerPin(pin)
    local guid = pin.getGUID()
    -- Back on the table: whatever put it away is over. A stale mark would make
    -- a later delete look like it went into a bag (the infinite bag puts its
    -- spare in straight away, and it comes out with the same GUID).
    stashed[guid] = nil
    local memo = readMemo(pin) or {}

    -- Help text older versions wrote: the map bundler only records a piece's
    -- transform when its description is empty.
    if string.sub(pin.getDescription() or "", 1, 13) == "Board mirror " then
        pin.setDescription("")
    end

    if pin.hasTag(OBJECT_TAGS.board_mirror_master) then
        local id = memo.mirror == "master" and memo.id or nil
        local holder = id and master_by_id[id]
        if id == nil or (holder and holder ~= guid and getObjectFromGUID(holder)) then
            id = newLinkId(pin)
        end
        local board = memo.board or (state.masters[guid] and state.masters[guid].board)
        state.masters[guid] = { id = id, board = board }
        saveMasterMemo(guid)
        master_by_id[id] = guid
        for _, slaveGuid in ipairs(slavesOf(id)) do
            state.slaves[slaveGuid].master = guid
        end
        refreshLink(id)
    elseif pin.hasTag(OBJECT_TAGS.board_mirror_slave) then
        local id = memo.mirror == "slave" and memo.master or nil
        local board = memo.board or (state.slaves[guid] and state.slaves[guid].board)
        local link = {
            master_id = id,
            master = id and master_by_id[id],
            color = memo.color,
            gm_only = memo.gm_only or nil,
            board = board,
        }
        state.slaves[guid] = link
        if id then
            -- A pasted slave arrives with its original's color: give it its own.
            local taken = false
            for other, l in pairs(state.slaves) do
                if other ~= guid and l.master_id == id and l.color == link.color then taken = true end
            end
            if PIN_COLOR_BY_NAME[link.color or ""] == nil or taken then
                link.color = freeSlaveColor(id, guid)
            end
            saveSlaveMemo(guid)
            refreshLink(id)
        end
    else
        return
    end
    -- Invisibility is not saved with the object, so it is applied every time.
    local board = (state.masters[guid] or state.slaves[guid]).board
    applyHidden(pin, board ~= nil and state.hidden[board] == true)
    addPinMenu(pin)
end

-- A slave is a copy of its master without the script, so it cannot register
-- itself as a master too, and without the master's description, which may
-- hold the map bundler's record of where the master lives.
local function spawnSlave(masterPin)
    local entry = state.masters[masterPin.getGUID()]
    if not entry then return end
    local id = entry.id
    local data = masterPin.getData()
    data.GUID = nil
    data.LuaScript = ""
    data.LuaScriptState = ""
    data.XmlUI = ""
    data.Description = ""
    data.Memo = JSON.encode({ mirror = "slave", master = id, color = freeSlaveColor(id) })
    data.Tags = { OBJECT_TAGS.board_mirror_slave }
    data.Locked = false
    data.States = nil
    data.ChildObjects = nil
    spawnObjectData({
        data = data,
        position = masterPin.getPosition() + Vector(1.5, 1, 0),
        callback_function = function(pin) registerPin(pin) end,
    })
end

local function setGmOnly(slaveGuid, gm_only)
    local link = state.slaves[slaveGuid]
    if not link then return end
    link.gm_only = gm_only or nil
    saveSlaveMemo(slaveGuid)
    refreshLink(link.master_id)
    local pin = getObjectFromGUID(slaveGuid)
    if pin then addPinMenu(pin) end
    BoardMirror.syncAll()
end

-- Deliberately removing a slave: its pin goes too.
local function removeSlave(slaveGuid)
    local link = state.slaves[slaveGuid]
    if not link then return end
    state.slaves[slaveGuid] = nil
    destroyGhostsOfSlave(slaveGuid)
    local pin = getObjectFromGUID(slaveGuid)
    if pin then pin.destruct() end
    refreshLink(link.master_id)
end

-- "Mirror: initialize": sets up a master and every slave pin on the table whose
-- memo names it, finds the board under each, and resyncs the shadows.
local function initLink(masterPin, player_color)
    registerPin(masterPin)
    local guid = masterPin.getGUID()
    local entry = state.masters[guid]
    if not entry then return end
    placePin(masterPin)

    local count = 0
    for _, pin in ipairs(getObjectsWithTag(OBJECT_TAGS.board_mirror_slave)) do
        local memo = readMemo(pin)
        if memo and memo.master == entry.id then
            registerPin(pin)
            placePin(pin)
            count = count + 1
        end
    end
    refreshLink(entry.id)
    BoardMirror.syncAll()

    if player_color then
        local board = entry.board and getObjectFromGUID(entry.board)
        local where = board and boardLabel(board) or "no board"
        utils.success("Mirror initialized: master on " .. where .. ", " .. count .. " slave(s).", player_color)
    end
end

function BoardMirror.initialize(guid, player_color)
    if state == nil then return end
    local pin = getObjectFromGUID(guid)
    if pin then initLink(pin, player_color) end
end

addPinMenu = function(pin)
    pin.clearContextMenu()
    local guid = pin.getGUID()
    if state.masters[guid] then
        pin.addContextMenuItem("Mirror: initialize", function(player_color) initLink(pin, player_color) end)
        pin.addContextMenuItem("Spawn slave", function() spawnSlave(pin) end)
        pin.addContextMenuItem("Remove all slaves", function()
            local entry = state.masters[guid]
            if not entry then return end
            for _, slaveGuid in ipairs(slavesOf(entry.id)) do removeSlave(slaveGuid) end
        end)
    elseif state.slaves[guid] then
        if state.slaves[guid].gm_only then
            pin.addContextMenuItem("Shadows: show to all", function() setGmOnly(guid, false) end)
        else
            pin.addContextMenuItem("Shadows: GM only", function() setGmOnly(guid, true) end)
        end
        pin.addContextMenuItem("Unlink", function() removeSlave(guid) end)
    end
end

local function pinsOnBoard(boardGuid)
    local pins = {}
    for guid, m in pairs(state.masters) do
        if m.board == boardGuid then table.insert(pins, guid) end
    end
    for guid, s in pairs(state.slaves) do
        if s.board == boardGuid then table.insert(pins, guid) end
    end
    return pins
end

local function setBoardHidden(boardGuid, hidden)
    state.hidden[boardGuid] = hidden or nil
    for _, guid in ipairs(pinsOnBoard(boardGuid)) do
        local pin = getObjectFromGUID(guid)
        if pin then applyHidden(pin, hidden) end
    end
    save()
end

-- Global can add menu items to any object; the callbacks run here, so the
-- boards themselves never need a script. Script-added items do not survive a
-- reload, which is why init() adds them again.
addBoardMenu = function(board)
    local guid = board.getGUID()
    if board_menus[guid] then return end
    board_menus[guid] = true
    board.addContextMenuItem("Mirror: hide pins", function() setBoardHidden(guid, true) end)
    board.addContextMenuItem("Mirror: show pins", function() setBoardHidden(guid, false) end)
end

-- Brings in the links an older version kept in SAVED_DATA, by writing them
-- onto the pins' memos.
local function migrate(old)
    if type(old) ~= "table" or type(old.masters) ~= "table" then return end
    local ids = {}
    for guid in pairs(old.masters) do
        local pin = getObjectFromGUID(guid)
        if pin and readMemo(pin) == nil then
            ids[guid] = newLinkId(pin)
            writeMemo(pin, { mirror = "master", id = ids[guid] })
            master_by_id[ids[guid]] = guid
        end
    end
    for guid, link in pairs(old.slaves or {}) do
        local pin = getObjectFromGUID(guid)
        if pin and readMemo(pin) == nil and ids[link.master] then
            writeMemo(pin, {
                mirror = "slave",
                master = ids[link.master],
                color = type(link.color) == "string" and link.color or nil,
                gm_only = link.gm_only or nil,
            })
        end
    end
    master_by_id = {}
end

------------------------------------------------------------------------------
-- Entry points (wired to Global's events by attach())
------------------------------------------------------------------------------

function BoardMirror.init()
    print("[B9EA4F](Board mirror)[ffffff] Global v" .. BOARD_MIRROR_VERSION .. " loaded")
    local saved = SAVED_DATA.BOARD_MIRROR or {}
    state = { masters = {}, slaves = {}, hidden = saved.hidden or {} }
    migrate(saved)

    -- Ghosts are rebuilt rather than restored.
    for _, obj in ipairs(getObjectsWithTag(OBJECT_TAGS.board_mirror_ghost)) do
        obj.destruct()
    end

    -- Masters first, so slaves find them.
    for _, pin in ipairs(getObjectsWithTag(OBJECT_TAGS.board_mirror_master)) do registerPin(pin) end
    for _, pin in ipairs(getObjectsWithTag(OBJECT_TAGS.board_mirror_slave)) do registerPin(pin) end
    -- Pins from older versions have no board saved yet.
    for guid, entry in pairs(state.masters) do
        if entry.board == nil then placePin(getObjectFromGUID(guid)) end
    end
    for guid, entry in pairs(state.slaves) do
        if entry.board == nil then placePin(getObjectFromGUID(guid)) end
    end
    save()

    -- Let the deleted ghosts finish going before spawning new ones.
    Wait.frames(BoardMirror.syncAll, 2)

    if BoardMirror.heartbeat_id == nil then
        BoardMirror.heartbeat_id = Wait.time(heartbeat, HEARTBEAT, -1)
    end
end

function BoardMirror.onPickUp(obj)
    if state == nil then return end
    if isTracked(obj) then follow(obj) end
end

function BoardMirror.onDrop(obj, player_color)
    if state == nil then return end
    if isTracked(obj) then
        follow(obj)
    elseif isPin(obj) then
        -- (Re)register it from its memo and find the board it landed on.
        Wait.condition(function()
            if obj.isDestroyed() then return end
            registerPin(obj)
            placePin(obj, player_color)
            BoardMirror.syncAll()
        end, function() return obj.isDestroyed() or settled(obj) end, 5)
    end
end

------------------------------------------------------------------------------
-- Pings
------------------------------------------------------------------------------

-- Whether a ping landed on an object: within its footprint across, and no
-- further than a little above its top or below its bottom. A shadow has no
-- collider, so a ping on it lands on the board right under it.
local function pingHits(position, obj)
    if obj == nil or obj.isDestroyed() then return false end
    local b = obj.getBounds()
    local dx, dz = position.x - b.center.x, position.z - b.center.z
    local radius = math.max(b.size.x, b.size.z) / 2
    local half = b.size.y / 2 + 0.5
    return dx * dx + dz * dz <= radius * radius and math.abs(position.y - b.center.y) <= half
end

-- Our own pings may come back through onPlayerPing; ignore them for a moment.
-- Pings are not echoed onto anything the pinging player cannot see.
local function hiddenFromPlayer(obj, player_color)
    local list = ghost_hidden[obj.getGUID()]
    if list == nil and isTracked(obj) then list = tokenHiddenFrom(obj) end
    for _, c in ipairs(list or {}) do
        if c == player_color then return true end
    end
    return false
end

local function echoPing(player_color, targets)
    echoing = true
    for _, obj in ipairs(targets) do
        if not hiddenFromPlayer(obj, player_color) then
            utils.pingObject(player_color, obj.getGUID())
        end
    end
    Wait.frames(function() echoing = false end, 10)
end

-- The pin a ping landed on, if any. Hidden pins do not count.
local function pingedPin(position, object)
    local function visible(guid)
        local entry = state.masters[guid] or state.slaves[guid]
        return entry and not (entry.board and state.hidden[entry.board])
    end
    if object and visible(object.getGUID()) then
        return object.getGUID()
    end
    for guid in pairs(state.masters) do
        if visible(guid) and pingHits(position, getObjectFromGUID(guid)) then return guid end
    end
    for guid in pairs(state.slaves) do
        if visible(guid) and pingHits(position, getObjectFromGUID(guid)) then return guid end
    end
    return nil
end

-- Lights up the board a pin is on, in that pin's color.
local function glowBoard(pinGuid)
    local master, slave = state.masters[pinGuid], state.slaves[pinGuid]
    local entry = master or slave
    if not entry or not entry.board then return end
    local board = getObjectFromGUID(entry.board)
    if not board then return end
    local key = master and colorOfId(master.id) or slave.color
    if PIN_COLOR_BY_NAME[key or ""] == nil then return end
    board.highlightOn(Color.fromHex(PIN_COLOR_BY_NAME[key].hex), BOARD_GLOW)
end

-- Pinging a shadow pings its token; pinging a token pings all its shadows.
-- Pinging a slave pin pings its master; pinging a master pings all its slaves.
function BoardMirror.onPing(player, position, object)
    if state == nil or echoing then return end
    position = Vector(position)

    -- Only Black sees pins, so only Black's pings can land on one. The other
    -- end(s) of the link get pinged, and every board involved glows in the
    -- color of the pin on it.
    local pinGuid = player.color == "Black" and pingedPin(position, object) or nil
    if pinGuid then
        local others = {}
        if state.slaves[pinGuid] then
            local master = state.slaves[pinGuid].master
            if master then table.insert(others, master) end
        else
            for guid, link in pairs(state.slaves) do
                if link.master == pinGuid then table.insert(others, guid) end
            end
        end

        local targets = {}
        for _, guid in ipairs(others) do
            local pin = getObjectFromGUID(guid)
            if pin then table.insert(targets, pin) end
        end
        if #targets > 0 then echoPing(player.color, targets) end

        glowBoard(pinGuid)
        for _, guid in ipairs(others) do glowBoard(guid) end
        return
    end

    for tokenGuid, byToken in pairs(ghosts) do
        for _, g in pairs(byToken) do
            if pingHits(position, g.obj) then
                local token = getObjectFromGUID(tokenGuid)
                if token then echoPing(player.color, { token }) end
                return
            end
        end
    end

    local tokenGuid = nil
    if object and ghosts[object.getGUID()] then
        tokenGuid = object.getGUID()
    else
        for guid in pairs(ghosts) do
            if pingHits(position, getObjectFromGUID(guid)) then
                tokenGuid = guid
                break
            end
        end
    end
    if tokenGuid == nil then return end

    local targets = {}
    for _, g in pairs(ghosts[tokenGuid]) do
        if g.obj and not g.obj.isDestroyed() then table.insert(targets, g.obj) end
    end
    if #targets > 0 then echoPing(player.color, targets) end
end

-- The monster UI's visibility toggle, relayed by main.lua.
function BoardMirror.onVisibilityChanged(guid)
    if state == nil then return end
    local token = getObjectFromGUID(guid)
    if token and isTracked(token) then BoardMirror.sync(token) end
end

-- Pins going into a bag or bundle: remembered so onDestroy knows they were
-- put away, not deleted.
function BoardMirror.onEnterContainer(obj)
    if state ~= nil and isPin(obj) then stashed[obj.getGUID()] = true end
end

-- Flipping or spinning a token does not pick it up, so follow it from here.
function BoardMirror.onRotate(obj)
    if state == nil then return end
    if isTracked(obj) then follow(obj) end
end

function BoardMirror.onDestroy(obj)
    if state == nil or isGhost(obj) then return end
    -- Some objects have no GUID (TTS destroys them too when a table closes).
    local guid = obj.getGUID()
    if guid == nil then return end
    -- A pin leaving the table first drops out of the links. If it went into a
    -- bag or bundle, or is only reloading its script, that is all: its slaves
    -- keep their pins and link up again when it is initialized again. A master
    -- that was really deleted takes its slave pins with it; a deleted slave
    -- only removes itself.
    if state.masters[guid] then
        local id = state.masters[guid].id
        state.masters[guid] = nil
        if master_by_id[id] == guid then master_by_id[id] = nil end
        for _, slaveGuid in ipairs(slavesOf(id)) do
            state.slaves[slaveGuid].master = nil
            destroyGhostsOfSlave(slaveGuid)
        end
        -- Give onObjectEnterContainer, or the reloaded pin, time to show up.
        Wait.time(function()
            local wasStashed = stashed[guid]
            stashed[guid] = nil
            if wasStashed or getObjectFromGUID(guid) or master_by_id[id] then return end
            for _, slaveGuid in ipairs(slavesOf(id)) do
                local pin = getObjectFromGUID(slaveGuid)
                if pin then pin.destruct() end
            end
        end, 0.5)
    elseif state.slaves[guid] then
        local id = state.slaves[guid].master_id
        state.slaves[guid] = nil
        destroyGhostsOfSlave(guid)
        refreshLink(id)
    else
        stopFollowing(guid)
        destroyGhostsOfToken(guid)
        last_seen[guid] = nil
        rest_offset[guid] = nil
    end
end

------------------------------------------------------------------------------
-- Wiring
------------------------------------------------------------------------------

-- Hooks a Global function: runs whatever was already defined under that name,
-- then the handler. main.lua's own handlers keep working untouched.
local function hook(name, handler)
    local previous = _G[name]
    _G[name] = function(...)
        local result = nil
        if previous then result = previous(...) end
        handler(...)
        return result
    end
end

-- Called once from the bottom of main.lua, after its own handlers are defined.
function BoardMirror.attach()
    hook("onLoad", function()
        -- Same delay main.lua gives the table to finish loading.
        Wait.frames(BoardMirror.init, 35)
    end)
    hook("onObjectPickUp", function(player_color, obj) BoardMirror.onPickUp(obj) end)
    hook("onObjectDrop", function(player_color, obj) BoardMirror.onDrop(obj, player_color) end)
    hook("onObjectDestroy", function(obj) BoardMirror.onDestroy(obj) end)
    hook("onObjectEnterContainer", function(container, obj) BoardMirror.onEnterContainer(obj) end)
    hook("onObjectRotate", function(obj) BoardMirror.onRotate(obj) end)
    hook("onPlayerPing", function(player, position, object) BoardMirror.onPing(player, position, object) end)

    -- Called by monster tokens through Global.call when their visibility changes.
    hook("updateFlyingVisibility", function(params)
        if params and params.guid then BoardMirror.onVisibilityChanged(params.guid) end
    end)

    -- Asked by mirror pins on load, to warn when Global and the pin differ.
    _G.boardMirror_version = function() return BOARD_MIRROR_VERSION end

    -- Called by a mirror pin's own "Mirror: initialize" (src/modules/mirror_pin.lua).
    hook("boardMirror_init", function(params)
        if params and params.guid then BoardMirror.initialize(params.guid, params.player_color) end
    end)
end

return BoardMirror

end)
__bundle_register("src.data.config", function(require, _LOADED, __bundle_register, __bundle_modules)

CONFIG = {
    color = {
        ally = "#66ba6b",
        neutral = "#d5d165",
        player = "#7e7dbb",
        enemy = "#BD5365",
        lair = "#D2D186",
        epic = "#B38CFF"
    },
    players = {
        "Zora",
        "Thommas",
        "Edwin",
        "Gilkan",
        "Marcus",
        "Kottur"
    },
    playersColors = {
        zora = "Red",
        thommas = "Teal",
        edwin = "Blue",
        gilkan = "Green",
        marcus = "White",
        kottur = "Purple"
    },
    colors = {
        "Green", 
        "Purple", 
        "Red", 
        "Blue", 
        "Yellow", 
        "Brown", 
        "White", 
        "Teal", 
        "Orange", 
        "Pink",
        "Black"
    },
    offsets = {
        nr = "-35 255",
        toggle = "0 255"
    },
    insetText = {
        nr = "-35 0",
        toggle = "0 0"
    },
    xt = 5,
    xc = 1,
    timeToken = {
        tToken = "2f363b",
        turnPos = {
            x = 101.87,
            y = 4.00,
            z = -33.55
        },
        turnOffset = 0.77,
        rToken = "0e4e22",
        roundPos = {
            x = 101.65,
            y = 4.00,
            z = -28.57
        },
        roundOffset = 0.38
    },
    static = {
        "Lair",
        "Epic Die"
    },
    textColor = "#f0f0f0ff",
    palette = {
        navy = {
            hex = "#001f3f",
            rgb = { r = 0, g = 0.1216, b = 0.2471 }
        },
        blue = {
            hex = "#0074D9",
            rgb = { r = 0, g = 0.4549, b = 0.851 }
        },
        aqua = {
            hex = "#7FDBFF",
            rgb = { r = 0.498, g = 0.8588, b = 1.0 }
        },
        teal = {
            hex = "#39CCCC",
            rgb = { r = 0.2235, g = 0.8, b = 0.8 }
        },
        purple = {
            hex = "#B10DC9",
            rgb = { r = 0.6941, g = 0.051, b = 0.7882 }
        },
        fuchsia = {
            hex = "#F012BE",
            rgb = { r = 0.9412, g = 0.0706, b = 0.7451 }
        },
        maroon = {
            hex = "#85144b",
            rgb = { r = 0.5216, g = 0.0784, b = 0.2941 }
        },
        red = {
            hex = "#FF4136",
            rgb = { r = 1.0, g = 0.2549, b = 0.2118 }
        },
        orange = {
            hex = "#FF851B",
            rgb = { r = 1.0, g = 0.5216, b = 0.1059 }
        },
        yellow = {
            hex = "#FFDC00",
            rgb = { r = 1.0, g = 0.8627, b = 0 }
        },
        olive = {
            hex = "#3D9970",
            rgb = { r = 0.2392, g = 0.6, b = 0.4392 }
        },
        green = {
            hex = "#2ECC40",
            rgb = { r = 0.1804, g = 0.8, b = 0.251 }
        },
        lime = {
            hex = "#01FF70",
            rgb = { r = 0.0039, g = 1.0, b = 0.4392 }
        },
        black = {
            hex = "#111111",
            rgb = { r = 0.0667, g = 0.0667, b = 0.0667 }
        },
        gray = {
            hex = "#AAAAAA",
            rgb = { r = 0.6667, g = 0.6667, b = 0.6667 }
        },
        silver = {
            hex = "#DDDDDD",
            rgb = { r = 0.8667, g = 0.8667, b = 0.8667 }
        },
        white = {
            hex = "#FFFFFF",
            rgb = { r = 1.0, g = 1.0, b = 1.0 }
        }
    }
}

-- Board mirror version, shared by Global (src/core/board_mirror.lua) and the
-- mirror pin (src/modules/mirror_pin.lua) so a stale script on either side is
-- easy to spot. Bump it with every board mirror change.
BOARD_MIRROR_VERSION = 27

OBJECT_TAGS = {
    npc_commander = "npc_commander",
    clever_notecard = "clever_notecard",
    targeted_reticle = "targeted_reticle",
    json_note_container = "json_note_container",
    monster_token = "monster_token",
    boss_token = "boss_token",
    infinite_container = "infinite_container",
    movement_measurement = "movement_measurement",
    flying = "flying",
    player = "player_token",
    board_mirror_master = "board_mirror_master",
    board_mirror_slave = "board_mirror_slave",
    board_mirror_ghost = "board_mirror_ghost"
}

SAVED_DATA = {
    PLAYER = {
        ["Black"] = {
            autoSnap = false
        },
    }
}
end)
__bundle_register("src.core.utils", function(require, _LOADED, __bundle_register, __bundle_modules)

Utils = {}

require("src.data.config")


function _debug(msg, source)
    if not source then source = "DEBUG" end

    if #Utils.getSeatedPlayers() == 1 then
        print("[BBBBBB](" .. os.date("%H:%M:%S") .. ") [B9EA4F](" .. source .. ")[ffffff] " .. msg)
    end
end

-- Updates the save state of the object with the provided data table
function Utils.updateSave(self, data)
    local saved_data = JSON.encode(data)
    self.script_state = saved_data
end


function Utils.updateGlobalSave(data)
    for k, v in pairs(data) do
        print(k)
        print(v)
        if CONFIG.SAVED_DATA[k] then
            CONFIG.SAVED_DATA[k] = CONFIG.SAVED_DATA[k] .. ";" .. v
        else
            CONFIG.SAVED_DATA[k] = v
        end
    end
    log("Global save updated: " .. JSON.encode(CONFIG.SAVED_DATA))
end

-- Returns the color associated with a player name (case insensitive). Must be defined in CONFIG.playersColors
function Utils.getColorByPlayer(player)
    player = string.lower(player)
    for k, v in pairs(CONFIG.playersColors) do
        if k == player then
            return v
        end
    end
    return nil
end

-- Returns the player name associated with a color. Must be defined in CONFIG.playersColors
function Utils.getPlayerByColor(color)
    for k, v in pairs(CONFIG.playersColors) do
        if v == color then
            return k
        end
    end
    return nil
end

function Utils.hideFromPlayersArray()
    return {
        "White",
        "Brown",
        "Red",
        "Orange",
        "Yellow",
        "Green",
        "Teal",
        "Blue",
        "Purple",
        "Pink",
        "Grey"
    }
end

function Utils.allPlayersArray()
    return {
        "White",
        "Brown",
        "Red",
        "Orange",
        "Yellow",
        "Green",
        "Teal",
        "Blue",
        "Purple",
        "Pink",
        "Grey",
        "Black"
    }
end

function Utils.hideFromAllButPlayer(player)
    local allPlayersArray = Utils.allPlayersArray()
    for i = 1, #allPlayersArray do
        if allPlayersArray[i] == player then
            table.remove(allPlayersArray, i)
        end
    end
    return allPlayersArray
end

-- Pretty prints a table to the console for debugging purposes
function Utils.printTable(t)
    local printTable_cache = {}

    local function sub_printTable(t, indent)
        if (printTable_cache[tostring(t)]) then
            print(indent .. "*" .. tostring(t))
        else
            printTable_cache[tostring(t)] = true
            if (type(t) == "table") then
                for pos, val in pairs(t) do
                    if (type(val) == "table") then
                        print(indent .. "[" .. pos .. "] => " .. tostring(t) .. " {")
                        sub_printTable(val, indent .. string.rep(" ", string.len(pos) + 8))
                        print(indent .. string.rep(" ", string.len(pos) + 6) .. "}")
                    elseif (type(val) == "string") then
                        print(indent .. "[" .. pos .. '] => "' .. val .. '"')
                    else
                        print(indent .. "[" .. pos .. "] => " .. tostring(val))
                    end
                end
            else
                print(indent .. tostring(t))
            end
        end
    end

    if (type(t) == "table") then
        print(tostring(t) .. " {")
        sub_printTable(t, "  ")
        print("}")
    else
        sub_printTable(t, "  ")
    end
end

-- Prints an error message to either the Black player (if seated) or to all players
function Utils.error(msg, color_to_broadcast)
    if not color_to_broadcast then
        color_to_broadcast = Utils.getSeatedPlayers()[1]
    end
    Player[color_to_broadcast].broadcast("✘ "..msg, CONFIG.palette.red.rgb)
end

function Utils.success(msg, color_to_broadcast)
    if not color_to_broadcast then
        color_to_broadcast = Utils.getSeatedPlayers()[1]
    end
    Player[color_to_broadcast].broadcast("✔ "..msg, CONFIG.palette.green.rgb)
end

function Utils.warning(msg, color_to_broadcast)
    if not color_to_broadcast then
        color_to_broadcast = Utils.getSeatedPlayers()[1]
    end
    Player[color_to_broadcast].broadcast("" ..msg, CONFIG.palette.yellow.rgb)
end

function Utils.info(msg, color_to_broadcast)
    if not color_to_broadcast then
        color_to_broadcast = Utils.getSeatedPlayers()[1]
    end
    Player[color_to_broadcast].broadcast("🛈 " ..msg, CONFIG.palette.aqua.rgb)
end

function Utils.pingObject(player_color, object_guid)
    local obj = getObjectFromGUID(object_guid)
    if not obj or obj.isDestroyed() then
        return
    end

    local obj_pos = obj.getPosition()
    Player[player_color].pingTable(obj_pos)
    Utils.HighlightObject(obj, player_color,5)
end

function Utils.hasTagsFromList(obj, tagList)
    if not obj or obj.isDestroyed() then return false end
    local returner = false

    for _, tag in ipairs(tagList) do
        if obj.hasTag(tag) then
            returner = true
            break
        end
    end
    return returner
end

function Utils.findBlackName(name)
    if name == nil then return nil end

    -- Find text within parentheses
    local black_name = name:match("%((.-)%)")
    return black_name
end

-- Checks if a player color is currently seated at the table
function Utils.isColorSeated(color)
    return Player[color].seated
end

-- Converts a hex color string (e.g. "#RRGGBB" or "#RRGGBBAA") to a TTS color object
function Utils.hexToRgb(hex)
    hex = hex:gsub("#", "")
    if #hex < 8 then
        hex = hex .. "ff"
    end
    return color(
        tonumber("0x" .. hex:sub(1, 2), 16) / 255,
        tonumber("0x" .. hex:sub(3, 4), 16) / 255,
        tonumber("0x" .. hex:sub(5, 6), 16) / 255,
        tonumber("0x" .. hex:sub(7, 8), 16) / 255
    )
end

-- A safe way to check if a player is the host
function Utils.isHost(color)
    local player = getPlayerByColor(color)
    return player and player.host
end


-- Checks if an object with a given GUID still exists in the world
function objExists(guid)
    return getObjectFromGUID(guid) ~= nil
end

function Utils.UI_findElementById(uiTable, id)
    for i, element in ipairs(uiTable) do
        if element.attributes and element.attributes.id == id then
            return element
        end
        if element.children and #element.children > 0 then
            local found = Utils.UI_findElementById(element.children, id)
            if found then
                return found
            end
        end
    end
    return nil
end

-- Finds the first object with a specific tag
-- Returns nil if no object is found
function Utils.getObjectByTag(tag)
    local allObjects = getAllObjects()
    for _, obj in ipairs(allObjects) do
        if obj.hasTag(tag) then
            return obj
        end
    end
    return nil
end

function Utils.getIndexObjectWithinByTag(container, tag)
    local allObjects = container.getObjects()
    for index, obj in ipairs(allObjects) do
        if Utils.searchInArray(obj.tags, tag) then
            return obj.index
        end
    end
    return nil
end

function Utils.searchInArray(array, needle)
    for i = 1, #array do
        if array[i] == needle then
            return i
        end
    end
    return nil
end

-- Finds ALL objects with a specific tag
function Utils.getObjectsByTag(tag)
    local foundObjects = {}
    local allObjects = getAllObjects()
    for _, obj in ipairs(allObjects) do
        if obj.hasTag(tag) then
            table.insert(foundObjects, obj)
        end
    end
    return foundObjects
end

-- Safely retrieves and decodes a JSON string from an object's GM notes/memo
function Utils.getData(object)
    local dataString = object.getGMNotes()
    if dataString and dataString ~= "" then
        local data = JSON.decode(dataString)
        return data
    end
    return {} -- Return an empty table on failure
end

-- Encodes a Lua table to JSON and saves it to an object's GM notes/memo
function Utils.setData(object, dataTable)
    local jsonString = JSON.encode(dataTable)
    object.setGMNotes(jsonString)
end

function Utils.roundVector(vector)
    log(vector)
    for _, v in pairs(vector) do
        vector[_] = math.floor(v)
        log(v, "v")
        log(vector[_], "_")
    end
    return vector
end

-- Encodes a Lua table to JSON to save it in the GM notes, appending it
function Utils.appendData(object, dataTable, dataSubKey)
    local data = Utils.getData(object)

    local target = nil
    if dataSubKey then
        if not data[dataSubKey] then
            data[dataSubKey] = {}
        end
        target = data[dataSubKey]
    else
        target = data
    end

    for k, v in pairs(dataTable) do
        target[k] = v
    end
    Utils.setData(object, data)
end

-- Load XML from self
function Utils.setXML(source_xml_obj, destination_obj)
    
    if not source_xml_obj then source_xml_obj = self end
    if not destination_obj then destination_obj = self end

    local script = source_xml_obj.getLuaScript()
    local xml = script:sub(script:find("StartXML")+8, script:find("StopXML")-1)
    xml = xml:gsub("&", "&amp;")
    destination_obj.UI.setXml(xml)
end

-- Load Lua script from self
function Utils.setLuaScript(source_lua_obj, destination_obj)
    
    if not source_lua_obj then source_lua_obj = self end
    if not destination_obj then destination_obj = self end

    local script = source_lua_obj.getLuaScript()
    local lua = script:sub(script:find("StartLua")+8, script:find("StopLua")-1)
    destination_obj.setLuaScript(lua)
end

function Utils.HighlightObject(obj, color, duration)
    if not obj or obj.isDestroyed() then return end
    if not color then color = {1,1,0} end
    if not duration then duration = 1 end

    obj.highlightOn(color, duration)
end

-- String split
function Utils.split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

function Utils.capitalize(s)
    local result = s:gsub("(%a)(%w*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)
    return result
end

-- Get Seated Players
function Utils.getSeatedPlayers()
    local seated = {}
    for _, color in pairs(CONFIG.colors) do
        if Player[color].seated then
            table.insert(seated, color)
        end
    end
    return seated
end

function Utils.getOnlineCode(link, callback)
    if not Utils.validDomain(link) then
        Utils.error("Invalid domain for link: "..link, "Black")
        callback(nil)
        return
    end
    
    -- Ensure it's a raw link
    if not link:find("https://pastebin.com/raw/") then
        local rawPattern = "^.+/raw/.+$"
        if not link:find(rawPattern) then
            local pageNamePattern = "^.+/(.+)$"
            local _, _, pageName = link:find(pageNamePattern)
            link = "https://pastebin.com/raw/" .. pageName
        end
    end
    
    WebRequest.get(
        link,
        function(request)
            if request.is_error then
                Utils.error(request.error, player_clicker_color, "Black")
                callback(nil)
            else
                local script = request.text
                if script == '{"message":"Document not found."}' then
                    Utils.error("Code not found at the provided link.", "Black")
                    callback(nil)
                else
                    Utils.success("Code successfully retrieved from online source.", "Black")
                    callback(script)
                end
            end
        end
    )
end

function Utils.validDomain(link)
    local domains = { "https://pastebin.com/raw/", "https://pastebin.com/" }


    for i = 1, #domains do
        if link:find(domains[i], 1, true) then
            return true
        end
    end

    return false
end

-- Take something from a bag and use it
function Utils.useFromBag(bag, obj_function, bag_callback_function, object_tag, spawn_table_name, random_offset)
    local targeted_spawn = require("src.modules.target_reticle_context_menu")

    if not bag then return end

    if bag.type == "Infinite" or bag.hasTag(OBJECT_TAGS.infinite_container) then
        local position = Vector(targeted_spawn.getSpawnData("pos", spawn_table_name))

        if random_offset then
            -- Check if we passed a specific Vector/Table (Calculated spacing)
            if type(random_offset) == "table" or type(random_offset) == "userdata" then
                -- Add our specific calculated offset to the target position
                position = position + Vector(random_offset)
            else
                -- Fallback to the old random logic if we just passed 'true'
                -- print(random_offset) -- Optional: comment out debug print
                local offset = math.random(-5, 5)
                position = position + Vector(offset, 0, offset)
            end
        end


        local rotation = Vector(targeted_spawn.getSpawnData("rot", spawn_table_name))
        local obj = bag.takeObject({
            position = position,
            rotation = rotation,
            index = object_tag and Utils.getIndexObjectWithinByTag(bag, object_tag) or nil,
            callback_function = obj_function
        })
        if obj_function then obj_function(obj) end -- this is more redundancy than anything else...
        if bag_callback_function then bag_callback_function() end

        return obj
    end

    return nil
end

function Utils.swapObjectInBagByTag(bag, tag_to_replace, new_object, callback_after_clone)
    local object_index = Utils.getIndexObjectWithinByTag(bag, tag_to_replace)
    if object_index then
        bag.removeTag(OBJECT_TAGS.infinite_container)
        local old = bag.takeObject({index = object_index})
        old.destroy()
        local clone = new_object.clone({
            position = bag.getPosition() + Vector(0,3,0),
            sound = false
        })
        if callback_after_clone then
            callback_after_clone(clone)
        end
        bag.putObject(clone)
        bag.addTag(OBJECT_TAGS.infinite_container)
    else
        return false
    end
end

function Utils.replaceObjectInBagByTag(bag, tag_to_replace, callback_after_taking)
    local object_index = Utils.getIndexObjectWithinByTag(bag, tag_to_replace)
    if object_index then
        bag.removeTag(OBJECT_TAGS.infinite_container)

        local obj = bag.takeObject({index = object_index})
        if callback_after_taking then
            callback_after_taking(obj)
        end

        Wait.frames(function()        
            bag.putObject(obj)
            bag.addTag(OBJECT_TAGS.infinite_container)
        end, 50)
        
    else
        return false
    end
end

return Utils
end)
__bundle_register("src.modules.target_reticle_context_menu", function(require, _LOADED, __bundle_register, __bundle_modules)
local utils = require("src.core.utils")

TargetedSpawn = {}

local markerURL = "https://steamusercontent-a.akamaihd.net/ugc/9635652932658209683/73A8026732547DFEC06D5B59074CF1B6FFE0454F/"
local PARAMS = {    
    customObjectParams = {
        image = markerURL,
        type = 2,
        thickness = 0.2,
        merge_distance = 5,
        stackable = false,
    }
}

TargetedSpawn.caller = self
TargetedSpawn.targetMarker = null;

function TargetedSpawn.create(contextText, varName, tagToPull)
    if not varName then varName = "spawnData" end

    -- TargetedSpawn.varName = varName
    TargetedSpawn.targetMarker = null
    TargetedSpawn.caller = self

    self.addTag(OBJECT_TAGS.targeted_reticle)

    if not contextText then contextText = "Spawning Reticle" end
    TargetedSpawn.caller.addContextMenuItem(contextText, function(player_color) contextMenuFunction(player_color, tagToPull, varName) end)
end

function TargetedSpawn.getSpawnData(t, spawn_table)
    local target = spawn_table and spawn_table or "spawnData"

    local spawnData = utils.getData(TargetedSpawn.caller)[target]

    if t == "pos" then
        if spawnData then
            return spawnData.position
        else
            return TargetedSpawn.caller.getBounds().center + Vector(0,3,0)
        end
    elseif t == "rot" then
        if spawnData then
            return spawnData.rotation
        else 
            return Vector(0,0,0)
        end
    end
end

function contextMenuFunction(player_color, tagToPull, varName)
    local targetMarker = TargetedSpawn.targetMarker
    local caller = TargetedSpawn.caller

    if (targetMarker ~= null) then
        destroyObject(targetMarker)
        utils.error("Cancelled", true)
        targetMarker = nil
        return
    end

    targetMarker = spawnObject({
        type = "Custom_Token",
        position = caller.getBounds().center + Vector(0,3,0),
        scale = Vector(0.4,0.4,0.4),
        callback_function = function(spawned) 
            spawned.setLock(true)
            Player[player_color].clearSelectedObjects()
        end
    })
    targetMarker.setName("▶ Place me where you want the object to land. Right click for me to save. Rotation and positions are saved")
    targetMarker.setCustomObject(PARAMS.customObjectParams)

    targetMarker.addContextMenuItem("Test" , function(player_color)
        local indexToPull = nil
        if tagToPull then
            indexToPull = utils.getIndexObjectWithinByTag(caller, tagToPull)
        end

        caller.takeObject({
            position = targetMarker.getBounds().center + Vector(0, 3, 0),
            rotation = targetMarker.getRotation(),
            index = indexToPull or nil
        })
        Player[player_color].clearSelectedObjects()
    end)

    targetMarker.addContextMenuItem("Save", function(player_color)
        local pos = targetMarker.getBounds().center + Vector(0, 3, 0)
        local rot = targetMarker.getRotation()
        utils.appendData(caller,
            {
                [varName] = {
                    position = utils.roundVector(pos),
                    rotation = utils.roundVector(rot)
                }
            }
        )
        destroyObject(targetMarker)
        utils.success("Spawn data saved in the GM Notes", player_color)
    end)
end

return TargetedSpawn
end)
__bundle_register("src.core.flying", function(require, _LOADED, __bundle_register, __bundle_modules)
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
end)
__bundle_register("src.core.movement_measurement", function(require, _LOADED, __bundle_register, __bundle_modules)
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
end)
__bundle_register("src.core.promise", function(require, _LOADED, __bundle_register, __bundle_modules)
Promise = {}

function Promise.WaitUntilResting(obj, callback_function)
    Wait.condition(
        callback_function or function() end,
        function() -- Condition function
            return obj.isDestroyed() or obj.resting
        end
    )
end

function Promise.WaitFrames(frames, callback_function)
    Wait.frames(
        callback_function or function() end,
        frames or 1
    )
end

function Promise.WaitTime(time, callback_function)
    Wait.time(
        callback_function or function() end,
        time or 1
    )
end

return Promise
end)
__bundle_register("src.core.updater", function(require, _LOADED, __bundle_register, __bundle_modules)
require("src.core.utils")

Updater = {}

local currentVersion = "2.0.0" -- This version is hardcoded in the script

function Updater.checkForUpdates()
    WebRequest.get(versionCheckURL, function(request)
        if request.is_done and request.is_success then
            local latestVersion = request.text
            -- Trim whitespace or other characters from the response
            latestVersion = latestVersion:match("^%s*(.-)%s*$")

            if latestVersion ~= currentVersion then
                -- UPDATE AVAILABLE! Broadcast an event with the data.
                -- Don't create UI here. Just announce the news.
                print("Update found: " .. latestVersion)
                Global.call("EventDispatcher.broadcast", {
                    eventName = "updateAvailable",
                    versionInfo = {
                        current = currentVersion,
                        latest = latestVersion
                    }
                })
            else
                -- System is up-to-date.
                print("System is up to date.")
                Global.call("EventDispatcher.broadcast", {eventName = "systemUpToDate"})
            end
        else
            -- FAILED TO CHECK! Broadcast a different event.
            Global.call("EventDispatcher.broadcast", {
                eventName = "updateCheckFailed",
                error = request.error
            })
        end
    end)
end

function Updater.getCurrentVersion()
    return currentVersion
end

return Updater
end)
__bundle_register("src.core.event_dispatcher", function(require, _LOADED, __bundle_register, __bundle_modules)
require("src.core.utils")

local EventDispatcher = {}
EventDispatcher.listeners = {}

-- Function to let other scripts subscribe to an event
function EventDispatcher.subscribe(eventName, listenerFunction)
    if EventDispatcher.listeners[eventName] == nil then
        EventDispatcher.listeners[eventName] = {} -- Create a new list for this event
    end
    table.insert(EventDispatcher.listeners[eventName], listenerFunction)
end

-- Function to broadcast an event to all subscribers
function EventDispatcher.broadcast(eventName, ...)
    if EventDispatcher.listeners[eventName] == nil then
        return -- No one is listening, do nothing
    end

    -- Call every function that subscribed to this event
    for _, listener in ipairs(EventDispatcher.listeners[eventName]) do
        listener(...) -- Pass along any arguments
    end
end

function EventDispatcher.list()
    log(EventDispatcher.listeners)
end

return EventDispatcher
end)
return __bundle_require("__root")