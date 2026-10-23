--[[StartXML
<Defaults>
    <Text color="#F8FAFC" fontStyle="Bold" alignment="MiddleCenter" />
    <Button color="#1E293B" textColor="#F1F5F9" hoverColor="#334155" pressColor="#0F172A" fontStyle="Bold" outline="#334155" outlineSize="1 1" />
    <Panel color="Transparent" />
    <Text class="lbl" fontSize="11" alignment="MiddleLeft" preferredHeight="22" />
    <Text class="chip" fontSize="9" color="#8A8F9E" alignment="MiddleCenter" preferredHeight="14" />
    <Text class="count" fontSize="22" alignment="MiddleRight" preferredHeight="28" />
    <Button class="swiss-step" width="30" height="30" preferredWidth="30" preferredHeight="30" minWidth="30" fontSize="18" color="#2A2D3B" outline="#4B5066" outlineSize="1 1" hoverColor="#3C4259" pressColor="#0F172A" textColor="#F8FAFC" />
    <Button class="max" text="SET MAX" fontSize="9" preferredWidth="52" preferredHeight="20" minWidth="52" color="#1F2230" outline="#3B4054" outlineSize="1 1" hoverColor="#3C4259" textColor="#CBD5E1" />
    <GridLayout class="track" childAlignment="MiddleLeft" constraint="FixedRowCount" constraintCount="1" spacing="2 2" padding="3" preferredWidth="424" color="#060A12" outline="#1E293B" outlineSize="1 1" />
</Defaults>
<Panel position="0 330 -50" width="560" height="508" color="#0A0B10FA" outline="#3F4350" outlineSize="1 1" padding="16" rectAlignment="MiddleCenter" id="StatsPanel" active="true">
    <VerticalLayout spacing="8" childForceExpandHeight="false">

        <HorizontalLayout preferredHeight="14" childForceExpandWidth="false" spacing="10" childAlignment="MiddleLeft">
            <Text text="VITALS" fontSize="11" color="#C9B27C" alignment="MiddleLeft" preferredWidth="52" minWidth="52" />
            <VerticalLayout flexibleWidth="1" childForceExpandHeight="false" childAlignment="MiddleCenter"><Image color="#5A4F34" preferredHeight="1" /></VerticalLayout>
        </HorizontalLayout>

        <HorizontalLayout preferredHeight="88" spacing="8" childForceExpandWidth="false">
            <HorizontalLayout preferredWidth="132" minWidth="132" color="#15171F" outline="#2A2E3C" outlineSize="1 1" spacing="0" childForceExpandWidth="false">
                <Image color="#C9B27C" preferredWidth="4" minWidth="4" />
                <VerticalLayout flexibleWidth="1" padding="12 12 8 8" spacing="0" childForceExpandHeight="false">
                    <HorizontalLayout preferredHeight="22" childForceExpandWidth="false" childAlignment="MiddleLeft">
                        <Text text="EVASION" class="lbl" color="#C9B27C" flexibleWidth="1" />
                        <Button id="edit_evasion" text="EDIT" class="max" preferredWidth="36" minWidth="36" onClick="68a05c/UI_SetVariable(evasion)" />
                    </HorizontalLayout>
                    <Text id="evasion" text="14" color="#FFFFFF" fontSize="44" preferredHeight="50" onClick="68a05c/UI_SetVariable(evasion)" />
                </VerticalLayout>
            </HorizontalLayout>

            <HorizontalLayout preferredWidth="388" minWidth="388" color="#15171F" outline="#2A2E3C" outlineSize="1 1" spacing="0" childForceExpandWidth="false">
                <Image color="#8796F6" preferredWidth="4" minWidth="4" />
                <VerticalLayout flexibleWidth="1" padding="12 12 8 8" spacing="0" childForceExpandHeight="false">
                    <HorizontalLayout preferredHeight="22" childForceExpandWidth="false" childAlignment="MiddleLeft" spacing="8">
                        <Text text="ARMOR" class="lbl" color="#8796F6" preferredWidth="60" minWidth="60" />
                        <Button id="set_max_armor" class="max" onClick="68a05c/UI_SetVariable(max_armor)" />
                    </HorizontalLayout>
                    <HorizontalLayout preferredHeight="48" childForceExpandWidth="false" childAlignment="MiddleLeft" spacing="8">
                        <Button id="lose_armor" text="-" class="swiss-step" onClick="68a05c/UI_LoseVariable(armor)" />
                        <Text id="armor_display" text="5" color="#FFFFFF" fontSize="28" preferredWidth="44" minWidth="44" />
                        <Button id="gain_armor" text="+" class="swiss-step" onClick="68a05c/UI_GainVariable(armor)" />
                        <GridLayout id="armor_slots" cellSize="20 20" spacing="3 3" constraint="FixedColumnCount" constraintCount="9" childAlignment="MiddleLeft" preferredWidth="212" preferredHeight="46" minWidth="212" color="#0A1024" outline="#2D3A66" outlineSize="1 1" padding="3" />
                    </HorizontalLayout>
                </VerticalLayout>
            </HorizontalLayout>
        </HorizontalLayout>

        <HorizontalLayout preferredHeight="164" color="#15171F" outline="#2A2E3C" outlineSize="1 1" spacing="0" childForceExpandWidth="false">
            <Image color="#F87171" preferredWidth="4" minWidth="4" />
            <VerticalLayout flexibleWidth="1" padding="12 12 8 8" spacing="8" childForceExpandHeight="false">
                <HorizontalLayout preferredHeight="52" spacing="2">
                    <VerticalLayout color="#1B1D26" outline="#3B4054" outlineSize="1 1" spacing="0" childAlignment="MiddleCenter" childForceExpandHeight="false">
                        <Text text="MINOR  ·  1 HP" class="chip" />
                        <Text id="minor_damage_display" text="1 - 14" fontSize="24" color="#E2E8F0" preferredHeight="30" />
                    </VerticalLayout>
                    <VerticalLayout color="#1B1D26" outline="#6B5420" outlineSize="1 1" spacing="0" onClick="68a05c/UI_SetVariable(first_threshold)" childAlignment="MiddleCenter" childForceExpandHeight="false">
                        <Text text="MAJOR  ·  2 HP" class="chip" color="#FCD34D" />
                        <HorizontalLayout preferredHeight="30" childForceExpandWidth="false" childAlignment="MiddleCenter" spacing="4">
                            <Text text="≥" fontSize="14" color="#B45309" preferredWidth="14" />
                            <Text id="first_threshold" text="15" fontSize="24" color="#FDE68A" preferredWidth="40" onClick="68a05c/UI_SetVariable(first_threshold)" />
                        </HorizontalLayout>
                    </VerticalLayout>
                    <VerticalLayout color="#1B1D26" outline="#6B2A2A" outlineSize="1 1" spacing="0" onClick="68a05c/UI_SetVariable(second_threshold)" childAlignment="MiddleCenter" childForceExpandHeight="false">
                        <Text text="SEVERE  ·  3 HP" class="chip" color="#FCA5A5" />
                        <HorizontalLayout preferredHeight="30" childForceExpandWidth="false" childAlignment="MiddleCenter" spacing="4">
                            <Text text="≥" fontSize="14" color="#B91C1C" preferredWidth="14" />
                            <Text id="second_threshold" text="22" fontSize="24" color="#FECACA" preferredWidth="40" onClick="68a05c/UI_SetVariable(second_threshold)" />
                        </HorizontalLayout>
                    </VerticalLayout>
                </HorizontalLayout>
                <HorizontalLayout preferredHeight="36" childForceExpandWidth="false" childAlignment="MiddleLeft" spacing="8">
                    <Text text="HIT POINTS" class="lbl" color="#F87171" preferredWidth="96" minWidth="96" />
                    <Button id="set_max_hp" class="max" onClick="68a05c/UI_SetVariable(max_hp)" />
                    <Text text=" " flexibleWidth="1" preferredWidth="1" minWidth="1" />
                    <Text id="hp_count" text="0 / 0" class="count" preferredWidth="150" minWidth="150" fontSize="28" preferredHeight="34" />
                </HorizontalLayout>
                <HorizontalLayout preferredHeight="44" childForceExpandWidth="false" childAlignment="MiddleCenter" spacing="8">
                    <Button id="suffer_hp" text="-" class="swiss-step" onClick="68a05c/UI_LoseVariable(hp)" />
                    <GridLayout id="hp" class="track" color="#170C11" outline="#4A2230" cellSize="30 36" preferredHeight="44" />
                    <Button id="recover_hp" text="+" class="swiss-step" onClick="68a05c/UI_GainVariable(hp)" />
                </HorizontalLayout>
            </VerticalLayout>
        </HorizontalLayout>

        <HorizontalLayout preferredHeight="88" color="#15171F" outline="#2A2E3C" outlineSize="1 1" spacing="0" childForceExpandWidth="false">
            <Image color="#FBBF24" preferredWidth="4" minWidth="4" />
            <VerticalLayout flexibleWidth="1" padding="12 12 8 8" spacing="4" childForceExpandHeight="false">
                <HorizontalLayout preferredHeight="30" childForceExpandWidth="false" childAlignment="MiddleLeft" spacing="8">
                    <Text text="STRESS" class="lbl" color="#FBBF24" preferredWidth="96" minWidth="96" />
                    <Button id="set_max_stress" class="max" onClick="68a05c/UI_SetVariable(max_stress)" />
                    <Text text=" " flexibleWidth="1" preferredWidth="1" minWidth="1" />
                    <Text id="stress_count" text="0 / 0" class="count" preferredWidth="150" minWidth="150" />
                </HorizontalLayout>
                <HorizontalLayout preferredHeight="36" childForceExpandWidth="false" childAlignment="MiddleCenter" spacing="8">
                    <Button id="suffer_stress" text="-" class="swiss-step" onClick="68a05c/UI_LoseVariable(stress)" />
                    <GridLayout id="stress" class="track" color="#181209" outline="#4A3A14" cellSize="30 30" preferredHeight="36" />
                    <Button id="recover_stress" text="+" class="swiss-step" onClick="68a05c/UI_GainVariable(stress)" />
                </HorizontalLayout>
            </VerticalLayout>
        </HorizontalLayout>

        <HorizontalLayout preferredHeight="88" color="#15171F" outline="#2A2E3C" outlineSize="1 1" spacing="0" childForceExpandWidth="false">
            <Image color="#60A5FA" preferredWidth="4" minWidth="4" />
            <VerticalLayout flexibleWidth="1" padding="12 12 8 8" spacing="4" childForceExpandHeight="false">
                <HorizontalLayout preferredHeight="30" childForceExpandWidth="false" childAlignment="MiddleLeft" spacing="8">
                    <Text text="HOPE" class="lbl" color="#60A5FA" preferredWidth="96" minWidth="96" />
                    <Button id="set_max_hope" class="max" onClick="68a05c/UI_SetVariable(max_hope)" />
                    <Text text=" " flexibleWidth="1" preferredWidth="1" minWidth="1" />
                    <Text id="hope_count" text="0 / 0" class="count" preferredWidth="150" minWidth="150" />
                </HorizontalLayout>
                <HorizontalLayout preferredHeight="36" childForceExpandWidth="false" childAlignment="MiddleCenter" spacing="8">
                    <Button id="lose_hope" text="-" class="swiss-step" onClick="68a05c/UI_LoseVariable(hope)" />
                    <GridLayout id="hope" class="track" color="#09122A" outline="#1F3A6E" cellSize="30 30" preferredHeight="36" />
                    <Button id="gain_hope" text="+" class="swiss-step" onClick="68a05c/UI_GainVariable(hope)" />
                </HorizontalLayout>
            </VerticalLayout>
        </HorizontalLayout>

    </VerticalLayout>
</Panel>
StopXML--]]
require("src.data.config")

local utils = require("src.core.utils")
local promise = require("src.core.promise")

local ICON_BASE = "https://upload.zaes.dev/i/tts-player-icons/"
local function icons(name)
    return { filled = ICON_BASE .. name .. "-filled.png", empty = ICON_BASE .. name .. "-empty.png" }
end

local imageAssets = {
    armor = icons("armor"),
    hope = icons("sun"),
    hp = icons("hp"),
    stress = icons("stress")
}

local _defaults = {
    max_hope = 6,
    max_hp = 12,
    max_stress = 12,
    max_armor = 18,
    max_evasion = 25
}

-- Resource bars keep a fixed frame; the cells share it, so the bar never changes width.
local BAR_WIDTH, BAR_PADDING, BAR_SPACING, BAR_MAX_CELL = 424, 3, 2, 36
local BAR_CELL_HEIGHT = { hp = 36 }
local BAR_CELL_HEIGHT_DEFAULT = 30

local function fitBar(grid, amount)
    local cell = math.min(BAR_MAX_CELL, math.floor((BAR_WIDTH - 2 * BAR_PADDING - BAR_SPACING * (amount - 1)) / amount))
    grid.attributes.cellSize = cell .. " " .. (BAR_CELL_HEIGHT[grid.attributes.id] or BAR_CELL_HEIGHT_DEFAULT)
end

local function setCount(id, current, max)
    self.UI.setAttribute(id, "text", (current or 0) .. "<size=15><color=#94A3B8> / " .. (max or 0) .. "</color></size>")
end

local function refreshCounts()
    local d = utils.getData(self) or {}
    setCount("hp_count", d.hp or d.max_hp, d.max_hp)
    setCount("stress_count", d.stress or d.max_stress, d.max_stress)
    setCount("hope_count", d.hope, d.max_hope)
end

-- Every saved change (hp, stress, hope, maxes) refreshes the count labels.
local appendData = utils.appendData
utils.appendData = function(obj, values)
    appendData(obj, values)
    if obj == self then refreshCounts() end
end

local linked = nil
local showing_ui = false


-- Where the stats panel sits relative to the checker. "up" is the original spot; the others keep the same gap.
local PANEL_POSITIONS = {
    up = "0 330 -50",
    down = "0 -330 -50",
    left = "-356 0 -50",
    right = "356 0 -50"
}
local PANEL_DIRECTIONS = {"up", "down", "left", "right"}

local function applyPanelDirection(direction)
    self.UI.setAttribute("StatsPanel", "position", PANEL_POSITIONS[direction] or PANEL_POSITIONS.up)
end

local function buildPanelMenu()
    local current = (utils.getData(self) or {}).panel_direction or "up"
    self.clearContextMenu()
    for _, direction in ipairs(PANEL_DIRECTIONS) do
        local mark = direction == current and "● " or "○ "
        self.addContextMenuItem(mark .. "Panel grows " .. direction, function()
            utils.appendData(self, { panel_direction = direction })
            applyPanelDirection(direction)
            buildPanelMenu()
        end)
    end
end

function onLoad()
    utils.setXML(self, self)
    buildPanelMenu()

    Wait.frames(function()
        local guid = self.getGUID()

        -- Stats Panel
        self.UI.setAttribute("suffer_hp", "onClick", guid .. "/UI_LoseVariable(hp)")
        self.UI.setAttribute("recover_hp", "onClick", guid .. "/UI_GainVariable(hp)")
        self.UI.setAttribute("suffer_stress", "onClick", guid .. "/UI_LoseVariable(stress)")
        self.UI.setAttribute("recover_stress", "onClick", guid .. "/UI_GainVariable(stress)")

        self.UI.setAttribute("set_max_hp", "onClick", guid .. "/UI_SetVariable(max_hp)")
        self.UI.setAttribute("set_max_stress", "onClick", guid .. "/UI_SetVariable(max_stress)")
        self.UI.setAttribute("set_max_hope", "onClick", guid .. "/UI_SetVariable(max_hope)")
        self.UI.setAttribute("first_threshold", "onClick", guid .. "/UI_SetVariable(first_threshold)")
        self.UI.setAttribute("second_threshold", "onClick", guid .. "/UI_SetVariable(second_threshold)")
        self.UI.setAttribute("evasion", "onClick", guid .. "/UI_SetVariable(evasion)")

        self.UI.setAttribute("lose_hope", "onClick", guid .. "/UI_LoseVariable(hope)")
        self.UI.setAttribute("gain_hope", "onClick", guid .. "/UI_GainVariable(hope)")
        self.UI.setAttribute("lose_armor", "onClick", guid .. "/UI_LoseVariable(armor)")
        self.UI.setAttribute("gain_armor", "onClick", guid .. "/UI_GainVariable(armor)")

        self.UI.setAttribute("set_max_armor", "onClick", guid .. "/UI_SetVariable(max_armor)")

        -- self.UI.hide("main")
        -- self.UI.hide("ConditionMenu")
        -- self.UI.hide("ReminderMenu")

        applyPanelDirection((utils.getData(self) or {}).panel_direction)
        hidePanel("StatsPanel")

    end, 20)


    self.createButton(
        {
            click_function = "ClickLink",
            function_owner = self,
            label = "Link",
            position = {0, 0.4, 0},
            rotation = {180, 0, 180},
            scale = {0.5, 0.5, 0.5},
            width = 1800,
            height = 1200,
            font_size = 400,
            color = CONFIG.palette.green.rgb
        }
    )
end

function loadSavedData()
    local data = utils.getData(self)
    if not data then return end

    -- Re-render resource grids if max values exist
    if data.max_hp then
        Wait.frames(function() Injector_setMaxHP(data.max_hp, nil, data.hp or data.max_hp) end, 10)
    end
    if data.max_stress then
        Wait.frames(function() Injector_setMaxStress(data.max_stress, nil, data.stress or data.max_stress) end, 20)
    end
    if data.max_armor then
        Wait.frames(function() Injector_setMaxArmor(data.max_armor, nil, data.armor or data.max_armor) end, 30)
    end
    if data.max_hope then
        Wait.frames(function() Injector_setMaxHope(data.max_hope, nil, data.hope or 0) end, 40)
    else
        Wait.frames(function() setHope(data.hope or 0) end, 50)
    end

    -- Restore text displays
    Wait.frames(function() setThresholds(data.first_threshold or 0, data.second_threshold or 0) end, 60)
    Wait.frames(function() setEvasion(data.evasion or 0) end, 70)
    Wait.frames(function() setArmorDisplay(data.armor or data.max_armor or 0) end, 80)
    Wait.frames(refreshCounts, 90)
end

function ClickLink(_, player_color)
    local data = utils.getData(self)

    if data.token == nil then
        utils.error("Please drop your mini on me and click the button again.", player_color)
        return
    end

    if data.max_hp == nil or data.max_stress == nil then
        utils.warning("Please set Max HP and Max Stress then click the button again.", player_color)
    else
        InjectMini(data.token)
    end

    if showing_ui == false then
        showPanel("StatsPanel")
        loadSavedData()
        showing_ui = true
        utils.pingObject(player_color, data.token)
    end
end

function InjectMini(obj_guid)
    local script = [[
    local data = {
    hp = 5,
    maxHp = 5,
    stress = 3,
    maxStress = 3,
    ui_table = {}
}

local ICON_BASE = "__ICON_BASE__"
local function icons(name)
    return { filled = ICON_BASE .. name .. "-filled.png", empty = ICON_BASE .. name .. "-empty.png" }
end
local images = { hp = icons("hp"), stress = icons("stress"), armor = icons("armor") }


function set_data(params)
    if not params or not params.hp or not params.stress then
        print('invalid params')
        return 
    end


    self.setTags({"player_token", "movement_measurement", "flying"})
    data.hp = tonumber(params.hp)
    data.maxHp = tonumber(params.max_hp)
    data.stress = tonumber(params.stress)
    data.maxStress = tonumber(params.max_stress)
    data.armor = tonumber(params.armor)
    data.maxArmor = tonumber(params.max_armor)

    setupUI()
end

function setupUI()
    -- self.UI.setXmlTable({})

    local xmlTable = {
        {
            tag = "GridLayout",
            attributes = {
                scale = "1 1 1",
                childAlignment = "MiddleCenter",
                constraint = "FixedRowCount",
                constraintCount = "1",
                position = "0 0 -300",
                rotation = "270 0 0",
                id = "hp_container"
            },
            children = {}            
        },
        {
            tag = "GridLayout",
            attributes = {
                scale = "1 1 1",
                childAlignment = "MiddleCenter",
                constraint = "FixedRowCount",
                constraintCount = "1",
                position = "0 0 -270",
                rotation = "270 0 0",
                id = "stress_container"
            },
            children = {}
        },
        {
            tag = "GridLayout",
            attributes = {
                scale = "1 1 1",
                childAlignment = "MiddleCenter",
                width = "200",
                height = "100",
                cellSize = "30 30",
                position = "0 55 -5",
                rotation = "0 0 180",
                id = "armor_container"
            },
            children = {}
        }
    }

    xmlTable = setMaxHP(data.maxHp, data.hp, xmlTable)
    xmlTable = setMaxStress(data.maxStress, data.stress, xmlTable)
    xmlTable = setMaxArmor(data.maxArmor, data.armor, xmlTable)


    self.UI.setXmlTable(xmlTable)    
end

---Linearly interpolates a value from an input range to an output range.
---@param value number The current input value to convert.
---@param inputStart number The lower bound of the input range.
---@param inputEnd number The upper bound of the input range.
---@param outputStart number The corresponding lower bound of the output range.
---@param outputEnd number The corresponding upper bound of the output range.
---@return number The interpolated value in the output range.
function interpolate(value, inputStart, inputEnd, outputStart, outputEnd)
    -- Calculate how far the value is through the input range (as a percentage from 0.0 to 1.0)
    local t = (value - inputStart) / (inputEnd - inputStart)

    -- Clamp the percentage to be between 0 and 1, ensuring the output stays within the desired range
    t = math.max(0, math.min(1, t))

    -- Apply the clamped percentage to the output range to get the final value
    return outputStart + (outputEnd - outputStart) * t
end

local BAR_WIDTH, BAR_HEIGHT, BAR_GAP, BAR_MAX_CELL = 360, 30, 3, 26
local ARMOR_CELL, ARMOR_COLUMNS = 26, 9
local BAR_EDGE = { hp = "#6B3340", stress = "#6B5420", armor = "#3B4577" }

-- Bars are transparent; every pip carries its own dark tile so it reads against any table.
local function styleBar(attrs, width, height, cell, align)
    attrs.width = width
    attrs.height = height
    attrs.cellSize = cell .. " " .. cell
    attrs.spacing = BAR_GAP .. " " .. BAR_GAP
    attrs.childAlignment = align
end

-- The HP/stress bars are seen mirrored, so they build last-to-first: pip 1 ends up on the viewer's left. Armor is rotated 180° instead and keeps its natural order.
-- Each pip = near-black silhouette of the glyph (fills the hollow outline and rims the solid one) under the icon.
local function addPips(container, kind, amount, current, mirrored)
    container.children = {}
    local first, last, step = 1, amount, 1
    if mirrored then first, last, step = amount, 1, -1 end
    for i = first, last, step do
        table.insert(container.children, {
            tag = "Panel",
            attributes = {},
            children = {
                { tag = "Image", attributes = { image = images[kind].filled, color = "#05060A", preserveAspect = "true" } },
                {
                    tag = "Panel",
                    attributes = { padding = "2" },
                    children = {{
                        tag = "Image",
                        attributes = {
                            id = kind .. "_" .. i,
                            image = i > current and images[kind].empty or images[kind].filled,
                            color = "#ffffff",
                            preserveAspect = "true"
                        }
                    }}
                }
            }
        })
    end
end

local function rowCell(amount)
    return math.min(BAR_MAX_CELL, math.floor((BAR_WIDTH - BAR_GAP * (amount - 1)) / amount))
end

function setMaxHP(amount, current_amount, t)
    local cell = rowCell(amount)
    styleBar(t[1].attributes, BAR_WIDTH, BAR_HEIGHT, cell, "MiddleCenter")
    addPips(t[1], "hp", amount, current_amount, true)
    return t
end

function setMaxStress(amount, current_amount, t)
    local cell = rowCell(amount)
    styleBar(t[2].attributes, BAR_WIDTH, BAR_HEIGHT, cell, "MiddleCenter")
    addPips(t[2], "stress", amount, current_amount, true)
    return t
end

function setMaxArmor(amount, current_amount, t)
    -- balanced rows (12 -> 6 + 6, not 9 + 3) so the block stays visually centered
    local rows = math.ceil(amount / ARMOR_COLUMNS)
    local columns = math.ceil(amount / rows)
    local width = columns * ARMOR_CELL + (columns - 1) * BAR_GAP
    local height = rows * ARMOR_CELL + (rows - 1) * BAR_GAP
    styleBar(t[3].attributes, width, height, ARMOR_CELL, "MiddleCenter")
    t[3].attributes.constraint = "FixedColumnCount"
    t[3].attributes.constraintCount = tostring(columns)
    addPips(t[3], "armor", amount, current_amount)
    return t
end

local function isFilled(prefix, i, imgs)
    return self.UI.getAttribute(prefix .. i, "image") ~= imgs.empty
end

local function setPip(prefix, i, imgs, filled)
    self.UI.setAttribute(prefix .. i, "image", filled and imgs.filled or imgs.empty)
end

local function lastFilled(index, prefix, imgs)
    local children = self.UI.getXmlTable()[index].children
    for i = #children, 1, -1 do
        if isFilled(prefix, i, imgs) then return i end
    end
end

local function firstEmpty(index, prefix, imgs)
    local children = self.UI.getXmlTable()[index].children
    for i = 1, #children do
        if not isFilled(prefix, i, imgs) then return i end
    end
end

function sufferHP()
    local i = lastFilled(1, "hp_", images.hp)
    if i then setPip("hp_", i, images.hp, false) data.hp = data.hp - 1 end
end

function healHP()
    local i = firstEmpty(1, "hp_", images.hp)
    if i then setPip("hp_", i, images.hp, true) data.hp = data.hp + 1 end
end

function sufferStress()
    local i = lastFilled(2, "stress_", images.stress)
    if i then setPip("stress_", i, images.stress, false) data.stress = data.stress - 1 end
end

function healStress()
    local i = firstEmpty(2, "stress_", images.stress)
    if i then setPip("stress_", i, images.stress, true) data.stress = data.stress + 1 end
end

function loseArmor()
    local i = lastFilled(3, "armor_", images.armor)
    if i then setPip("armor_", i, images.armor, false) end
end

function gainArmor()
    local i = firstEmpty(3, "armor_", images.armor)
    if i then setPip("armor_", i, images.armor, true) end
end

function getHP()
    return data.hp
end

function getStress()
    return data.stress
end


]]

    local obj = getObjectFromGUID(obj_guid)
    
    if not obj then return end
    script = script:gsub("__ICON_BASE__", ICON_BASE)
    obj.setLuaScript(script)
    linked = obj.reload()

    -- linked = obj

    promise.WaitFrames(40, function()
        local data = utils.getData(self)

        local params = {
            max_hp = data.max_hp, 
            hp = data.hp or data.max_hp,
            stress = data.stress or data.max_stress,
            max_stress = data.max_stress,
            armor = data.armor or data.max_armor or 0,
            max_armor = data.max_armor or 0
        }


        linked.call("set_data", params)
        Global.call("initializeFlying", {guid = linked.getGUID()})

        -- Why am i doing it twice you ask
        -- Well, you see, funny and tts is so hilarious

        Injector_setMaxHP(data.max_hp, nil, data.hp)
        promise.WaitFrames(80,
            function()
                Injector_setMaxHP(data.max_hp, nil, data.hp)
            end
        )

        Injector_setMaxStress(data.max_stress, nil, data.stress)
        promise.WaitFrames(120,
            function()
                Injector_setMaxStress(data.max_stress, nil, data.stress)
            end
        )

        Injector_setMaxArmor(data.max_armor, nil, data.armor)
        promise.WaitFrames(150,
            function()
                Injector_setMaxArmor(data.max_armor, nil, data.armor)
            end
        )

        setHope(data.hope)
        promise.WaitFrames(150,
            function()
                setHope(data.hope)
            end
        )
    end)
end

local last_dropped = nil

function onCollisionEnter(collision_info)
    local drop = collision_info.collision_object
    -- Ignore collisions with surfaces or tiles
    if drop.type == "Surface" or drop.type == "Custom_Tyle" or not drop.interactable then
        return
    end

    local drop_player = drop.getVar("last_held_by")
    local data = utils.getData(self)

    -- CASE 1: No token is saved yet.
    -- We can save it directly without confirmation.
    if not data.token then
        utils.HighlightObject(drop, CONFIG.palette.green.rgb, 2)
        utils.appendData(self, {token = drop.guid})
        utils.success("Token with guid " .. drop.guid .. " has been saved.", drop_player)
        drop.setVar("owner", drop_player)
        _debug("Token with guid " .. drop.guid .. " has the owner set to " .. drop_player, "onCollissionEnter_player_injector")
        return -- Exit the function after saving
    end

    -- CASE 2: A token already exists.
    -- Now, we need to check for confirmation to overwrite it.

    -- If the same object is dropped again, it's a confirmation.
    if last_dropped == drop then
        utils.HighlightObject(drop, CONFIG.palette.green.rgb, 2)
        utils.appendData(self, {token = drop.guid})
        utils.success("Token with guid " .. drop.guid .. " has been overridden.", drop_player)
        drop.setVar("owner", drop_player)
        _debug("Token with guid " .. drop.guid .. " has the owner set to " .. drop_player, "onCollissionEnter_player_injector")
        
        last_dropped = nil -- Reset confirmation state after successful override
    else
        -- If a different object is dropped, ask for confirmation.
        if drop_player then
            utils.warning("We already have a token saved. If you want to override it, please drop the same object again on top of me.", drop_player)
        else
            print("We have a token saved. If you want to override it, please drop the same object again on top of me.")
        end
        -- Store the object that was just dropped, so we can check against it next time.
        last_dropped = drop
    end
end

function updateMini()
    if not linked then return end
    
    local data = utils.getData(self)

    local params = {
        max_hp = data.max_hp, 
        hp = data.hp or data.max_hp,
        stress = data.stress or data.max_stress,
        max_stress = data.max_stress,
        armor = data.armor or data.max_armor or 0,
        max_armor = data.max_armor or 0
    }

    linked.call("set_data", params)
end

function showPanel(panel)
    self.UI.show(panel)
end

function hidePanel(panel)
    self.UI.hide(panel)
end

function Injector_setMajorThreshold(amount, player_color)
    amount = tonumber(amount) or 0

    self.UI.setAttribute("first_threshold", "text", amount)
    self.UI.setAttribute("minor_damage_display", "text", (amount > 1 and "1 - " .. (amount - 1) or "0"))
    utils.appendData(self, { first_threshold = amount })
end

function Injector_setSevereThreshold(amount, player_color)
    amount = tonumber(amount) or 0

    self.UI.setAttribute("second_threshold", "text", amount)
    utils.appendData(self, { second_threshold = amount })
end

function Injector_setMaxHP(amount, player_color, current_amount)
    amount = tonumber(amount) or 1
    if amount < 1 then amount = 1 end
    if amount > _defaults.max_hp then
        utils.error("Max HP cannot exceed " .. _defaults.max_hp .. ".", player_color)
        return
    end

    current_amount = tonumber(current_amount) or amount

    local xml_table = self.UI.getXmlTable()
    local grid = utils.UI_findElementById(xml_table, "hp")  
    grid.children = {}
    fitBar(grid, amount)

    local asset = imageAssets.hp
    for i = 1, amount do
        local isFilled = (i <= current_amount)
        local attributes = { class = "hp", id = "hp_" .. i, preserveAspect = "true" }

        if asset and asset.useColor then
            attributes.color = isFilled and (asset.color and asset.color.filled or "#ffffff") or (asset.color and asset.color.empty or "#000000")
        elseif asset then
            attributes.image = isFilled and asset.filled or asset.empty
        else
            attributes.color = isFilled and "#ffffff" or "#000000"
        end

        table.insert(grid.children, { tag = "Image", attributes = attributes })
    end
    
    self.UI.setXmlTable(xml_table)
    utils.appendData(self, { max_hp = amount, hp = current_amount })
    updateMini()
end

function Injector_setMaxStress(amount, player_color, current_amount)
    amount = tonumber(amount) or 1
    if amount < 1 then amount = 1 end
    if amount > _defaults.max_stress then
        utils.error("Max Stress cannot exceed ".._defaults.max_stress..".", player_color)
        return
    end

    current_amount = tonumber(current_amount) or amount

    local xml_table = self.UI.getXmlTable()
    local grid = utils.UI_findElementById(xml_table, "stress")
    grid.children = {}
    fitBar(grid, amount)    

    local asset = imageAssets.stress
    for i = 1, amount do
        local isFilled = (i <= current_amount)
        local attributes = { class = "stress", id = "stress_" .. i, preserveAspect = "true" }

        if asset and asset.useColor then
            attributes.color = isFilled and (asset.color and asset.color.filled or "#ffffff") or (asset.color and asset.color.empty or "#000000")
        elseif asset then
            attributes.image = isFilled and asset.filled or asset.empty
        else
            attributes.color = isFilled and "#ffffff" or "#000000"
        end

        table.insert(grid.children, { tag = "Image", attributes = attributes })
    end

    self.UI.setXmlTable(xml_table)
    utils.appendData(self, { max_stress = amount, stress = current_amount })
    updateMini()
end


function Injector_setMaxArmor(amount, player_color, current_amount)
    amount = tonumber(amount) or 1
    if amount < 1 then amount = 1 end
    if amount > _defaults.max_armor then
        utils.error("Armor Slots cannot exceed ".._defaults.max_armor..".", player_color)
        return
    end

    current_amount = tonumber(current_amount) or amount

    local xml_table = self.UI.getXmlTable()
    local grid = utils.UI_findElementById(xml_table, "armor_slots")
    grid.children = {}

    local asset = imageAssets.armor
    for i = 1, amount do
        local isFilled = (i <= current_amount)
        local attributes = { class = "armor-filled", id = "armor_" .. i }

        if asset and asset.useColor then
            attributes.image = asset.filled
            attributes.color = isFilled and (asset.color and asset.color.filled or "#8796F6") or (asset.color and asset.color.empty or "#000000")
        elseif asset then
            attributes.image = isFilled and asset.filled or asset.empty
        end

        table.insert(grid.children, { tag = "Image", attributes = attributes })
    end

    self.UI.setXmlTable(xml_table)
    utils.appendData(self, { max_armor = amount, armor = current_amount })
    self.UI.setAttribute("armor_display", "text", current_amount)
    updateMini()
end

function Injector_setMaxHope(amount, player_color, current_amount)
    amount = tonumber(amount) or 1
    if amount < 1 then amount = 1 end
    if amount > _defaults.max_hope then
        utils.error("Max Hope cannot exceed ".._defaults.max_hope..".", player_color)
        return
    end

    local data = utils.getData(self)
    
    -- Preserve existing hope if current_amount was not explicitly provided
    current_amount = tonumber(current_amount) or data.hope or 0

    -- Clamp current hope if the new max is lower than current hope
    if current_amount > amount then
        current_amount = amount
    end

    local xml_table = self.UI.getXmlTable()
    local grid = utils.UI_findElementById(xml_table, "hope")
    if grid then
        grid.children = {}
    fitBar(grid, amount)

        local asset = imageAssets.hope
        for i = 1, amount do
            local isFilled = (i <= current_amount)
            local attributes = { class = "hope", id = "hope_" .. i, preserveAspect = "true" }

            if asset and asset.useColor then
                attributes.color = isFilled and (asset.color and asset.color.filled or "#ffffff") or (asset.color and asset.color.empty or "#000000")
            elseif asset then
                attributes.image = isFilled and asset.filled or asset.empty
            else
                attributes.color = isFilled and "#ffffff" or "#000000"
            end

            table.insert(grid.children, { tag = "Image", attributes = attributes })
        end

        self.UI.setXmlTable(xml_table)
    end

    utils.appendData(self, { max_hope = amount, hope = current_amount })
end

function setThresholds(first, second)
    self.UI.setAttribute("first_threshold", "text", first)
    self.UI.setAttribute("second_threshold", "text", second)
    
    local firstNum = tonumber(first) or 0
    if firstNum > 1 then
        self.UI.setAttribute("minor_damage_display", "text", "1 - " .. (firstNum - 1))
    else
        self.UI.setAttribute("minor_damage_display", "text", "0")
    end
end

function setEvasion(value)
    self.UI.setAttribute("evasion", "text", value)
    utils.appendData(self, { evasion = text })
end

function setArmorDisplay(value)
    self.UI.setAttribute("armor_display", "text", value)
end


function UI_SetVariable(player_color, variable)
    player_color.showInputDialog("Set " .. Utils.capitalize(variable:gsub("_", " ")),
        function (text, player_color)
            if text == "" or text == nil then 
                utils.error("Must input something", player_color.color)
                return 
            end

            local callback = {
                ["max_hp"] = function()
                    Injector_setMaxHP(text, player_color.color)
                end,
                ["max_stress"] = function()
                    Injector_setMaxStress(text, player_color.color)
                end,
                ["evasion"] = function()
                    setEvasion(text)
                end,
                ["max_armor"] = function()
                    Injector_setMaxArmor(text, player_color.color)
                end,
                ["max_hope"] = function()
                    Injector_setMaxHope(text, player_color.color)
                end, -- Comma fixed here
                ["first_threshold"] = function()
                    Injector_setMajorThreshold(text, player_color.color)
                end,
                ["second_threshold"] = function()
                    Injector_setSevereThreshold(text, player_color.color)
                end
            }
            
            if callback[variable] then
                callback[variable]()
            else
                self.UI.setAttribute(variable, "text", text)
                utils.appendData(self, {[variable] = text})
            end
        end
    )
end

function UI_GainVariable(player_color, variable)
    if (variable == "hp") then
        recoverHP()
    elseif (variable == "stress") then
        recoverStress()
    elseif (variable == "armor") then
        gainArmor()
    elseif (variable == "hope") then
        gainHope()
    else
        utils.error("Invalid variable", player_color.color)
    end
end

function UI_LoseVariable(player_color, variable)
    if (variable == "hp") then
        sufferHP()
    elseif (variable == "stress") then
        sufferStress()
    elseif (variable == "armor") then
        loseArmor()
    elseif (variable == "hope") then
        loseHope()
    else
        utils.error("Invalid variable", player_color.color)
    end
end

function sufferHP()
    local data = utils.getData(self)
    local maxHp = data.max_hp or 12
    local currentHp = data.hp or maxHp

    if currentHp > 0 then
        currentHp = currentHp - 1
        utils.appendData(self, { hp = currentHp })
        updateResourceDisplay("hp", currentHp, maxHp, "hp_")
        if linked then linked.call("sufferHP") end
    end
end

function recoverHP()
    local data = utils.getData(self)
    local maxHp = data.max_hp or 12
    local currentHp = data.hp or maxHp

    if currentHp < maxHp then
        currentHp = currentHp + 1
        utils.appendData(self, { hp = currentHp })
        updateResourceDisplay("hp", currentHp, maxHp, "hp_")
        if linked then linked.call("healHP") end
    end
end

function sufferStress()
    local data = utils.getData(self)
    local maxStress = data.max_stress or 12
    local currentStress = data.stress or maxStress

    if currentStress > 0 then
        currentStress = currentStress - 1
        utils.appendData(self, { stress = currentStress })
        updateResourceDisplay("stress", currentStress, maxStress, "stress_")
        if linked then linked.call("sufferStress") end
    end
end

function recoverStress()
    local data = utils.getData(self)
    local maxStress = data.max_stress or 12
    local currentStress = data.stress or maxStress

    if currentStress < maxStress then
        currentStress = currentStress + 1
        utils.appendData(self, { stress = currentStress })
        updateResourceDisplay("stress", currentStress, maxStress, "stress_")
        if linked then linked.call("healStress") end
    end
end

function loseArmor()
    local data = utils.getData(self)
    local maxArmor = data.max_armor or 18
    local currentArmor = data.armor or maxArmor

    if currentArmor > 0 then
        currentArmor = currentArmor - 1
        utils.appendData(self, { armor = currentArmor })
        self.UI.setAttribute("armor_display", "text", currentArmor)
        updateResourceDisplay("armor", currentArmor, maxArmor, "armor_")
        if linked then linked.call("loseArmor") end
    end
end

function gainArmor()
    local data = utils.getData(self)
    local maxArmor = data.max_armor or 18
    local currentArmor = data.armor or maxArmor

    if currentArmor < maxArmor then
        currentArmor = currentArmor + 1
        utils.appendData(self, { armor = currentArmor })
        self.UI.setAttribute("armor_display", "text", currentArmor)
        updateResourceDisplay("armor", currentArmor, maxArmor, "armor_")
        if linked then linked.call("gainArmor") end
    end
end

function loseHope()
    local data = utils.getData(self)
    local maxHope = data.max_hope or 6
    local currentHope = data.hope or 0

    if currentHope > 0 then
        currentHope = currentHope - 1
        utils.appendData(self, { hope = currentHope })
        updateResourceDisplay("hope", currentHope, maxHope, "hope_")
    end
end

function gainHope()
    local data = utils.getData(self)
    local maxHope = data.max_hope or 6
    local currentHope = data.hope or 0

    if currentHope < maxHope then
        currentHope = currentHope + 1
        utils.appendData(self, { hope = currentHope })
        updateResourceDisplay("hope", currentHope, maxHope, "hope_")
    end
end

function setHope(amount)
    amount = tonumber(amount) or 0
    local data = utils.getData(self)
    local maxHope = data.max_hope or 6
    utils.appendData(self, { hope = amount })
    updateResourceDisplay("hope", amount, maxHope, "hope_")
end

--- Updates all slot icons for a resource automatically based on its `useColor` setting.
--- @param resourceKey string Key in imageAssets (e.g. "armor", "hope", "hp", "stress")
--- @param currentValue number How many filled slots the player currently has
--- @param totalSlots number Total number of slots (max amount)
--- @param idPrefix string? Optional custom prefix for UI IDs (defaults to "resourceKey_")
function updateResourceDisplay(resourceKey, currentValue, totalSlots, idPrefix)
    local asset = imageAssets[resourceKey]
    if not asset then
        log("Error: Resource key '" .. tostring(resourceKey) .. "' not found in imageAssets.")
        return
    end

    local prefix = idPrefix or (resourceKey .. "_")

    for i = 1, totalSlots do
        local elementId = prefix .. i
        local isFilled = (i <= currentValue)

        if asset.useColor then
            local targetColor = isFilled and (asset.color and asset.color.filled or "#FFFFFF")
                                         or (asset.color and asset.color.empty or "#000000")
            self.UI.setAttribute(elementId, "color", targetColor)
        else
            local targetImage = isFilled and asset.filled or asset.empty
            self.UI.setAttribute(elementId, "image", targetImage)
        end
    end
end
