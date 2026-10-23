--- Credits
-- Daggerheart [Unofficial]
-- Original Author: Marum
-- Workshop Link: https://steamcommunity.com/sharedfiles/filedetails/?id=3181973858

require("src.data.config")
require("src.data.asset_urls")

local utils = require("src.core.utils")
local promise = require("src.core.promise")
local event = require("src.core.events")

local state = nil
local ready = false
local lastAng = -1
local frame = 0
local IM_BOSS = false
local _visible = true

local _myPosition = nil

local data={
    name = "Monster",
    hp = 5,
    maxHp = 5,
    stress = 3,
    maxStress = 3,
    difficulty = 10,
    showing = true,
    height = -1
}

function onUpdate()
    if (ready) then
        frame = frame+1
        if (frame % 8 == 0 or self.isSmoothMoving()) then
            alignPivot()
        end
    end
end

function onPickUp(player_color)
    self.UI.hide("pivot")
end

function onDrop(player_color)
    lastAng = -1
    alignPivot()
    if (data.showing) then
        self.UI.show("pivot")
    end
    _myPosition = self.getPosition()
end

function updateSave()
    utils.updateSave(self, data)
end

function alignPivot()
    local p = Player["Black"]
    if (p) then
        local pRot = p.getPointerRotation()
        if (pRot ~=nil and (pRot ~=lastAng or self.isSmoothMoving())) then
            lastAng = pRot
            local rot = self.getRotation()
            local ang = Vector(-rot.x, -rot.z, rot.y-pRot+180)
            local scale = self.getScale()
            
            if( not data.height or data.height < 0 ) then
                if (self.hasTag(OBJECT_TAGS.monster_token)) then
                    data.height = 200
                else 
                    data.height = 250
                end
            end
    
            self.UI.setAttributes("scale", {
                scale=1/scale.x.." "..1/scale.z.." "..1/scale.y
            })
            self.UI.setAttributes("pivot", {
                rotation=ang.x.." "..ang.y.." "..ang.z
            })


            self.UI.setAttributes("height", {
                position="0 0 "..tostring(-data.height)
            })
        end
    end
end



function setName(name)
    data.name = name
    self.editInput({index = 0, value = name})
    updateSave()
end

function increaseHP()
    changeHP(1)
    callForAllSelected("changeHP", 1)
end

function decreaseHP()
    changeHP(-1)
    callForAllSelected("changeHP", -1)
end

function Injector_setMaxHP(amount)
    if (data.hp == data.maxHp) then
        data.hp = tonumber(amount)
    end
    data.maxHp = tonumber(amount)
    if (tonumber(data.hp) > tonumber(amount)) then
        data.hp = tonumber(amount)
    end
    changeHP(0)
    rebuildUI()
    updateSave()
end

function Injector_setMaxStress(amount)
    if (data.stress == data.maxStress) then
        data.stress = tonumber(amount)
    end
    data.maxStress = tonumber(amount)
    if (tonumber(data.stress) > tonumber(amount)) then
        data.stress = tonumber(amount)
    end
    changeStress(0)
    rebuildUI()
    updateSave()
end

function changeHP(amount)
    data.hp = tonumber(data.hp)+tonumber(amount)
    if (tonumber(data.hp) <= 0) then
        data.hp = 0
    end
    if (tonumber(data.hp) > tonumber(data.maxHp)) then data.hp = data.maxHp end
    refreshPips("hp", data.hp, data.maxHp)

    if (tonumber(data.hp) < tonumber(data.maxHp)/2) then
        toggleCondition("bloodied", "true")
    else
        toggleCondition("bloodied", "false")
    end

    event.broadcast(
        event.EVENT_NAMES.monster_hp_update, 
        {hp = data.hp, obj_guid = self.getGUID()}
    )

    updateSave()
end

function increaseStress()
    changeStress(1)
    callForAllSelected("changeStress", 1)
end

function decreaseStress()
    changeStress(-1)
    callForAllSelected("changeStress", -1)
end

function changeStress(amount)
    data.stress = data.stress+amount
    if (tonumber(data.stress) <= 0) then
        data.stress = 0
    end
    if (tonumber(data.stress) > tonumber(data.maxStress)) then data.stress = data.maxStress end

    if (tonumber(data.stress) < tonumber(data.maxStress)/2) then
        toggleCondition("stressed", "true")
    else
        toggleCondition("stressed", "false")
    end

    if (tonumber(data.stress) == 0) then
        toggleCondition("stressed", "false")
        toggleCondition("vulnerable", "true")
    end 

    refreshPips("stress", data.stress, data.maxStress)

    event.broadcast(
        event.EVENT_NAMES.monster_stress_update,
        {stress = data.stress, obj_guid = self.getGUID()}
    )

    updateSave()
end

function toggleUI(player_color)
    if (player_color ~= "Black") then
        utils.error("You must be GM to toggle the UI.", player_color)
        return
    end

    if (data.showing) then
        hideUI()
        callForAllSelected("hideUI")
    else
        showUI()
        callForAllSelected("showUI")
    end
end

function hideUI()
    data.showing = false
    self.UI.hide("pivot")
    updateSave()
end

function showUI()
    data.showing = true
    self.UI.show("pivot")
    updateSave()
end

function callForAllSelected(func, param)
    for k, v in pairs(Player["Black"].getSelectedObjects()) do
        if (hasScriptingTags(v) and v ~=self) then
            v.call(func, param)
        end
    end
end

function raiseUI(player_color)
    if (player_color ~= "Black") then
        utils.error("You must be GM to raise the UI.", player_color)
        return
    end

    lastAng = -1
    data.height = data.height + 25
    alignPivot()
    updateSave()
end

function lowerUI(player_color)
    if (player_color ~= "Black") then
        utils.error("You must be GM to lower the UI.", player_color)
        return
    end

    lastAng = -1
    data.height = data.height - 25
    alignPivot()
    updateSave()
end

function barString(full, empty, amount, max)
    return string.rep(full, amount)..string.rep(empty,math.max(0, max-amount))
end

function onload(saved_data)
    if (saved_data ~= "") then
        data = JSON.decode(saved_data)
    end

    local z_pos = 0.7

    local object_type = self.type
    if object_type == "Figurine" then
        self.setTags({OBJECT_TAGS.monster_token})
    else 
        self.setTags({OBJECT_TAGS.boss_token})
        IM_BOSS = true
        z_pos = 0.35
    end
    setupDMUI() 

    self.addTag(OBJECT_TAGS.movement_measurement)
    self.addTag(OBJECT_TAGS.flying)

    if (data.post_reload_action) then
        promise.WaitUntilResting(self, function()
            _debug("Post-reload action on final object: " .. self.getGUID(), "MONSTER_UI")
            self.setLock(false)
            data.post_reload_action = nil
            updateSave() 
        end)
    end

    self.createInput(
        {
            input_function = "name",
            function_owner = self,
            label = "Name",
            alignment = 3,
            position = {x = 0, y = 0.05, z = z_pos},
            rotation = {0, 0, 0},
            width = 2200,
            height = 475,
            font_size = 380,
            validation = 1,
            scale = {0.3, 0.3, 0.3},
            value = data.name
        }
    )

    Wait.time(function()
        lastAng = -1
        alignPivot()
        Global.call("initializeFlying", {guid = self.getGUID()})
    end, 0.75)
end

function _init(params)
    if not params or not params.data then
        utils.error("Error: _init called without complete params")
        return 
    end

    local json = params.data

    if json.image then
        self.setCustomObject(
            {
                image = params.image,
            }
        )
    end

    data.hp = json.hp
    data.maxHp = json.hp
    data.stress = json.stress
    data.maxStress = json.stress
    data.difficulty = json.difficulty
    data.name = json.name

    local black_name = find_black_name(json.name)
    if black_name then
        data.black_name = black_name
        data.name = name_without_black_name(json.name)
    else
        data.black_name = nil
    end

    data.image = json.image
    data.post_reload_action = true

    self.script_state = JSON.encode(data)
    self.setLock(true)
    self.reload()
end

function name()
    return data.name
end

function find_black_name(name)
    local black_name = name:match("%((.-)%)")
    return black_name
end

function name_without_black_name(name)
    local name_without_black = name:gsub("%b()", "")
    name_without_black = name_without_black:match("^%s*(.-)%s*$")
    return name_without_black
end

-- Icons8 glyphs (https://icons8.com), hosted on upload.zaes.dev; sources in assets/icons (see README).
local ICON_BASE = "https://upload.zaes.dev/i/tts-monster-icons-png/"

local function icon(name, state)
    return ICON_BASE .. "mon-" .. name .. "-" .. state .. ".png"
end

local function conditionIcon(name)
    return ICON_BASE .. "mon-" .. name .. ".png"
end

-- Layout in real units (the container is drawn at scale 1 so text and glyphs rasterize crisp). Compact: badge left, HP over stress right.
local PLATE_WIDTH, STEP_SIZE, STEP_GAP, ROW_GAP = 264, 32, 4, 4
local BADGE_SIZE, BADGE_GAP = 52, 6
local ROWS_WIDTH = PLATE_WIDTH - BADGE_SIZE - BADGE_GAP
local TRACK_WIDTH = ROWS_WIDTH - 2 * (STEP_SIZE + STEP_GAP)
local PIP_GAP, PIP_PAD, PIP_MAX_CELL = 2, 2, 28
-- Past SEGMENT_FROM pips the glyphs get too small to read, so the row switches to tall flat segments.
local SEGMENT_FROM, SEGMENT_HEIGHT = 9, 24
local SEGMENT_COLORS = {
    hp = {filled = "#F87171", empty = "#262833"},
    stress = {filled = "#FBBF24", empty = "#262833"},
}

local function isSegmented(amount)
    return (tonumber(amount) or 1) >= SEGMENT_FROM
end

-- Always one row at a fixed width: icon pips shrink up to SEGMENT_FROM, then tall segments take over.
local function pipLayout(amount)
    amount = math.max(1, tonumber(amount) or 1)
    local segmented = isSegmented(amount)
    local gap = segmented and 2 or PIP_GAP
    local width = math.floor((TRACK_WIDTH - 2 * PIP_PAD - gap * (amount - 1)) / amount * 10) / 10
    local cellW = segmented and width or math.min(PIP_MAX_CELL, width)
    local cellH = segmented and SEGMENT_HEIGHT or cellW
    return amount, cellW, cellH, gap, math.max(STEP_SIZE, cellH + 2 * PIP_PAD)
end

-- Every pip is a near-black silhouette of the glyph (fills hollow outlines, rims solid ones) under the icon.
local function pipsXml(kind, current, amount)
    local out = {}
    local segmented = isSegmented(amount)
    for i = 1, math.max(1, tonumber(amount) or 1) do
        local state = i <= (tonumber(current) or 0) and "filled" or "empty"
        if segmented then
            out[#out + 1] = '<Panel color="#05060A" padding="2"><Image id="' .. kind .. '_' .. i .. '" color="' .. SEGMENT_COLORS[kind][state] .. '" /></Panel>'
        else
            out[#out + 1] = '<Panel><Image image="' .. icon(kind, "filled") .. '" color="#05060A" preserveAspect="true" />'
                .. '<Panel padding="2"><Image id="' .. kind .. '_' .. i .. '" image="' .. icon(kind, state) .. '" preserveAspect="true" /></Panel></Panel>'
        end
    end
    return table.concat(out)
end

local function stepButton(id, handler, label)
    return '<Button id="' .. id .. '" onClick="' .. handler .. '" text="' .. label .. '" fontSize="22" fontStyle="Bold" padding="0 0 0 0"'
        .. ' preferredWidth="' .. STEP_SIZE .. '" preferredHeight="' .. STEP_SIZE .. '" minWidth="' .. STEP_SIZE .. '"'
        .. ' color="#2A2D3B" hoverColor="#3C4259" pressColor="#1B1D26" textColor="#F8FAFC" outline="#4B5066" outlineSize="2 2" />'
end

local function barRow(kind, current, amount, decId, decFn, incId, incFn)
    local columns, cellW, cellH, gap, height = pipLayout(amount)
    return '<HorizontalLayout preferredHeight="' .. height .. '" childForceExpandWidth="false" childForceExpandHeight="false" childAlignment="MiddleCenter" spacing="' .. STEP_GAP .. '">'
        .. stepButton(decId, decFn, "-")
        .. '<GridLayout id="small' .. kind .. '" cellSize="' .. cellW .. ' ' .. cellH .. '" spacing="' .. gap .. ' ' .. gap .. '"'
        .. ' constraint="FixedColumnCount" constraintCount="' .. columns .. '" childAlignment="MiddleCenter"'
        .. ' preferredWidth="' .. TRACK_WIDTH .. '" preferredHeight="' .. height .. '" minWidth="' .. TRACK_WIDTH .. '" padding="' .. PIP_PAD .. '">'
        .. pipsXml(kind, current, amount)
        .. '</GridLayout>'
        .. stepButton(incId, incFn, "+")
        .. '</HorizontalLayout>', height
end

-- Condition icons sit in a row on top of the plate; inactive ones collapse, the rest stay centered.
local CONDITION_SIZE, CONDITION_GAP = 44, 4
local CONDITION_ORDER = {"restrained", "vulnerable", "stressed", "bloodied", "hidden"}

local function conditionsRowXml(plateHeight)
    local out = {}
    for _, id in ipairs(CONDITION_ORDER) do
        local gmOnly = id == "hidden" and ' visibility="Black"' or ''
        out[#out + 1] = '<Panel id="' .. id .. '" active="false" preferredWidth="' .. CONDITION_SIZE .. '" preferredHeight="' .. CONDITION_SIZE .. '"' .. gmOnly .. '>'
            .. '<Image image="' .. conditionIcon(id) .. '" color="#05060A" preserveAspect="true" />'
            .. '<Panel padding="3"><Image image="' .. conditionIcon(id) .. '" preserveAspect="true" /></Panel></Panel>'
    end
    return '<HorizontalLayout id="conditions" width="' .. PLATE_WIDTH .. '" height="' .. CONDITION_SIZE .. '" offsetXY="0 ' .. (plateHeight + CONDITION_SIZE / 2 + 6)
        .. '" spacing="' .. CONDITION_GAP .. '" childForceExpandWidth="false" childForceExpandHeight="false" childAlignment="MiddleCenter">'
        .. table.concat(out) .. '</HorizontalLayout>'
end

local function mainXml()
        local hpRow, hpHeight = barRow("hp", data.hp, data.maxHp, "decHPSmall", "decreaseHP", "incHPSmall", "increaseHP")
    local stressRow, stressHeight = barRow("stress", data.stress, data.maxStress, "decStressSmall", "decreaseStress", "incStressSmall", "increaseStress")
    local rowsHeight = hpHeight + stressHeight + ROW_GAP
    local plateHeight = math.max(BADGE_SIZE, rowsHeight)

    return [[
        <Defaults>
            <Button visibility="Black"/>
            <InputField visibility="Black"/>
        </Defaults>
        <Panel id="scale">
            <Panel id="pivot" visibility="Black" active="]] .. tostring(data.showing) .. [[" offsetXY="0 0" scale="1 1 1" rotation="0 0 0">
                <Panel visibility="Black" id="height">
                    <Panel id="container" visibility="Black" offsetXY="0 0" scale="1 1 1" rotation="-45 0 0">
                        <HorizontalLayout id="plate" width="]] .. PLATE_WIDTH .. [[" height="]] .. plateHeight .. [[" offsetXY="0 ]] .. (plateHeight / 2) .. [[" spacing="]] .. BADGE_GAP .. [[" childForceExpandWidth="false" childForceExpandHeight="false" childAlignment="MiddleCenter">
                            <Panel preferredWidth="]] .. BADGE_SIZE .. [[" preferredHeight="]] .. BADGE_SIZE .. [[">
                                <Image image="]] .. icon("armor", "filled") .. [[" color="#0A0B10" preserveAspect="true" />
                                <Image image="]] .. icon("armor", "empty") .. [[" preserveAspect="true" />
                                <Text id="smallDifficulty" color="#F8FAFC" fontSize="26" fontStyle="Bold" alignment="MiddleCenter" offsetXY="0 2">]] .. data.difficulty .. [[</Text>
                            </Panel>
                            <VerticalLayout preferredWidth="]] .. ROWS_WIDTH .. [[" preferredHeight="]] .. rowsHeight .. [[" spacing="]] .. ROW_GAP .. [[" childForceExpandHeight="false" childAlignment="MiddleCenter">
                                ]] .. hpRow .. stressRow .. [[
                            </VerticalLayout>
                        </HorizontalLayout>
                        ]] .. conditionsRowXml(plateHeight) .. [[
                    </Panel>
                </Panel>
            </Panel>
        </Panel>
    ]]
end

function refreshPips(kind, current, amount)
    local segmented = isSegmented(amount)
    for i = 1, tonumber(amount) or 0 do
        local state = i <= tonumber(current) and "filled" or "empty"
        if segmented then
            self.UI.setAttribute(kind .. "_" .. i, "color", SEGMENT_COLORS[kind][state])
        else
            self.UI.setAttribute(kind .. "_" .. i, "image", icon(kind, state))
        end
    end
end

-- Max HP / stress changed: the pip grid size changes, so the whole panel is rebuilt.
function rebuildUI()
    local active = {}
    for _, id in ipairs({"restrained", "vulnerable", "stressed", "bloodied", "hidden"}) do
        active[id] = self.UI.getAttribute(id, "active")
    end
    self.UI.setXml(mainXml() .. conditionsXml())
    Wait.frames(function()
        for id, value in pairs(active) do
            if value == "true" then toggleCondition(id, "true") end
        end
        lastAng = -1
        alignPivot()
    end, 10)
end


-- The GM-only black name, appended after the bars panel.
function conditionsXml()
    local xml = ""
    if data.black_name then
        local p = 35
        if IM_BOSS then
            p = 15
        end

        xml = xml .. [[
            <Text id="BlackName" scale="1 1 1" fontSize="34" visibility="Black" text="]]..data.black_name..[[" color="Black" position="0 ]].. p ..[[ -50" rotation="90 270 90" fontStyle="Bold" outline="White" outlineSize="1 -1" />
        ]]
    end

    return xml
end

function setupDMUI()
    self.addContextMenuItem("Toggle UI", toggleUI, true)
    self.addContextMenuItem("Raise UI", raiseUI, true)
    self.addContextMenuItem("Lower UI", lowerUI, true)
    self.addContextMenuItem("Set Name", function(player_color)
        if player_color ~= "Black" then
            utils.error("You must be GM to set names.", player_color)
        end
        Player["Black"].showInputDialog("Set Name", data.name,
            function (text, player_color)
                setName(text)
            end
        )
    end, false)
    self.addContextMenuItem("Toggle Condition", function(player_color)
        Player[player_color].showOptionsDialog("Select Condition", 
            {"Select Condition", "restrained", "vulnerable", "stressed", "bloodied", "hidden"},
            1,
            function (text, player_color)
                toggleCondition(text)
            end
        )
    end, false)

    self.addContextMenuItem("[cf00ff]Toggle visibility[-]", toggleVisibilityMenu, true)

    self.UI.setCustomAssets({{
        type=0,
        name="bars",
        url="https://steamusercontent-a.akamaihd.net/ugc/10744411922391955301/63FC0CC8C7BAAF5ED059C3170C5716F67152C8C6/"
    },
    {
        type=0,
        name="full",
        url="https://steamusercontent-a.akamaihd.net/ugc/17575880191213685112/86FE092CB588ED8B9241E28C5F7BC242347A397F/"
    },
    {
        type=0,
        name="cross",
        url="https://steamusercontent-a.akamaihd.net/ugc/2458480429345457547/13A122E49D432AC41893940503983AE71FA6B6DF/"
    }})
    Wait.time(function() 
        ready = true     
        
        local XMLString = mainXml()

        XMLString = XMLString .. conditionsXml()
        self.UI.setXml(XMLString)
        self.setName(data.name)
    end, 0.5)
    Wait.time(function()
        lastAng = -1
        alignPivot()
    end, 0.75)
end

function toggleCondition(conditionName, state)
    local conditionState = state
    if (conditionState == nil) then
        conditionState = self.UI.getAttribute(conditionName, "active") == "true" and "false" or "true"
    end

    self.UI.setAttribute(conditionName, "active", conditionState)
end

function setHiddenCondition()
    self.UI.setAttribute("hidden", "active", "true")

end

function clearHiddenCondition()
    self.UI.setAttribute("hidden", "active", "false")
end

function hasScriptingTags(obj)
    return utils.hasTagsFromList(obj, {OBJECT_TAGS.monster_token, OBJECT_TAGS.boss_token})
end

function toggleVisibilityMenu(player_color)
    if player_color ~= "Black" then
        return
    end

    -- Every selected monster takes the clicked one's new state, and each one
    -- applies it through its own script so its is_visible() stays truthful.
    local visible = not _visible

    local objs = Player["Black"].getSelectedObjects()
    local includesSelf = false
    for i = 1, #objs do
        if objs[i] == self then includesSelf = true end
    end
    if not includesSelf then
        table.insert(objs, self)
    end

    for i = 1, #objs do
        if hasScriptingTags(objs[i]) then
            objs[i].call("setVisible", {visible = visible})
        end
    end
end

function setVisible(params)
    _visible = params.visible

    local c = self.getColorTint()
    if not _visible then
        self.setInvisibleTo(utils.hideFromPlayersArray())
        self.setColorTint({r=c.r, g=c.g, b=c.b, a=0.3})
        setHiddenCondition()
    else
        self.setInvisibleTo({})
        self.setColorTint({r=c.r, g=c.g, b=c.b, a=1})
        clearHiddenCondition()
    end
    Global.call("updateFlyingVisibility", {guid = self.getGUID(), visible = _visible})
end

function is_visible()
    return _visible
end