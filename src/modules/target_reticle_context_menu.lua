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