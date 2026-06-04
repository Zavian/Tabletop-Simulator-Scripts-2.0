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
        local table = Tables.getTable()

        print("Table loading complete")

        if table ~= "Table_RPG" then return end
        local newBoss = utils.getObjectByTag(OBJECT_TAGS.boss_token)
        utils.swapObjectInBagByTag(COMPONENTS.npc_commander, OBJECT_TAGS.boss_token, newBoss)

        local newMonster = utils.getObjectByTag(OBJECT_TAGS.monster_token)
        utils.swapObjectInBagByTag(COMPONENTS.npc_commander, OBJECT_TAGS.monster_token, newMonster)

        local newNote = utils.getObjectByTag(OBJECT_TAGS.clever_notecard)
        utils.swapObjectInBagByTag(COMPONENTS.npc_commander, OBJECT_TAGS.clever_notecard, newNote)
    end)

    if saved_data then SAVED_DATA = JSON.decode(saved_data) end
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
end

function onObjectDrop(player_color, drop_obj)
    drop_obj.setVar("last_held_by", player_color)
    _debug("Object with guid " .. drop_obj.guid .. " has variable last_held_by set to " .. player_color)

    if drop_obj.hasTag(OBJECT_TAGS.movement_measurement) then
        movement_measurement.onDrop(drop_obj)
    end
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

function onSave()
    local saved_data = JSON.encode(SAVED_DATA)
    self.script_state = saved_data
    return self.script_state
end
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