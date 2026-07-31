--[[StartXML
<Defaults>
    <!-- General Defaults -->
    <Text color="#F3F4F6" fontStyle="Bold" alignment="MiddleCenter" />
    <Button color="#272A34" textColor="#FFFFFF" hoverColor="#3B3E4D" pressColor="#1A1C23" fontStyle="Bold" />
    <Panel color="Transparent" />

    <!-- Custom Class Defaults -->
    <Text class="stat-label" fontSize="11" color="#9CA3AF" />
    <Text class="sub-label" fontSize="9" color="#6B7280" />
</Defaults>

<!-- Main Container Panel -->
<Panel position="0 300 -50" width="560" height="440" color="#0F1015F2" padding="12" rectAlignment="MiddleCenter" id="StatsPanel">
    <VerticalLayout spacing="8">
        
        <!-- ======================================================= -->
        <!-- 1. TOP STATS (EVASION & ARMOR SCORE) - 2 Column Grid   -->
        <!-- ======================================================= -->
        <GridLayout cellSize="263 120" spacing="10 0" height="120">
            
            <!-- Evasion Box -->
            <VerticalLayout color="#181A20" outline="#374151" outlineSize="1 1" padding="6" spacing="2">
                <Text text="EVASION" class="stat-label" height="16" wrapText="false" />
                
                <!-- Text element stays light purple and handles click events -->
                <Text id="evasion" text="0" color="#A78BFA" fontSize="28" fontStyle="Bold" height="46" />
                
                <Text text="Click value to edit" class="sub-label" height="14" wrapText="false" />
            </VerticalLayout>

            <!-- Armor Score Box -->
            <VerticalLayout color="#181A20" outline="#374151" outlineSize="1 1" padding="6" spacing="2">
                <!-- Header -->
                <HorizontalLayout height="20">
                    <Text text="ARMOR SCORE" class="stat-label" alignment="MiddleLeft" wrapText="false" />
                    <Button id="set_max_armor" text="SET MAX" width="60" fontSize="9" height="18" />
                </HorizontalLayout>

                <!-- Score Controls -->
                <HorizontalLayout height="34" spacing="6">
                    <Button id="lose_armor" text="-" width="30" fontSize="16" />
                    <Text id="armor_display" text="0" color="#60A5FA" fontSize="24" fontStyle="Bold" />
                    <Button id="gain_armor" text="+" width="30" fontSize="16" />
                </HorizontalLayout>

                <!-- Grid wraps armor shields into max 9 icons per row (up to 18 total) -->
                <GridLayout id="armor_slots" cellSize="18 18" spacing="3 3" constraint="FixedColumnCount" constraintCount="9" childAlignment="MiddleCenter" height="44" />
            </VerticalLayout>

        </GridLayout>

        <!-- ======================================================= -->
        <!-- 2. DAMAGE THRESHOLDS - 3 Column Grid                    -->
        <!-- ======================================================= -->
        <GridLayout cellSize="172 70" spacing="10 0" height="70">
            
            <!-- Minor Damage -->
            <VerticalLayout color="#181A20" outline="#374151" outlineSize="1 1" padding="4" spacing="1">
                <Text text="MINOR DAMAGE" fontSize="9" color="#9CA3AF" height="14" wrapText="false" />
                
                <!-- Dynamic Minor Damage text updated via Lua -->
                <Text id="minor_damage_display" text="1 - 5" fontSize="16" color="#FFFFFF" fontStyle="Bold" height="20" wrapText="false" />
                
                <Text text="Mark 1 HP" class="sub-label" color="#D1D5DB" height="12" wrapText="false" />
            </VerticalLayout>

            <!-- Major Damage (Clickable) -->
            <VerticalLayout color="#181A20" outline="#374151" outlineSize="1 1" padding="4" spacing="1">
                <Text text="MAJOR DAMAGE" fontSize="9" color="#FBBF24" height="14" wrapText="false" />
                
                <!-- Text element stays gold (#FBBF24) and handles click events -->
                <Text id="first_threshold" text="0" color="#FBBF24" fontSize="20" fontStyle="Bold" height="22" />
                
                <Text text="Mark 2 HP" class="sub-label" color="#D1D5DB" height="12" wrapText="false" />
            </VerticalLayout>

            <!-- Severe Damage (Clickable) -->
            <VerticalLayout color="#181A20" outline="#374151" outlineSize="1 1" padding="4" spacing="1">
                <Text text="SEVERE DAMAGE" fontSize="9" color="#EF4444" height="14" wrapText="false" />
                
                <!-- Text element stays red (#EF4444) and handles click events -->
                <Text id="second_threshold" text="0" color="#EF4444" fontSize="20" fontStyle="Bold" height="22" />
                
                <Text text="Mark 3 HP" class="sub-label" color="#D1D5DB" height="12" wrapText="false" />
            </VerticalLayout>

        </GridLayout>

        <!-- ======================================================= -->
        <!-- 3. RESOURCE TRACKERS (HP, STRESS, HOPE)                 -->
        <!-- ======================================================= -->
        <VerticalLayout spacing="6">
            
            <!-- HP Tracker Row -->
            <HorizontalLayout height="44" color="#181A20" outline="#374151" outlineSize="1 1" padding="4" spacing="6">
                <Button id="set_max_hp" text="⚙" width="28" fontSize="12" color="#374151" hoverColor="#4B5563" />
                <Text text="HP" width="55" alignment="MiddleLeft" wrapText="false" fontSize="13" color="#EF4444" />
                <Button id="suffer_hp" width="32" text="-" fontSize="18" />
                
                <GridLayout id="hp" cellSize="22 22" spacing="2 2" constraint="FixedRowCount" constraintCount="1" childAlignment="MiddleCenter" height="28" color="#111827" />
                
                <Button id="recover_hp" width="32" text="+" fontSize="18" />
            </HorizontalLayout>

            <!-- Stress Tracker Row -->
            <HorizontalLayout height="44" color="#181A20" outline="#374151" outlineSize="1 1" padding="4" spacing="6">
                <Button id="set_max_stress" text="⚙" width="28" fontSize="12" color="#374151" hoverColor="#4B5563" />
                <Text text="STRESS" width="55" alignment="MiddleLeft" wrapText="false" fontSize="11" color="#F59E0B" />
                <Button id="suffer_stress" width="32" text="-" fontSize="18" />
                
                <GridLayout id="stress" cellSize="22 22" spacing="2 2" constraint="FixedRowCount" constraintCount="1" childAlignment="MiddleCenter" height="28" color="#111827" />
                
                <Button id="recover_stress" width="32" text="+" fontSize="18" />
            </HorizontalLayout>

            <!-- Hope Tracker Row -->
            <HorizontalLayout height="44" color="#181A20" outline="#374151" outlineSize="1 1" padding="4" spacing="6">
                <Button id="set_max_hope" text="⚙" width="28" fontSize="12" color="#374151" hoverColor="#4B5563" />
                <Text text="HOPE" width="55" alignment="MiddleLeft" wrapText="false" fontSize="12" color="#3B82F6" />
                <Button id="lose_hope" width="32" text="-" fontSize="18" />
                
                <GridLayout id="hope" cellSize="24 24" spacing="4 2" constraint="FixedRowCount" constraintCount="1" childAlignment="MiddleCenter" height="28" color="#111827">
                    <Image id="hope_1" image="https://steamusercontent-a.akamaihd.net/ugc/12670953746498142696/BE3FF12AC9766F669C026E325E3A14FB21FAC75C/" />
                    <Image id="hope_2" image="https://steamusercontent-a.akamaihd.net/ugc/12670953746498142696/BE3FF12AC9766F669C026E325E3A14FB21FAC75C/" />
                    <Image id="hope_3" image="https://steamusercontent-a.akamaihd.net/ugc/12670953746498142696/BE3FF12AC9766F669C026E325E3A14FB21FAC75C/" />
                    <Image id="hope_4" image="https://steamusercontent-a.akamaihd.net/ugc/12670953746498142696/BE3FF12AC9766F669C026E325E3A14FB21FAC75C/" />
                    <Image id="hope_5" image="https://steamusercontent-a.akamaihd.net/ugc/12708366135666346318/BB64E4C4F488D80BE6E4F71C3338027600E499AF/" />
                    <Image id="hope_6" image="https://steamusercontent-a.akamaihd.net/ugc/12708366135666346318/BB64E4C4F488D80BE6E4F71C3338027600E499AF/" />
                </GridLayout>
                
                <Button id="gain_hope" width="32" text="+" fontSize="18" />
            </HorizontalLayout>

        </VerticalLayout>

    </VerticalLayout>
</Panel>
StopXML--xml]]
require("src.data.config")

local utils = require("src.core.utils")
local promise = require("src.core.promise")

local imageAssets = {
    armor = {
        empty = "https://steamusercontent-a.akamaihd.net/ugc/9694915526965512541/CF069EC63EA00DC557F7F7789824FD2DF7C01967/",
        filled = "https://steamusercontent-a.akamaihd.net/ugc/2426949702261775967/768DF5E97CB1FBE314C632B9FFDEB2D433A39690/",
        color = {
            empty = "#000000",
            filled = "#8796F6"
        }
    },
    hope = {
        empty = "https://steamusercontent-a.akamaihd.net/ugc/12708366135666346318/BB64E4C4F488D80BE6E4F71C3338027600E499AF/",
        filled = "https://steamusercontent-a.akamaihd.net/ugc/12670953746498142696/BE3FF12AC9766F669C026E325E3A14FB21FAC75C/"
    }
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

        -- hidePanel("StatsPanel")

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
        setThresholds(data.first_threshold or 0, data.second_threshold or 0)
        setEvasion(data.evasion or 0)
        setArmorDisplay(data.armor or data.max_armor or 0)
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
    hp = "https://steamusercontent-a.akamaihd.net/ugc/10494050456455959184/B2057166B19BAE387F62C851A6404592248EB3A1/",
    stress = "https://steamusercontent-a.akamaihd.net/ugc/15261052138615878051/6A2F452DCA95EDA5CDD8FD82EC58F4B286AA585B/",
    armor = "https://steamusercontent-a.akamaihd.net/ugc/2426949702261775967/768DF5E97CB1FBE314C632B9FFDEB2D433A39690/"
}


function set_data(params)
    if not params or not params.hp or not params.stress then
        print('invalid params')
        return 
    end

    log(params)

    self.setTags({"player_token", "movement_measurement", "flying"})
    data.hp = tonumber(params.hp)
    data.maxHp = tonumber(params.max_hp)
    data.stress = tonumber(params.stress)
    data.maxStress = tonumber(params.max_stress)
    data.armor = tonumber(params.armor)
    data.maxArmor = tonumber(params.max_armor)

    log(data, "token data")

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
                id = "armor_container",
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

    linked = obj

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

function showPanel(panel)
    self.UI.show(panel)
end

function hidePanel(panel)
    self.UI.hide(panel)
end

function Injector_setMaxHP(amount, player_color, current_amount)
    amount = tonumber(amount)

    if (amount < 1) then
        amount = 1
    end

    if (amount > 12) then
        utils.error("Max HP cannot exceed 12.", player_color)
        return
    end

    if not current_amount then
        current_amount = amount
    end

    current_amount = tonumber(current_amount)

    local xml_table = self.UI.getXmlTable()
    local grid = utils.UI_findElementById(xml_table, "hp")  

    grid.children = {}

    for i = 1, amount do
        local image = {
            tag = "Image",
            attributes = {
                class = "hp",
                id = "hp_" .. i,
                color = i > current_amount and "#000000" or "#ffffff"
            }
        }
        
        table.insert(grid.children, image)
    end

    log(grid)

    self.UI.setXmlTable(xml_table)
    utils.appendData(self, {max_hp = amount})
end

function Injector_setMaxStress(amount, player_color, current_amount)
    amount = tonumber(amount)

    if (amount < 1) then
        amount = 1
    end

    if (amount > 12) then
        utils.error("Max Stress cannot exceed 12.", player_color)
        return
    end

    if not current_amount then
        current_amount = amount
    end

    current_amount = tonumber(current_amount)

    local xml_table = self.UI.getXmlTable()
    local grid = utils.UI_findElementById(xml_table, "stress")

    grid.children = {}    

    for i = 1, amount do
        local image = {
            tag = "Image",
            attributes = {
                class = "stress",
                id = "stress_" .. i,
                color = i > current_amount and "#000000" or "#ffffff"
            }
        }
        table.insert(grid.children, image)
    end

    self.UI.setXmlTable(xml_table)
    utils.appendData(self, {max_stress = amount})
end


function Injector_setMaxArmor(amount,  player_color, current_amount)

    amount = tonumber(amount)

    if (amount < 1) then
        amount = 1
    end

    if (amount > 18) then
        utils.error("Armor Slots cannot exceed 18.", player_color)
        return
    end

    if not current_amount then
        current_amount = amount
    end

    current_amount = tonumber(current_amount)

    local xml_table = self.UI.getXmlTable()
    local grid = utils.UI_findElementById(xml_table, "armor_slots")

    grid.children = {}

    for i = 1, amount do
        local image = {
            tag = "Image",
            attributes = {
                class = "armor-filled",
                id = "armor_" .. i,
                image = imageAssets.armor.filled,
                color = i > current_amount and imageAssets.armor.color.empty or imageAssets.armor.color.filled
            }
        }
        table.insert(grid.children, image)
    end

    self.UI.setXmlTable(xml_table)
    utils.appendData(self, {max_armor = amount})
end

function setHope(amount)
    for i = 1, 6 do
        local image = i > amount and imageAssets.hope.empty or imageAssets.hope.filled
        self.UI.setAttribute("hope_" .. i, "image", image)
    end
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
                ["max_armor"] = function()
                    Injector_setMaxArmor(text, player_color.color)
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
    local xml_table = self.UI.getXmlTable()
    local target = utils.UI_findElementById(xml_table, "hp")
    for i = #target.children, 1, -1 do
        local color = self.UI.getAttribute("hp_"..i, "color")
        if not color or color == "#ffffff" then
            self.UI.setAttribute("hp_"..i, "color", "#000000")
            utils.appendData(self, {hp = i - 1})
            linked.call("sufferHP")
            return
        end
    end
end

function recoverHP()
    local xml_table = self.UI.getXmlTable()
    local target = utils.UI_findElementById(xml_table, "hp")
    for i = 1, #target.children do
        local color = self.UI.getAttribute("hp_"..i, "color")
        if color and color == "#000000" then
            self.UI.setAttribute("hp_"..i, "color", "#ffffff")
            utils.appendData(self, {hp = i })
            linked.call("healHP")
            return
        end
    end
end

function sufferStress()
    local xml_table = self.UI.getXmlTable()
    local target = utils.UI_findElementById(xml_table, "stress")
    for i = #target.children, 1, -1 do
        local color = self.UI.getAttribute("stress_"..i, "color")
        if not color or color == "#ffffff" then
            self.UI.setAttribute("stress_"..i, "color", "#000000")
            utils.appendData(self, {stress = i - 1})
            linked.call("sufferStress")
            return
        end
    end
end

function recoverStress()
    local xml_table = self.UI.getXmlTable()
    local target = utils.UI_findElementById(xml_table, "stress")
    for i = 1, #target.children do
        local color = self.UI.getAttribute("stress_"..i, "color")
        if color and color == "#000000" then
            self.UI.setAttribute("stress_"..i, "color", "#ffffff")
            utils.appendData(self, {stress = i })
            linked.call("healStress")
            return
        end
    end
end

function loseArmor()
    local xml_table = self.UI.getXmlTable()
    local target = utils.UI_findElementById(xml_table, "armor_slots")
    for i = #target.children, 1, -1 do
        local image = self.UI.getAttribute("armor_"..i, "color")
        if not image or image == imageAssets.armor.color.filled then
            self.UI.setAttribute("armor_"..i, "color", imageAssets.armor.color.empty)
            utils.appendData(self, {armor = i - 1})
            self.UI.setAttribute("armor_display", "text", i - 1)
            linked.call("loseArmor")
            return
        end
    end
end

function gainArmor()
    local xml_table = self.UI.getXmlTable()
    local target = utils.UI_findElementById(xml_table, "armor_slots")
    for i = 1, #target.children do
        local color = self.UI.getAttribute("armor_"..i, "color")
        if not color or color == imageAssets.armor.color.empty then
            self.UI.setAttribute("armor_"..i, "color", imageAssets.armor.color.filled)
            utils.appendData(self, {armor = i })
            self.UI.setAttribute("armor_display", "text", i)
            linked.call("gainArmor")
            return
        end
    end
end

function loseHope()
    local xml_table = self.UI.getXmlTable()
    local target = utils.UI_findElementById(xml_table, "hope")
    for i = #target.children, 1, -1 do
        local image = self.UI.getAttribute("hope_"..i, "image")
        if not image or image == imageAssets.hope.filled then
            self.UI.setAttribute("hope_"..i, "image", imageAssets.hope.empty)
            utils.appendData(self, {hope = i - 1})
            return
        end
    end
end

function gainHope()
    local xml_table = self.UI.getXmlTable()
    local target = utils.UI_findElementById(xml_table, "hope")
    for i = 1, #target.children do
        local image = self.UI.getAttribute("hope_"..i, "image")
        if image and image == imageAssets.hope.empty then
            self.UI.setAttribute("hope_"..i, "image", imageAssets.hope.filled)
            utils.appendData(self, {hope = i })
            return
        end
    end
end
