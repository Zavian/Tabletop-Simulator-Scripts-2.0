--[[StartXML
<Defaults>
    <!-- Swiss Minimalist Defaults -->
    <Text color="#F8FAFC" fontStyle="Bold" alignment="MiddleCenter" />
    <Button color="#1E293B" textColor="#F1F5F9" hoverColor="#334155" pressColor="#0F172A" fontStyle="Bold" outline="#475569" outlineSize="1 1" />
    <Panel color="Transparent" />

    <!-- Class Defaults -->
    <Text class="swiss-label" fontSize="10" color="#94A3B8" alignment="MiddleLeft" />
    <Button class="swiss-step" width="28" height="28" fontSize="16" color="#1E293B" hoverColor="#334155" textColor="#F8FAFC" outline="#334155" outlineSize="1 1" />
    <Button class="swiss-gear" width="26" height="26" fontSize="12" color="#1E293B" hoverColor="#475569" textColor="#CBD5E1" outline="#334155" outlineSize="1 1" />
</Defaults>

<!-- Main Container -->
<Panel position="0 300 -50" width="560" height="400" color="#0A0E17FA" outline="#334155" outlineSize="1 1" padding="12" rectAlignment="MiddleCenter" id="StatsPanel">
    <VerticalLayout spacing="4">
        
        <!-- 1. DEFENSE STATS -->
        <GridLayout cellSize="263 120" spacing="10 0" height="120">
            
            <!-- Evasion -->
            <VerticalLayout color="#0F172A" outline="#334155" outlineSize="1 1" padding="6" spacing="2">
                <HorizontalLayout height="18">
                    <Text text="EVASION" class="swiss-label" color="#CBD5E1" />
                    <Button id="edit_evasion" text="EDIT" width="40" height="18" fontSize="8" color="#1E293B" textColor="#F8FAFC" outline="#475569" outlineSize="1 1" />
                </HorizontalLayout>
                <Text id="evasion" text="10" color="#FFFFFF" fontSize="32" fontStyle="Bold" height="44" />
            </VerticalLayout>

            <!-- Armor -->
            <VerticalLayout color="#0F172A" outline="#334155" outlineSize="1 1" padding="6" spacing="2">
                <HorizontalLayout height="18">
                    <Text text="ARMOR SCORE" class="swiss-label" color="#CBD5E1" />
                    <Button id="set_max_armor" text="SET MAX" width="54" height="18" fontSize="8" color="#1E293B" textColor="#F8FAFC" outline="#475569" outlineSize="1 1" />
                </HorizontalLayout>

                <HorizontalLayout height="32" spacing="6" childAlignment="MiddleCenter">
                    <Button id="lose_armor" text="-" class="swiss-step" />
                    <Text id="armor_display" text="2 / 6" color="#FFFFFF" fontSize="22" fontStyle="Bold" width="90" />
                    <Button id="gain_armor" text="+" class="swiss-step" />
                </HorizontalLayout>

                <GridLayout id="armor_slots" cellSize="18 18" spacing="3 3" constraint="FixedColumnCount" constraintCount="9" childAlignment="MiddleCenter" height="44" color="#030712" outline="#1E293B" outlineSize="1 1" />
            </VerticalLayout>

        </GridLayout>

        <!-- 2. DAMAGE THRESHOLDS -->
        <GridLayout cellSize="172 70" spacing="10 0" height="70">
            
            <!-- Minor -->
            <VerticalLayout color="#0F172A" outline="#334155" outlineSize="1 1" padding="4" spacing="1">
                <Text text="MINOR DAMAGE" fontSize="9" color="#94A3B8" height="14" />
                <Text id="minor_damage_display" text="1 - 6" fontSize="16" color="#FFFFFF" fontStyle="Bold" height="20" />
                <Text text="MARK 1 HP" fontSize="8" color="#64748B" height="12" />
            </VerticalLayout>

            <!-- Major -->
            <VerticalLayout color="#484127" outline="#FDE68A" outlineSize="1 1" padding="4" spacing="1">
                <Text text="MAJOR DAMAGE" fontSize="9" color="#FCD34D" height="14" />
                <Text id="first_threshold" text="7+" color="#FDE68A" fontSize="20" fontStyle="Bold" height="22" />
                <Text text="MARK 2 HP" fontSize="8" color="#F59E0B" height="12" />
            </VerticalLayout>

            <!-- Severe -->
            <VerticalLayout color="#442D2D" outline="#FCA5A5" outlineSize="1 1" padding="4" spacing="1">
                <Text text="SEVERE DAMAGE" fontSize="9" color="#FCA5A5" height="14" />
                <Text id="second_threshold" text="14+" color="#FECACA" fontSize="20" fontStyle="Bold" height="22" />
                <Text text="MARK 3 HP" fontSize="8" color="#EF4444" height="12" />
            </VerticalLayout>

        </GridLayout>

        <!-- 3. RESOURCE WELLS -->
        <VerticalLayout spacing="6">
            
            <!-- HP -->
            <HorizontalLayout height="44" color="#0F172A" outline="#334155" outlineSize="1 1" padding="4" spacing="6" childAlignment="MiddleLeft">
                <Button id="set_max_hp" text="⚙" class="swiss-gear" />
                <Text text="HIT POINTS" width="65" alignment="MiddleLeft" wrapText="false" fontSize="11" color="#F87171" fontStyle="Bold" />
                <Button id="suffer_hp" text="-" class="swiss-step" />
                <GridLayout id="hp" cellSize="22 22" spacing="2 2" constraint="FixedRowCount" constraintCount="1" childAlignment="MiddleCenter" height="28" color="#030712" outline="#1E293B" outlineSize="1 1" />
                <Button id="recover_hp" text="+" class="swiss-step" />
            </HorizontalLayout>

            <!-- Stress -->
            <HorizontalLayout height="44" color="#0F172A" outline="#334155" outlineSize="1 1" padding="4" spacing="6" childAlignment="MiddleLeft">
                <Button id="set_max_stress" text="⚙" class="swiss-gear" />
                <Text text="STRESS" width="65" alignment="MiddleLeft" wrapText="false" fontSize="11" color="#FBBF24" fontStyle="Bold" />
                <Button id="suffer_stress" text="-" class="swiss-step" />
                <GridLayout id="stress" cellSize="22 22" spacing="2 2" constraint="FixedRowCount" constraintCount="1" childAlignment="MiddleCenter" height="28" color="#030712" outline="#1E293B" outlineSize="1 1" />
                <Button id="recover_stress" text="+" class="swiss-step" />
            </HorizontalLayout>

            <!-- Hope -->
            <HorizontalLayout height="44" color="#0F172A" outline="#334155" outlineSize="1 1" padding="4" spacing="6" childAlignment="MiddleLeft">
                <Button id="set_max_hope" text="⚙" class="swiss-gear" />
                <Text text="HOPE" width="65" alignment="MiddleLeft" wrapText="false" fontSize="11" color="#60A5FA" fontStyle="Bold" />
                <Button id="lose_hope" text="-" class="swiss-step" />
                <GridLayout id="hope" cellSize="22 22" spacing="2 2" constraint="FixedRowCount" constraintCount="1" childAlignment="MiddleCenter" height="28" color="#030712" outline="#1E293B" outlineSize="1 1" />
                <Button id="gain_hope" text="+" class="swiss-step" />
            </HorizontalLayout>

        </VerticalLayout>

    </VerticalLayout>
</Panel>
StopXML--]]
require("src.data.config")

local utils = require("src.core.utils")
local promise = require("src.core.promise")

local imageAssets = {
    armor = {
        useColor = false,
        empty = "https://steamusercontent-a.akamaihd.net/ugc/14703946279316053304/9CBA4489042257736865EECEB3169AA4DF44C969/",
        filled = "https://steamusercontent-a.akamaihd.net/ugc/14796930385077024339/7E84D6CDFFBAE9FD7391FDCFF72A04F07575A81A/",
        color = {
            empty = "#000000",
            filled = "#8796F6"
        }
    },
    hope = {
        empty = "https://steamusercontent-a.akamaihd.net/ugc/12711628340321279551/7FB25DE24927C7013C51155B4920788787794290/",
        filled = "https://steamusercontent-a.akamaihd.net/ugc/9553207623171576974/8C777BB56569223B78913805E39BC41FB84E6EFC/"
    },
    hp = {
        filled = "https://steamusercontent-a.akamaihd.net/ugc/17692463545472723776/FDCF6A7BD047FF0FE95D7B18C1D742804F096322/",
        empty = "https://steamusercontent-a.akamaihd.net/ugc/17933638928571452076/35B105A67D9B48031480BC45601CBB3775101C52/"
    },
    stress = {
        filled = "https://steamusercontent-a.akamaihd.net/ugc/17766890096207944889/BE4260799C63669EC0D532AF8AFB372B5C3671B8/",
        empty = "https://steamusercontent-a.akamaihd.net/ugc/17169108119283629613/E491D3B5B4EF77B2F44E1CFABF3CA2B17009431C/"
    }
}

local _defaults = {
    max_hope = 6,
    max_hp = 12,
    max_stress = 12,
    max_armor = 18,
    max_evasion = 25
}

local linked = nil
local showing_ui = false


function onLoad()
    utils.setXML(self, self)

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
        Injector_setMaxHP(data.max_hp, nil, data.hp or data.max_hp)
    end
    if data.max_stress then
        Injector_setMaxStress(data.max_stress, nil, data.stress or data.max_stress)
    end
    if data.max_armor then
        Injector_setMaxArmor(data.max_armor, nil, data.armor or data.max_armor)
    end
    if data.max_hope then
        Injector_setMaxHope(data.max_hope, nil, data.hope or 0)
    else
        setHope(data.hope or 0)
    end

    -- Restore text displays
    setThresholds(data.first_threshold or 0, data.second_threshold or 0)
    setEvasion(data.evasion or 0)
    setArmorDisplay(data.armor or data.max_armor or 0)
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

local images = {
    hp = "https://steamusercontent-a.akamaihd.net/ugc/17692463545472723776/FDCF6A7BD047FF0FE95D7B18C1D742804F096322/",
    stress = "https://steamusercontent-a.akamaihd.net/ugc/17766890096207944889/BE4260799C63669EC0D532AF8AFB372B5C3671B8/",
    armor = "https://steamusercontent-a.akamaihd.net/ugc/14796930385077024339/7E84D6CDFFBAE9FD7391FDCFF72A04F07575A81A/"
}


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
                position = "0 0 -250",
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

function setMaxHP(amount, current_amount, t)
    -- Define the range for the amount that will affect the icon size.
    -- For example, let's say the size starts decreasing after 1 icon and stops at 10 icons.
    local min_amount = 6
    local max_amount = 12

    -- Define the corresponding icon size range.
    local max_icon_size = 50
    local min_icon_size = 25

    -- Linearly interpolate to find the icon size.
    local icon_size = interpolate(amount, min_amount, max_amount, max_icon_size, min_icon_size)
    icon_size = math.floor(icon_size) -- It's good practice to use whole numbers for UI element sizes.

    t[1].attributes.cellSize = icon_size .. " " .. icon_size

    t[1].children = {}

    for i = 1, amount do
        local icon = {
            tag = "Image",
            attributes = {
                width = icon_size,
                height = icon_size,
                image = images.hp,
                id = "hp_" .. i,
                color = i > current_amount and "#000000" or "#ffffff"
            }
        }
        table.insert(t[1].children, icon)
    end
    return t
end

function setMaxStress(amount, current_amount, t)
    -- Define the range for the amount that will affect the icon size.
    -- For example, let's say the size starts decreasing after 1 icon and stops at 10 icons.
    local min_amount = 6
    local max_amount = 12

    -- Define the corresponding icon size range.
    local max_icon_size = 50
    local min_icon_size = 25

    -- Linearly interpolate to find the icon size.
    local icon_size = interpolate(amount, min_amount, max_amount, max_icon_size, min_icon_size)
    icon_size = math.floor(icon_size) -- It's good practice to use whole numbers for UI element sizes.
    
    t[2].attributes.cellSize = icon_size .. " " .. icon_size

    t[2].children = {}

    for i = 1, amount do
        local icon = {
            tag = "Image",
            attributes = {
                width = icon_size,
                height = icon_size,
                image = images.stress,
                id = "stress_" .. i,
                color = i > current_amount and "#000000" or "#ffffff"
            }
        }
        table.insert(t[2].children, icon)
    end
    return t
end

function setMaxArmor(amount, current_amount, t)
    t[3].children = {}

    for i = 1, amount do
        local icon = {
            tag = "Image",
            attributes = {
                width = 35,
                height = 35,
                image = images.armor,
                id = "armor_" .. i, 
                color = i > current_amount and "#000000" or "#ffffff"
            }
        }
        table.insert(t[3].children, icon)
    end
    return t
end

function sufferHP()
    local target = self.UI.getXmlTable()[1]
    for i = #target.children, 1, -1 do
        local color = self.UI.getAttribute("hp_"..i, "color")
        if not color or color == "#ffffff" then
            self.UI.setAttribute("hp_"..i, "color", "#000000")
            data.hp = data.hp - 1
            return
        end
    end
end

function healHP()
    local target = self.UI.getXmlTable()[1]
    for i = 1, #target.children do
        local color = self.UI.getAttribute("hp_"..i, "color")
        if color and color == "#000000" then
            self.UI.setAttribute("hp_"..i, "color", "#ffffff")
            data.hp = data.hp + 1
            return
        end
    end
end

function sufferStress()
    local target = self.UI.getXmlTable()[2]
    for i = #target.children, 1, -1 do
        local color = self.UI.getAttribute("stress_"..i, "color")
        if not color or color == "#ffffff" then
            self.UI.setAttribute("stress_"..i, "color", "#000000")
            data.stress = data.stress - 1
            return
        end
    end
end

function healStress()
    local target = self.UI.getXmlTable()[2]
    for i = 1, #target.children do
        local color = self.UI.getAttribute("stress_"..i, "color")
        if color and color == "#000000" then
            self.UI.setAttribute("stress_"..i, "color", "#ffffff")
            data.stress = data.stress + 1
            return
        end
    end
end

function loseArmor()
    local target = self.UI.getXmlTable()[3]
    for i = #target.children, 1, -1 do
        local color = self.UI.getAttribute("armor_"..i, "color")
        if not color or color == "#ffffff" then
            self.UI.setAttribute("armor_"..i, "color", "#000000")
            return
        end
    end
end

function gainArmor()
    local target = self.UI.getXmlTable()[3]
    for i = 1, #target.children do
        local color = self.UI.getAttribute("armor_"..i, "color")
        if color and color == "#000000" then
            self.UI.setAttribute("armor_"..i, "color", "#ffffff")
            return
        end
    end
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

    local asset = imageAssets.hp
    for i = 1, amount do
        local isFilled = (i <= current_amount)
        local attributes = { class = "hp", id = "hp_" .. i }

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

    local asset = imageAssets.stress
    for i = 1, amount do
        local isFilled = (i <= current_amount)
        local attributes = { class = "stress", id = "stress_" .. i }

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

        local asset = imageAssets.hope
        for i = 1, amount do
            local isFilled = (i <= current_amount)
            local attributes = { class = "hope", id = "hope_" .. i }

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
