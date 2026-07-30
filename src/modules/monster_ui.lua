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

-- Fly up/down state (ported from legacy script)
local _flyOffset = 0
local _floating = false
local _myPosition = nil
local OFFSET_VALUE = Grid.sizeX

-- Range bands, in squares (1 square = 5ft), used to color/label the height button and shadow
-- Melee: 1 | Very Close: 3 | Close: 6 | Far: 12 | Very Far: 13+
local RANGE_COLORS = {
    melee     = {0, 0.4550, 0.8510, 1}, -- default blue
    veryClose = {0, 0.659, 0.976, 1},
    close     = {0.204, 0.91, 0, 1},
    far       = {0.918, 0.416, 0, 1},
    veryFar   = {0.91, 0.169, 0.169, 1} -- red-ish
}
local RANGE_LABELS = {
    melee     = "Melee",
    veryClose = "Very\nClose",
    close     = "Close",
    far       = "Far",
    veryFar   = "Very\nFar"
}

-- Ground shadow indicator state
local _groundIndicator = nil
local _lastIndicatorPos = nil

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

-- Helper to check if any given object is currently being held or selected by any player
function isObjectHeldOrSelected(obj)
    if not obj then return false end
    if obj.held_by_color ~= nil then
        return true
    end
    local players = Player.getPlayers()
    for _, p in ipairs(players) do
        local selected = p.getSelectedObjects()
        if selected then
            for _, sObj in ipairs(selected) do
                if sObj == obj then
                    return true
                end
            end
        end
    end
    return false
end

-- Toggles whether the shadow token can be clicked, dragged, and affected by gravity/snapping
function setShadowInteractable(state)
    if not _groundIndicator then
        return
    end
    _groundIndicator.setLock(not state)
    _groundIndicator.interactable = state
    _groundIndicator.use_gravity = state
    _groundIndicator.use_grid = false
    _groundIndicator.tooltip = state

    local col = _groundIndicator.getComponent("BoxCollider") or _groundIndicator.getComponent("MeshCollider") or _groundIndicator.getComponent("CapsuleCollider")
    if col then
        col.set("enabled", state)
    end
end

-- Performs a downward raycast to find the ground height below the token (used when grounded)
function getGroundHeight()
    local pos = self.getPosition()
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
        if hit ~= nil and hit.hit_object ~= nil and hit.hit_object ~= self and (not _groundIndicator or hit.hit_object ~= _groundIndicator) then
            return hit.point.y
        end
    end
    return 0
end

function onUpdate()
    if (ready) then
        frame = frame+1
        if (frame % 8 == 0 or self.isSmoothMoving()) then
            alignPivot()
        end
        if (frame % 4 == 0 or self.isSmoothMoving()) then
            maybeUpdateGroundIndicator()
        end
    end

    if _floating and _groundIndicator then
        local shadowPos = _groundIndicator.getPosition()
        local targetY = shadowPos.y + _flyOffset
        local selfPos = self.getPosition()

        -- If the shadow is actively being dragged, snap the mini instantly for zero lag
        if isObjectHeldOrSelected(_groundIndicator) then
            self.setPosition({shadowPos.x, targetY, shadowPos.z})
            self.setVelocity({0, 0, 0})
            self.setAngularVelocity({0, 0, 0})
        else
            -- Otherwise, smoothly align to the shadow
            if math.abs(selfPos.x - shadowPos.x) > 0.01 
                or math.abs(selfPos.z - shadowPos.z) > 0.01 
                or math.abs(selfPos.y - targetY) > 0.01 
            then
                self.setPositionSmooth({shadowPos.x, targetY, shadowPos.z}, false, false)
            end
        end
    end
end

function onPickUp(player_color)
    self.UI.hide("pivot")
    _floating = false
end

function onDrop(player_color)
    lastAng = -1
    alignPivot()
    if (data.showing) then
        self.UI.show("pivot")
    end
    _myPosition = self.getPosition()
    setFloat()
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

-- ===== Fly up/down (ported from legacy script) =====

function flyUp(player_color)
    if player_color ~= "Black" then
        return
    end
    _flyOffset = _flyOffset + OFFSET_VALUE
    setFloat()
end

function flyDown(player_color)
    if player_color ~= "Black" then
        return
    end
    if _floating then
        _flyOffset = _flyOffset - OFFSET_VALUE
    end
    setFloat()
end

function resetFlyButton(obj, color)
    if color == "Black" then
        _flyOffset = 0
        setFloat()
    end
end

function setFloat()
    if _flyOffset == 0 then
        _floating = false
        self.use_gravity = true
        hideHeightButton()
        setGroundIndicatorLabel("", nil)
        setShadowInteractable(false)
    else
        _floating = true
        self.use_gravity = false
        updateHeightButton()
        setShadowInteractable(true)
    end
    spawnGroundIndicator()
end

function hideHeightButton()
    self.editButton({index = 0, font_color = {1,1,1,0}})
    self.editButton({index = 0, color = {0,0.4550,0.8510,0}})
end

-- Picks a range band key based on how many squares up the token is flying
function getRangeBand(squares)
    if squares <= 1 then
        return "melee"
    elseif squares <= 3 then
        return "veryClose"
    elseif squares <= 6 then
        return "close"
    elseif squares <= 12 then
        return "far"
    else
        return "veryFar"
    end
end

function updateHeightButton()
    local squares = _flyOffset / OFFSET_VALUE
    local band = getRangeBand(squares)
    self.editButton({index = 0, font_color = {1,1,1,1}})
    self.editButton({index = 0, color = RANGE_COLORS[band]})
    self.editButton({index = 0, label = "+" .. squares * 5})
    setGroundIndicatorLabel(RANGE_LABELS[band], RANGE_COLORS[band])
end

-- ===== end fly up/down =====

-- ===== Ground shadow indicator =====

-- Converts a {r,g,b,a} (0-1 float) color table into a "#RRGGBBAA" hex string
function colorToHex(c)
    local function toHex(v)
        return string.format("%02X", math.floor((v or 1) * 255 + 0.5))
    end
    return "#" .. toHex(c[1]) .. toHex(c[2]) .. toHex(c[3]) .. toHex(c[4])
end

-- Updates the range-band text on the shadow indicator
function setGroundIndicatorLabel(text, color)
    if not _groundIndicator then
        return
    end
    _groundIndicator.UI.setAttribute("rangeLabel", "text", text or "")
    if color then
        _groundIndicator.UI.setAttribute("rangeLabel", "color", colorToHex(color))
    end
end

function spawnGroundIndicator()
    if _groundIndicator then
        if not _floating then
            destroyGroundIndicator()
        end
        return
    end

    local bounds = self.getBounds()
    local size = math.max(bounds.size.x, bounds.size.z) * 0.45
    local pos = self.getPosition()

    spawnObject({
        type = "reversi_chip",
        position = {pos.x, pos.y - 0.5, pos.z},
        rotation = {0, 0, 0},
        scale = {size, 0.02, size},
        sound = false,
        callback_function = function(obj)
            _groundIndicator = obj
            obj.setColorTint({0, 0, 0})
            obj.setName("Height Base")
            obj.sticky = false
            obj.setInvisibleTo(_visible and {} or utils.hideFromPlayersArray())

            -- Retrieve tags from the original token and copy them to the shadow
            local originalTags = self.getTags()
            if originalTags then
                obj.setTags(originalTags)
            end

            local rot = self.getRotation()

            obj.UI.setXml([[
                <Text id="rangeLabel" text="" color="#FFFFFFFF" fontSize="22"
                    fontStyle="Bold" alignment="MiddleCenter" width="600" height="600"
                    position="0 0 -150" rotation="0 0 180" outline="#000000FF" outlineSize="3 -3" />
            ]])

            obj.setRotation({0, rot.y, 0})

            if _floating then
                local band = getRangeBand(_flyOffset / OFFSET_VALUE)
                obj.UI.setAttribute("rangeLabel", "text", RANGE_LABELS[band])
                obj.UI.setAttribute("rangeLabel", "color", colorToHex(RANGE_COLORS[band]))
            end

            Wait.condition(function()
                setShadowInteractable(_floating)
            end, function() return not obj.loading_custom end)
        end
    })
end

-- Cheap gate: only pay for the (relatively expensive) raycast when the
-- token's x/z has actually moved since the last check.
function maybeUpdateGroundIndicator()
    if not _groundIndicator then
        return
    end

    -- If we are floating, the shadow acts as the anchor and doesn't follow the mini.
    if _floating then
        return
    end

    local pos = self.getPosition()
    if _lastIndicatorPos
        and math.abs(pos.x - _lastIndicatorPos.x) < 0.05
        and math.abs(pos.z - _lastIndicatorPos.z) < 0.05
    then
        return
    end

    _lastIndicatorPos = {x = pos.x, z = pos.z}
    updateGroundIndicator()
end

function updateGroundIndicator()
    if not _groundIndicator then
        return
    end

    local pos = self.getPosition()
    local groundY = getGroundHeight()
    _groundIndicator.setPosition({pos.x, groundY + 0.02, pos.z})
end

function destroyGroundIndicator()
    if _groundIndicator then
        destroyObject(_groundIndicator)
        _groundIndicator = nil
    end
end

function onDestroy()
    destroyGroundIndicator()
end

-- ===== end ground shadow indicator =====

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
    print("setMaxHP function")
    print("amount:", amount)
    if (data.hp == data.maxHp) then
        print("data.hp equals data.maxHp")
        data.hp = tonumber(amount)
    end
    data.maxHp = tonumber(amount)
    local vals = {
        scale=2.1/amount.." 0.35 0.25",
        width=100*amount
    }
    log(vals, "vals")
    local smallvals = {
        scale=1.45/amount.." 0.25 0.5",
        width=100*amount
    }
    if (tonumber(data.hp) > tonumber(amount)) then
        print("data.hp is greater than amount")
        data.hp = tonumber(amount)
    end
    changeHP(0)
    self.UI.setAttributes("smallhp", smallvals)
    updateSave()
end

function changeHP(amount)
    data.hp = tonumber(data.hp)+tonumber(amount)
    if (tonumber(data.hp) <= 0) then
        data.hp = 0
        self.UI.setAttribute("smallHp", "color", "#ff0000ff")
    else
        self.UI.setAttribute("smallHp", "color", "Black")
    end
    if (tonumber(data.hp) > tonumber(data.maxHp)) then data.hp = data.maxHp end
    self.UI.setValue("smallhp", barString("□", "■", data.hp, data.maxHp))

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
        self.UI.setAttribute("smallstress", "color", "#ff6a00ff")
    else
        self.UI.setAttribute("smallstress", "color", "Black")
    end
    if (tonumber(data.stress) > tonumber(data.maxStress)) then data.stress = data.maxStress end
    self.UI.setValue("smallstress", barString("□", "■", data.stress, data.maxStress))

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

    -- Fly height button
    self.createButton(
        {
            click_function = "resetFlyButton",
            function_owner = self,
            label = "+999",
            position = {x = 1.3, y = 0.05, z = z_pos},
            rotation = {0, 0, 0},
            width = 600,
            height = 475,
            font_size = 300,
            color = {0, 0.4550, 0.8510, 1},
            font_color = {1, 1, 1, 1},
            tooltip = "Height",
            scale = {0.3, 0.3, 0.3}
        }
    )
    hideHeightButton()

    Wait.time(function()
        lastAng = -1
        alignPivot()
        -- spawnGroundIndicator()
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

function setupDMUI()
    self.addContextMenuItem("Toggle UI", toggleUI, true)
    self.addContextMenuItem("Raise UI", raiseUI, true)
    self.addContextMenuItem("Lower UI", lowerUI, true)
    self.addContextMenuItem("Fly Up", flyUp, true)
    self.addContextMenuItem("Fly Down", flyDown, true)
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
        
        local XMLString = [[
            <Defaults>
                <Button visibility="Black"/>
                <InputField visibility="Black"/>
                <Button tooltipOffset="-25" tooltipBackgroundColor="#000000ff" color="#ffffff00" textColor="#000000ff" textAlignment="MiddleCenter"/>
                <Button class="clickable" color="#ffffffff" colors="#ffffff00|#ffff0040|#00000040|#ffffff00"/>
            </Defaults>
            <Panel id="scale">
                <Panel id="pivot" visibility="Black" active="]]..tostring(data.showing)..[[" offsetXY="0 0" scale="1 1 1" rotation="0 0 0">
                    <Panel visibility="Black" id="height">
                        <Panel id="container" visibility="Black" offsetXY="0 0" scale="2 2 2" rotation="-45 0 0">
                            <Image
                                id="bars"
                                image="bars"
                                offsetXY="0 20"
                                width="200"
                                height="85"
                                scale="0.525 0.525 0.525"
                            >
                                <Text
                                    id="smallhp"
                                    color="Black"
                                    fontSize="150"
                                    width="]]..100*data.maxHp..[["
                                    height="200"
                                    offsetXY="17 -2"
                                    scale="]]..1.45/data.maxHp..[[ 0.25 0.25"
                                >]]..barString("□", "■", data.hp, data.maxHp)..[[</Text>

                                <Text
                                    id="smallstress"
                                    color="Black"
                                    fontSize="150"
                                    width="]]..100*data.maxStress..[["
                                    height="200"
                                    offsetXY="17 -29"
                                    scale="]]..1.45/data.maxStress..[[ 0.17 0.25"
                                >]]..barString("□", "■", data.stress, data.maxStress)..[[</Text>

                                <Text
                                    id="smallDifficulty"
                                    color="Black"
                                    fontSize="30"
                                    width="60"
                                    height="60"
                                    offsetXY="0 23"
                                    scale="0.8 0.8 0.8"
                                    alignment="MiddleCenter"
                                >]]..data.difficulty..[[</Text>

                                <Button
                                    id="incHPSmall"
                                    onClick="increaseHP"
                                    class="clickable"
                                    offsetXY="90 -1"
                                    width="40"
                                    height="40"
                                ></Button>
                                <Button
                                    id="decHPSmall"
                                    onClick="decreaseHP"
                                    class="clickable"
                                    offsetXY="-90 -1"
                                    width="40"
                                    height="40"
                                ></Button>

                                <Button
                                    id="incStressSmall"
                                    onClick="increaseStress"
                                    class="clickable"
                                    offsetXY="90 -40"
                                    width="40"
                                    height="40"
                                ></Button>
                                <Button
                                    id="decStressSmall"
                                    onClick="decreaseStress"
                                    class="clickable"
                                    offsetXY="-90 -40"
                                    width="40"
                                    height="40"
                                ></Button>
                            </Image>
                        </Panel>
                    </Panel>
                </Panel>
            </Panel>
        ]]

        local panelPosY = 350
        if (self.hasTag(OBJECT_TAGS.boss_token)) then
            panelPosY = 480
        end

        require("src.data.condition_images")

        local iconSize = 100

        XMLString = XMLString .. [[
            <GridLayout scale="1 1 1" cellSize="]]..iconSize..[[ ]]..iconSize..[[" childAlignment="MiddleCenter" id="conditions" constraint="FixedRowCount" constraintCount="1"  position="0 0 -]]..panelPosY..[[" rotation="90 0 0">
                <Image id="restrained" width="]]..iconSize..[[" height="]]..iconSize..[[" class="condition" image="]]..CONDITIONS["restrained"].url..[["  active="false" />
                <Image id="vulnerable" width="]]..iconSize..[[" height="]]..iconSize..[[" class="condition" image="]]..CONDITIONS["vulnerable"].url..[[" rotation="0 0 180"  active="false" />
                <Image id="stressed" width="]]..iconSize..[[" height="]]..iconSize..[[" class="condition" image="]]..CONDITIONS["stressed"].url..[["  active="false" />
                <Image id="bloodied" width="]]..iconSize..[[" height="]]..iconSize..[[" class="condition" image="]]..CONDITIONS["bloodied"].url..[["  active="false" />
                <Image id="hidden" width="]]..iconSize..[[" height="]]..iconSize..[[" class="condition" image="]]..CONDITIONS["hidden"].url..[["  active="false" visibility="Black" />
            </GridLayout>
        ]]

        if data.black_name then
            local p = 35
            if IM_BOSS then
                p = 15
            end

            XMLString = XMLString .. [[
                <Text id="BlackName" scale="1 1 1" fontSize="34" visibility="Black" text="]]..data.black_name..[[" color="Black" position="0 ]].. p ..[[ -50" rotation="90 270 90" fontStyle="Bold" outline="White" outlineSize="1 -1" />
            ]]
        end

        self.UI.setXml(XMLString)
        self.setName(data.name)
    end, 0.5)
    Wait.time(function()
        lastAng = -1
        alignPivot()
    end, 0.75)
end

function toggleCondition(conditionName)
    local conditionState = nil
    if (self.UI.getAttribute(conditionName, "active") == "true") then
        conditionState = "false"
    else
        conditionState = "true"
    end

    self.UI.setAttribute(conditionName, "active", conditionState)
end

function hasScriptingTags(obj)
    return utils.hasTagsFromList(obj, {OBJECT_TAGS.monster_token, OBJECT_TAGS.boss_token})
end

function toggleVisibilityMenu(player_color)
    if player_color ~= "Black" then
        return
    end

    _visible = not _visible

    local objs = Player["Black"].getSelectedObjects()
    for i = 1, #objs do
        if hasScriptingTags(objs[i]) then
            if not _visible then
                objs[i].setInvisibleTo(utils.hideFromPlayersArray())

                local c = objs[i].getColorTint()
                objs[i].setColorTint({r=c.r, g=c.g, b=c.b, a=0.3})

            else
                objs[i].setInvisibleTo({})

                local c = objs[i].getColorTint()
                objs[i].setColorTint({r=c.r, g=c.g, b=c.b, a=1})
            end

            if objs[i] == self and _groundIndicator then
                _groundIndicator.setInvisibleTo(_visible and {} or utils.hideFromPlayersArray())
            end

            toggleCondition("hidden")
        end
    end
end