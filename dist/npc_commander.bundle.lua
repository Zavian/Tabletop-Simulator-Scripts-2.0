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
require("src.core.utils")
require("src.data.config")
require("src.data.random_names")


local target_reticle = require("src.modules.target_reticle_context_menu")
local events = require("src.core.events")
local promise = require("src.core.promise")
local utils = require("src.core.utils")

local _states = {
    ["player"] = {color = {0, 0, 0.545098}, state = 1},
    ["enemy"] = {color = {0.517647, 0, 0.098039}, bright = {0.94902, 0.184314, 0.32549}, state = 2},
    ["ally"] = {color = {0.039216, 0.368627, 0.211765}, bright = {0.352941, 0.823529, 0.603922}, state = 3},
    ["neutral"] = {color = {0.764706, 0.560784, 0}, bright = {0.933333, 0.741176, 0.219608}, state = 4}
}

_side = "enemy"

function onload()
    self.setTags({OBJECT_TAGS.npc_commander, OBJECT_TAGS.infinite_container})
    
    initializeSelfUI()

    events.subscribe(events.EVENT_NAMES.parse_monster_data, "ParseMonsterData")

    events.subscribe(events.EVENT_NAMES.create_json_note, "createNote")


    target_reticle.create("Mob Spawn Reticle", "monsterSpawnData", OBJECT_TAGS.monster_token)
    target_reticle.create("Save Card Reticle", "saveCardData", OBJECT_TAGS.clever_notecard)
    self.addContextMenuItem("Update token", function()
        Player["Black"].showOptionsDialog("Select tag", {OBJECT_TAGS.boss_token, OBJECT_TAGS.monster_token, OBJECT_TAGS.clever_notecard}, 1,
        function (selected_tag, index, player_color)
            Player["Black"].showInputDialog("Pastebin link",
                function (text, player_color)
                    utils.getOnlineCode(text, function(script)
                        if script then
                            log(script)
                            utils.replaceObjectInBagByTag(self, selected_tag, function(spawned_object)
                                spawned_object.setLock(true)
                                spawned_object.setLuaScript(script)
                            end)
                        end
                    end)
                end)
        end)
    end)
    
end

function initializeSelfUI() 
    debug = #utils.getSeatedPlayers() == 1

    local inputs = {
        {
            -- name input							[0]
            name = "name",
            function_owner = self,
            label = " ",
            position = {-2.94, 0.4, -0.27},
            scale = {0.5, 0.5, 0.5},
            width = 2900,
            height = 424,
            font_size = 350,
            tooltip = "Name",
            value = debug and "/" or "",
            alignment = 2,
            tab = 2
        },
        {
            -- hp input								[2]
            name = "hp",
            function_owner = self,
            label = " ",
            position = {-3.88, 0.4, 0.55},
            scale = {0.5, 0.5, 0.5},
            width = 1100,
            height = 385,
            font_size = 350,
            tooltip = "Hit Points",
            value = debug and "5" or "",
            alignment = 3,
            tab = 2
        },
        {
            -- stress input								[2]
            name = "stress",
            function_owner = self,
            label = " ",
            position = {-2.7, 0.4, 0.55},
            scale = {0.5, 0.5, 0.5},
            width = 1100,
            height = 385,
            font_size = 350,
            tooltip = "Stress",
            value = debug and "5" or "",
            alignment = 3,
            tab = 2
        },
        {
            --difficulty input								[3]
            name = "difficulty",
            function_owner = self,
            label = "Difficulty",
            position = {-1.76, 0.4, 0.55},
            scale = {0.5, 0.5, 0.5},
            width = 650,
            height = 385,
            font_size = 350,
            tooltip = " ",
            alignment = 3,
            validation = 2,
            tab = 2,
            value = debug and "15" or ""
        },
        {
            -- image name						[4]
            name = "image",
            function_owner = self,
            label = " ",
            position = {2.7, 0.4, 1.38},
            scale = {0.5, 0.5, 0.5},
            width = 3150,
            height = 424,
            font_size = 350,
            tooltip = "Url to image (needs Is Boss to be true)",
            alignment = 2,
            tab = 2,
            value = ""
        },
        {
            -- numberToCreate input					[5]
            name = "number",
            function_owner = self,
            label = "NMB",
            position = {0.03, 0.4, 0.73},
            scale = {0.5, 0.5, 0.5},
            width = 870,
            height = 495,
            font_size = 320,
            color = {0.4941, 0.4941, 0.4941, 1},
            tooltip = "Number to Create",
            alignment = 3,
            validation = 2,
            tab = 2
        },
        {
            -- jsonImport input                     [6]
            input_function = "none",
            function_owner = self,
            label = "JSON IMPORT",
            position = {-3, 0.4, 1.35},
            scale = {0.5, 0.5, 0.5},
            color = {0.4941, 0.4941, 0.4941, 1},
            width = 2730,
            height = 425,
            font_size = 320,
            tooltip = "Import JSON stuff",
            alignment = 2
        },
        -- {
        --     -- boss token size bossSize              [7]
        --     name = "boss_size",
        --     function_owner = self,
        --     label = "Boss Size",
        --     position = {3.48, 0.4, -1.08},
        --     scale = {0.5, 0.5, 0.5},
        --     width = 1830,
        --     height = 425,
        --     font_size = 300,
        --     color = {0.4941, 0.4941, 0.4941, 1},
        --     tooltip = "Boss Token Size",
        --     alignment = 3,
        --     value = "Boss token size",
        --     validation = 3
        -- }
    }
    local buttons = {
        {
            -- size button							[0]
            click_function = "switch_size",
            function_owner = self,
            label = "Medium",
            tooltip = "Size",
            position = {3.64, 0.4, 0.62},
            scale = {0.5, 0.5, 0.5},
            width = 1630,
            height = 425,
            font_size = 320,
            color = {0.1921, 0.4431, 0.1921, 1},
            alignment = 2
        },
        {
            -- note button							[1]
            click_function = "create_json_note",
            function_owner = self,
            label = "Make Note",
            position = {1.95, 0.4, -0.24},
            scale = {0.5, 0.5, 0.5},
            width = 1730,
            height = 425,
            font_size = 320,
            color = {0.1921, 0.4431, 0.1921, 1},
            font_color = {0.6353, 0.8902, 0.6353, 1},
            alignment = 2
        },
        {
            -- create button						[2]
            click_function = "create_npc",
            function_owner = self,
            label = "CREATE",
            position = {0.03, 0.4, 0.23},
            scale = {0.5, 0.5, 0.5},
            width = 1620,
            height = 495,
            font_size = 320,
            color = {0.2823, 0.4039, 0.7686, 1},
            font_color = {0.8, 0.8196, 0.8862, 1},
            alignment = 2
        },
        {
            -- isBoss button						[3]
            click_function = "boss_checkbox",
            function_owner = self,
            label = "",
            position = {3.19, 0.4, -0.24},
            scale = {0.5, 0.5, 0.5},
            width = 425,
            height = 425,
            font_size = 320,
            color = {0.6196, 0.2431, 0.2431, 1},
            font_color = {0.6353, 0.8902, 0.6353, 1},
            tooltip = "false",
            alignment = 2
        },
        {
            -- allegiance button					[4]
            click_function = "switch_sides",
            function_owner = self,
            label = "Enemy",
            position = {1.88, 0.4, 0.62},
            scale = {0.5, 0.5, 0.5},
            width = 1630,
            height = 425,
            font_size = 320,
            color = _states["enemy"].color,
            alignment = 2
        },
        {
            -- name question button                      [5]
            click_function = "none",
            function_owner = self,
            label = "?",
            tooltip = "The names of monsters can be variegated, remember of these escape characters:" ..
                "\n- [FF4136]/[-] is for [b][FF4136]r[-][FF851B]a[-][FFDC00]n[-][2ECC40]d[-][0074D9]o[-][B10DC9]m[-] names[/b]" ..
                    "\n- [FF4136]%[-] is for [b]numbered creatures[/b] (only works for a set of monsters)",
            position = {-3.42, 0.4, -0.63},
            scale = {0.5, 0.5, 0.5},
            width = 290,
            height = 290,
            font_size = 270,
            color = {0.8972, 0.8915, 0.3673, 1},
            alignment = 2
        },
        {
            -- boss question button                     [6]
            click_function = "none",
            function_owner = self,
            label = "?",
            tooltip = "A boss is defined by its image, if it has one then it needs to be a boss." ..
                "To have a creature with image simply put the link to the image (hosted wherever, I suggest imgur)" ..
                    "in the [b][FF4136]description of the commander[-][/b] and click the button button to the immediate left" ..
                        "of this tutorial: \n[2ECC40]green[-] = boss\n[FF4136]red[-] = not boss",
            position = {4.25, 0.400000005960464, -0.12},
            scale = {0.5, 0.5, 0.5},
            width = 290,
            height = 290,
            font_size = 270,
            color = {0.8972, 0.8915, 0.3673, 1},
            alignment = 2
        },
        {
            -- clear button                            [7]
            click_function = "clear",
            function_owner = self,
            label = "↺",
            position = {-4, 0.400000005960464, -1.13},
            scale = {0.5, 0.5, 0.5},
            width = 490,
            height = 490,
            font_size = 470,
            color = {0.2823, 0.4039, 0.7686, 1},
            tooltip = "Clear",
            alignment = 2
        },
        {
            -- randomize button                     [8]
            click_function = "randomize",
            function_owner = self,
            label = "↝",
            position = {-3.5, 0.400000005960464, -1.13},
            scale = {0.5, 0.5, 0.5},
            width = 490,
            height = 490,
            font_size = 470,
            color = {0.2823, 0.4039, 0.7686, 1},
            tooltip = "Randomize\nPlease don't use this as an encounter builder",
            alignment = 2
        },
        {
            click_function = "parseJson",
            function_owner = self,
            label = "P",
            tooltip = "Parse JSON",
            -- position = {4.13, 0.400000005960464, 1.12},
            position = {-1.5, 0.400000005960464, 1.35},
            scale = {0.5, 0.5, 0.5},
            width = 640,
            height = 460,
            font_size = 270,
            color = {0.4941, 0.4941, 0.4941, 1},
            alignment = 2
        }
    }

    for i = 1, #inputs do

        if inputs[i].name then
            local funcName = "input_" .. inputs[i].name
            local func = function(_, _, value, stillEditing)
                manageInput(inputs[i].name, value)
            end
            self.setVar(funcName, func)
            inputs[i].input_function = funcName
        end

        self.createInput(inputs[i])
    end
    for i = 1, #buttons do
        self.createButton(buttons[i])
    end
end

function none() end

function manageInput(input_name, value)
    local possibleNames = {
        "name",
        "hp",
        "stress",
        "difficulty",
        "image",
        "number",
        "side"
    }

    if not utils.searchInArray(possibleNames, input_name) then
        return
    end

    utils.appendData(self, {
            [input_name] = value
    }, "exportData")
end

function clear()
    for i = 1, #self.getInputs() do
        self.editInput({index = i - 1, value = ""})
    end
end

function randomize()
    -- name input							[0]
    -- initiative input						[1]
    -- hp input								[2]
    -- ac input								[3]
    -- movement input						[4]
    -- numberToCreate input					[5]
    self.editInput({index = 0, value = "/"})
    self.editInput({index = 1, value = math.random(-2, 5)})
    self.editInput({index = 2, value = "r" .. math.random(1, 50) .. "-" .. math.random(51, 175)})
    self.editInput({index = 3, value = math.random(8, 17)})
    self.editInput({index = 4, value = math.random(1, 5) .. "0 ft"})
    self.editInput({index = 5, value = math.random(1, 9)})
end

-- name functions ---------------------------------------
function getName(number, literal)
    local inputs = self.getInputs()[1]
    local name = inputs.value
    if literal then
        return name
    end

    name = name:gsub("/", random_names[math.random(1, #random_names)])
    if number then
        name = name:gsub("%%", number)
    end
    return name
end

function setName(params)
    if params == nil or params.input == "" then return end
    self.editInput({index = 0, value = params.input})
    utils.appendData(self, {name = params.input}, "exportData")
end

-- hp ------------------------------------------------
function getHP(literal)
    local hp = self.getInputs()[3].value
    if literal then
        return hp
    end

    if string.sub(hp, 1, 1) == "r" then
        hp = string.gsub(hp, "r", "")
        local range = mysplit(hp, "-")
        hp = math.random(range[1], range[2])
    end

    return tonumber(hp)
end
function setHP(params)
    if params == nil or params.input == "" then return end
    self.editInput({index = 1, value = params.input})
    utils.appendData(self, {hp = params.input}, "exportData")
end

-- ac ------------------------------------------------
function getDiff()
    local input = self.getInputs()[4].value
    return input
end
function setDiff(params)
    if params == nil or params.input == "" then return end
    self.editInput({index = 3, value = params.input})
    utils.appendData(self, {difficulty = params.input}, "exportData")
end

-- movement ------------------------------------------
function getMovement()
    local input = self.getInputs()[5].value
    return input
end
function setMovement(params)
    if params == nil or params.input == "" then return end
    self.editInput({index = 4, value = params.input})
end

-- stress --------------------------------------------
function getStress()
    local input = self.getInputs()[3].value
    return input
end
function setStress(params)
    if params == nil or params.input == "" then return end
    self.editInput({index = 2, value = params.input})
    utils.appendData(self, {stress = params.input}, "exportData")
end

-- size ----------------------------------------------
function getSize(get_scale)
    local buttons = self.getButtons()[1]
    if not get_scale then
        return buttons.label
    end

    local scale = {}
    scale["Small"] = 0.53
    scale["Medium"] = 0.78
    scale["Large"] = 1.45
    scale["Huge"] = 2.40
    scale["Gargantuan"] = 3.30
    return scale[buttons.label]

    -- if not getBossCheckbox() then
    --     local scale = {}
    --     scale["Small"] = 0.17
    --     scale["Medium"] = 0.30
    --     scale["Large"] = 0.55
    --     scale["Huge"] = 0.90
    --     scale["Gargantuan"] = 1.20
    --     return scale[buttons.label]
    -- else
    --     local scale = {}
    --     scale["Small"] = 0.53
    --     scale["Medium"] = 0.78
    --     scale["Large"] = 1.45
    --     scale["Huge"] = 2.40
    --     scale["Gargantuan"] = 3.30
    --     return scale[buttons.label]
    -- end
    
end

function switch_size(obj, player_clicker_color, alt_click)
    local sizes = {}
    sizes[1] = "Small"
    sizes[2] = "Medium"
    sizes[3] = "Large"
    sizes[4] = "Huge"
    sizes[5] = "Gargantuan"

    local currentSize = getSize()
    local c = 1
    for i = 1, #sizes do
        if sizes[i] == currentSize then
            c = alt_click and i - 1 or i + 1
        end
    end
    if c > #sizes then
        c = 1
    elseif c <= 0 then
        c = #sizes
    end
    self.editButton(
        {
            index = 0,
            label = sizes[c]
        }
    )

    utils.appendData(self, {size = sizes[c]}, "exportData")
end

function setSize(params)
    if params == nil or params.input == "" then return end
    self.editButton({index = 0, label = params.input})
    utils.appendData(self, {size = params.input}, "exportData")
end

-- boss checkbox -------------------------------------
function boss_checkbox()
    local btn = self.getButtons()[4]
    local isBoss = btn.tooltip == "true"
    local color = {
        red = {0.6196, 0.2431, 0.2431, 1},
        green = {0.1921, 0.4431, 0.1921, 1}
    }
    if not isBoss then
        self.editButton({index = 3, color = color.green})
        self.editButton({index = 3, tooltip = "true"})
    else
        self.editButton({index = 3, color = color.red})
        self.editButton({index = 3, tooltip = "false"})
    end

    utils.appendData(self, {
        boss = not isBoss
    }, "exportData")
end

function getBossCheckbox()
    local btn = self.getButtons()[4]
    return btn.tooltip == "true"
end

function toggleIsBoss(params)
    local btn = self.getButtons()[4]
    local color = {
        red = {0.6196, 0.2431, 0.2431, 1},
        green = {0.1921, 0.4431, 0.1921, 1}
    }

    if params.input then
        self.editButton({index = 3, color = color.green})
        self.editButton({index = 3, tooltip = "true"})
    else
        self.editButton({index = 3, color = color.red})
        self.editButton({index = 3, tooltip = "false"})
    end

    utils.appendData(self, { boss = params.input }, "exportData")
end

-- side ----------------------------------------------
function switch_sides()
    if _side == "enemy" then
        _side = "ally"
    elseif _side == "ally" then
        _side = "neutral"
    elseif _side == "neutral" then
        _side = "enemy"
    end
    self.editButton({index = 4, color = _states[_side].color})
    self.editButton({index = 4, label = _side:gsub("^%l", string.upper)})

    utils.appendData(self, {side = _side}, "exportData")
end

function setSide(params)
    if params == nil or params.input == "" then return end
    local side = string.lower(params.input)

    _side = side
    self.editButton({index = 4, color = _states[_side].color})
    self.editButton({index = 4, label = _side:gsub("^%l", string.upper)})

    utils.appendData(self, {side = _side}, "exportData")
end

-- numberToCreate -------------------------------------
function setNumberToCreate(params)
    self.editInput({index = 5, value = params.input})
    utils.appendData(self, { number = params.input }, "exportData")
end

function getNumberToCreate()
    local input = self.getInputs()[6]
    if input.value == "" then
        return 1
    else
        return tonumber(input.value)
    end
end

-- Image ----------------------------------------------
function getImage()
    local input = self.getInputs()[5]
    return input.value
end

function setImage(image)
    self.editInput({index = 4, value = image})
    utils.appendData(self, {image = image}, "exportData")
end

-- jsonImport ----------------------------------------
function getJsonImport()
    local input = self.getInputs()[7]
    return input.value
end


function parseJson(params)
    local json = getJsonImport()
    parseData({input = json})
end

function parseData(params)
    local data = JSON.decode(params.input)
    setName({input = data.name})
    -- setINI(({input = data.ini}))
    setHP(({input = data.hp}))
    setStress(({input = data.stress}))
    setDiff(({input = data.difficulty}))
    setSize({input = data.size})
    setSide({input = data.side})
    setNumberToCreate({input = data.number or 1})
    if data.image and data.image ~= "" then
        toggleIsBoss({input = true})
        setImage(data.image)
    else
        toggleIsBoss({input = false})
    end
end

function lockInputs(toggle)
    for i = 1, #self.getButtons() do
        self.editButton({index = i - 1, enabled = toggle})
    end

    for i = 1, #self.getInputs() do
        self.editInput({index = i - 1, enabled = toggle})
    end
end

--- @param args MonsterData
function ParseMonsterData(args) 
    _debug("Event " .. events.EVENT_NAMES.parse_monster_data .. " triggered", "ParseMonsterData")

    local json = args[1]
    parseData({input = json})
end

function create_json_note(obj, player_clicker_color, alt_click)
    local data = utils.getData(self).exportData
    local vars = {
        name = data.name,
        -- ini = getInitiative(),
        hp = data.hp,
        stress = data.stress,
        difficulty = data.difficulty,
        size = data.size or "Medium",
        image = data.image or nil,
        side = data.side or "Enemy",
        number = data.number
    }
    local json = JSON.encode(vars)
    events.broadcast(events.EVENT_NAMES.create_json_note, json)
end

function createNote(args)
    local json = args[1]
    local data = JSON.decode(json)

    log(getBossCheckbox())
    log(data.boss)
    log(data.image)

    if not getBossCheckbox() then
        data.boss = false
        data.image = nil
        log("no boss")
        log(data)
    end

    if data.image == "" then
        data.image = nil
    end

    
    local obj = utils.useFromBag(self, function(spawned_object)
        local name = utils.findBlackName(data.name)
        if name == nil then
            name = data.name
        end
        spawned_object.setName(name)
        spawned_object.setDescription(JSON.encode(data))
        spawned_object.setColorTint(_states[_side].bright)
    end, nil, OBJECT_TAGS.clever_notecard, "saveCardData")
    promise.WaitUntilResting(obj, function()
        obj.call("setData", {})
    end)
end

function create_npc(obj, player_clicker_color, alt_click)
    -- local data = utils.getData(self).exportData

    -- local creation_params
    -- if data.boss then
    --     creation_params = {
    --         object_tag = OBJECT_TAGS.boss_token,
    --         is_boss = true
    --     }
    -- else
    --     creation_params = {
    --         object_tag = OBJECT_TAGS.monster_token,
    --         is_boss = false
    --     }
    -- end
    create_thing()
end

function create_thing()
    startLuaCoroutine(self, "creation_coroutine")
end

-- Module-level tables to hold the shuffled, available names
local available_random_names = {}
local available_paired_names = {}

---
-- Shuffles a table in-place using the Fisher-Yates algorithm.
-- @param tbl The table to be shuffled.
--
local function shuffle(tbl)
    for i = #tbl, 2, -1 do
        local j = math.random(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
end

---
-- Initializes the name pools by creating and shuffling copies of the master name lists.
--
local function initialize_name_pools()
    available_random_names = {}
    for _, name in ipairs(random_names) do
        table.insert(available_random_names, name)
    end
    shuffle(available_random_names)

    available_paired_names = {}
    for _, pair in ipairs(paired_names) do
        table.insert(available_paired_names, pair)
    end
    shuffle(available_paired_names)
end

    
function creation_coroutine()
    local data = utils.getData(self).exportData
    local numberToCreate = tonumber(data.number) or 1
    local object_tag = data.boss and OBJECT_TAGS.boss_token or OBJECT_TAGS.monster_token
    
    math.randomseed(os.time() + os.clock())
    initialize_name_pools()

    local pending_pair_name = nil
    
    -- Chance Logic
    local pair_chance = 0.10
    if numberToCreate == 2 then pair_chance = 0.9 end

    -- SPACING SETTINGS --
    local tokenScale = getSize(true) 
    local spawnRadius = 6 
    local minDistance = tokenScale * 1.5 
    
    -- We store OFFSETS here (e.g. {x=2, y=0, z=1}), not absolute world positions
    local assignedOffsets = {} 

    for i = 1, numberToCreate do
        
        -- CALCULATE OFFSET --
        local finalOffset = {x=0, y=0, z=0} -- Default to exact center if logic fails
        local attempts = 0
        local foundSpot = false

        while not foundSpot and attempts < 50 do
            attempts = attempts + 1
            
            -- Random Math
            local angle = math.random() * 2 * math.pi
            local dist = math.sqrt(math.random()) * spawnRadius 

            local candidateOffset = {
                x = math.cos(angle) * dist,
                y = 0, -- Keep y at 0, the Utils function handles the base height
                z = math.sin(angle) * dist
            }

            -- Check for overlap against previous offsets in this batch
            local clash = false
            for _, prevOffset in ipairs(assignedOffsets) do
                local dx = candidateOffset.x - prevOffset.x
                local dz = candidateOffset.z - prevOffset.z
                local distSq = (dx*dx) + (dz*dz)
                
                if distSq < (minDistance * minDistance) then
                    clash = true
                    break
                end
            end

            if not clash then
                finalOffset = candidateOffset
                foundSpot = true
                table.insert(assignedOffsets, finalOffset)
            end
        end

        utils.useFromBag(self, function(spawned_object)
            local image = data.image
            local instanceData = {}
            for k, v in pairs(data) do instanceData[k] = v end
            
            local final_name
            final_name, pending_pair_name = generate_name(data.name, i, numberToCreate, pair_chance, pending_pair_name)
            instanceData.name = final_name

            local init_params = {
                data = instanceData,
                image = (data.boss and data.image) and data.image or nil
            }

            local size = getSize(true)
            spawned_object.setScale({size, size, size})
            spawned_object.setColorTint(_states[_side].color)
            spawned_object.call("_init", init_params)

        -- ARGS: bag_cb, tag, spawn_table, RANDOM_OFFSET (We pass our Vector here)
        end, nil, object_tag, "monsterSpawnData", finalOffset) 
        
        coroutine.yield(0)
    end

    return 1
end

function generate_name(name_template, current_index, total_to_create, pair_chance, pending_pair_name)
    local random_name
    local new_pending_pair_name = nil
    
    if pending_pair_name then
        -- A pending name from a pair must be used.
        random_name = pending_pair_name
        -- pending_pair_name is consumed, so we return nil for it
    else
        -- Decide whether to start a new pair or use a regular name.
        -- Conditions to use a pair:
        -- 1. There is room for the second part (current_index < total_to_create).
        -- 2. There are paired names available.
        local can_use_pair = (current_index < total_to_create) and (#available_paired_names > 0)
        
        -- Check against the determined chance.
        if can_use_pair and (math.random() < pair_chance) then
            -- Pull a new pair from the shuffled pool.
            local pair = table.remove(available_paired_names)
            random_name = pair[1]
            new_pending_pair_name = pair[2] -- Set the pending name for the next iteration.
        else
            -- Use a regular random name.
            random_name = table.remove(available_random_names) or "Nameless" -- Fallback
        end
    end
    
    -- Apply the template transformations
    local final_name = name_template
    -- Replace / with the random name
    final_name = final_name:gsub("/", random_name)
    -- Replace % with the current index
    final_name = final_name:gsub("%%", tostring(current_index))
    
    return final_name, new_pending_pair_name
end



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
__bundle_register("src.data.random_names", function(require, _LOADED, __bundle_register, __bundle_modules)
-- Paired names that should appear together
paired_names = {
    {"Mr. Piss", "Mr. Stachio"}, {"Stan", "Still"},
    {"Earl", "Lee Bird"}, {"Ward", "Robe"}, {"Doug", "Hole"},
    {"Ollie", "Garchy"}, {"Barry", "Cade"}, {"Is", "Is Not"},
    {"Moe", "Lester"}, {"Justin", "Case"}, {"Flash", "Bang"},
    {"Lock", "Key"}, {"Hammer", "Anvil"}, {"Click", "Clack"},
    {"Salt", "Pepper"}, {"Ben", "Dover"}, {"Dee", "Nied"},
    {"Sal", "Amander"}, {"Sword", "Shield"}, {"Chris", "P. Bacon"},
    {"Truth", "Dare"}, {"Don", "Key"}, {"Ella", "Vator"}, {"Gene", "Pool"},
    {"Pete", "Repeat"}
}

-- Regular random names
random_names = {
    "Kyle", "Preston", "Pedro", "Jean", "Willis", "Eric", "Alan",
    "Jeremiah", "Troy", "Warner", "Guadalupe", "Emanuel", "Parker",
    "Willie", "Mauricio", "Tommie", "Buck", "Marlon", "Deshawn",
    "Fritz", "Sam", "Chung", "Chungus", "Jim", "Whitney", "Barton",
    "Alec", "Antione", "Micah", "Rhett", "Clint", "Raphael",
    "Sammy", "Dale", "Pat", "Lazarus", "Milton", "Vaughn",
    "Walton", "Lorenzo", "Robby", "Stanley", "Marvin", "Arnold",
    "Chester", "Wilmer", "Zane", "Cornelius", "Ivan", "Javier",
    "Jesse", "Rhea", "Karla", "Maybelle", "Salley", "Temple",
    "Ronna", "Lilli", "Stella", "Lorine", "Denna", "Bernice",
    "Lorina", "Rhona", "Kasie", "Earline", "Felisha", "Jeni",
    "Stormy", "Akiko", "Beverlee", "Chia", "Ethelene", "Lakisha",
    "Hsiu", "Dawna", "Demetra", "Junita", "June", "Lyndia",
    "Otelia", "Joanie", "Jenell", "Johana", "Corina", "Hannelore",
    "Deandra", "Florida", "Matilde", "Maragret", "Luana", "Neva",
    "Rachal", "Rona", "Shirl", "Maudie", "Rosalyn", "Rosaura",
    "Jesusita", "Adela", "Lashon"
}
end)
return __bundle_require("__root")