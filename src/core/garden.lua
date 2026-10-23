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
