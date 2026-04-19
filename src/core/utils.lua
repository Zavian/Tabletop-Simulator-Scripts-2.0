
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