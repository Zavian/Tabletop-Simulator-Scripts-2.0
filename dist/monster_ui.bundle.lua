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
end)
__bundle_register("src.data.condition_images", function(require, _LOADED, __bundle_register, __bundle_modules)
CONDITIONS = {
    ranger_focus = {
        url = "https://steamusercontent-a.akamaihd.net/ugc/2426950071414376932/2BBC97B068AFDD9AB4F2DA6F94977EE41D70754C/"
    },
    vulnerable = {
        url = "https://steamusercontent-a.akamaihd.net/ugc/2426949702261761386/F109A21CE2ABB207A0096EC817BB2BA9A7DBFFDC/",
        rotation = "0 180 0"
    },
    hidden = {
        url = "https://steamusercontent-a.akamaihd.net/ugc/2426949702261748427/640665717D8050B053DE8EB2944C30CF817FCA5C/",
    },
    restrained = {
        url = "https://steamusercontent-a.akamaihd.net/ugc/2426949702261749880/B2B7FFA29ED39AAFCCD86AF675A5C9FDA54BFBE0/"
    },
    stressed = {
        url = "https://steamusercontent-a.akamaihd.net/ugc/2426949702261749880/B2B7FFA29ED39AAFCCD86AF675A5C9FDA54BFBE0/"
    },
    bloodied = {
        url = "https://steamusercontent-a.akamaihd.net/ugc/2426949702261749880/B2B7FFA29ED39AAFCCD86AF675A5C9FDA54BFBE0/"
    }
}
end)
__bundle_register("src.core.events", function(require, _LOADED, __bundle_register, __bundle_modules)
--- @class MonsterData
--- @field name string
--- @field hp string
--- @field ac string
--- @field mov string
--- @field size string
--- @field side string
--- @field image string (optional)

local Events = {}

-- Dictionary for possible events
Events.EVENT_NAMES = {
    parse_monster_data = "parse_monster_data",
    create_json_note = "create_json_note",

    -- in development
    player_hp_update = "player_hp_update",
    monster_hp_update = "monster_hp_update",
    monster_stress_update = "monster_stress_update",
    ruin_update = "ruin_update",
    on_roll = "on_roll",
    create_monster = "create_monster"
}



--- Subscribes to an event.
--- @param eventName string The name of the event.
--- @param func string The callback function name.
--- @overload fun(eventName: "parse_monster_data", func: fun(data: MonsterData))
--- @overload fun(eventName: "create_json_note", func: fun(data: MonsterData))
function Events.subscribe(eventName, func)
    Global.call("event_subscribe", {eventName = eventName, guid = self.getGUID(), functionName = func})
end

--- Broadcasts an event.
--- @param eventName string The name of the event.
--- @param ... any The event data.
--- @overload fun(eventName: "parse_monster_data", data: MonsterData)
--- @overload fun(eventName: "create_json_note", data: MonsterData)
function Events.broadcast(eventName, ...)
    Global.call("event_broadcast", {eventName = eventName, args = {...}})
end

return Events
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

OBJECT_TAGS = {
    npc_commander = "npc_commander",
    clever_notecard = "clever_notecard",
    targeted_reticle = "targeted_reticle",
    json_note_container = "json_note_container",
    monster_token = "monster_token",
    boss_token = "boss_token",
    infinite_container = "infinite_container",
    movement_measurement = "movement_measurement",
    player = "player_token"
}

SAVED_DATA = {
    PLAYER = {
        ["Black"] = {
            autoSnap = false
        },
    }
}
end)
__bundle_register("src.data.asset_urls", function(require, _LOADED, __bundle_register, __bundle_modules)
ASSET_URLS = {
    monster_model_url = "https://steamusercontent-a.akamaihd.net/ugc/940582727530924131/8296EABA1FAA8BDEBAA853B8FD63AFFC94969F5D/",
    boss_token_url = "https://steamusercontent-a.akamaihd.net/ugc/15386339533060476558/91B6859B49AF1ABA1C63BEACB43CE23B40DB7F35/"
}
end)
return __bundle_require("__root")