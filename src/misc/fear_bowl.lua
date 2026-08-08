--Counting Bowl    by MrStump

--Table of items which can be counted in this Bowl
--Each entry has 2 things to enter
    --a name (what is in the name field of that object)
    --a value (how much it is worth)
--A number in the items description will override the number entry in this table
validCountItemList = {
    ["Fear"] = 1,
    --["Name2"] = 5,
    --["Name3"] = 2,
    --["Name4"] = 31,
    --Add more entries as needed
    --Remove the -- from before a line for the script to use it
}

local labelPos = "0 0.04 -2.5"
local labelRot = "0 180 0"

--END OF CODE TO EDIT

function onLoad()
    loadSave()

    timerID = self.getGUID()..math.random(9999999999999)
    --Sets position/color for the button, spawns it
    self.createButton({
        label="", click_function="none", function_owner=self,
        position=createVector(labelPos), rotation=createVector(labelRot), height=00, width=0,
        font_color={1,1,1}, font_size=500
    })

    self.createButton({
        label="+", click_function="add", function_owner=self,
        position={2.2,0.3,-0.3}, rotation={0,0,0}, height=400, width=400,
        font_size=400
    })

    self.createButton({
        label="-", click_function="remove", function_owner=self,
        position={2.2,0.3,0.7}, rotation={0,0,0}, height=400, width=400,
        font_size=400
    })

    --Start timer which repeats forever, running countItems() every second
    Timer.create({
        identifier=timerID,
        function_name="countItems", function_owner=self,
        repetitions=0, delay=1
    })

    self.addContextMenuItem("Set Label Pos", function()
        Player["Black"].showInputDialog("Set Label Pos", labelPos,
            function (text, player_color)
                if not isValidVector(text) then
                    print("Invalid Vector")
                    return
                end
                labelPos = text
                self.editButton({index=0, position=createVector(text)})
                updateGMNote()
            end
        )
    end)

    self.addContextMenuItem("Set Label Rot", function()
        Player["Black"].showInputDialog("Set Label Rot", labelRot,
            function (text, player_color)
                if not isValidVector(text) then
                    print("Invalid Vector")
                    return
                end
                labelRot = text
                self.editButton({index=0, rotation=createVector(text)})
                updateGMNote()
            end
        )
    end)

    
end

function add(_, player_color)
    if player_color ~= "Black" then return end
    local gm_note = self.getGMNotes()
    if gm_note == "" then print("No GM Notes") return end
    local data = JSON.decode(gm_note)
    
    if not data.add_bag then print("No add_bag in GM Notes") return end
    local bag = getObjectFromGUID(data.add_bag)
    if not bag then print("No bag found with that GUID") return end

    local pos = self.getPosition() + Vector(math.random(0.5, 1.5), math.random(3.5,4.5), math.random(0.5, 1.5))
    bag.takeObject({position = pos})
end

function remove(_, player_color)
    if player_color ~= "Black" then return end
    local gm_note = self.getGMNotes()
    if gm_note == "" then print("No GM Notes") return end
    local data = JSON.decode(gm_note)
    
    if not data.remove_bag then print("No remove_bag in GM Notes") return end
    local bag = getObjectFromGUID(data.remove_bag)
    if not bag then print("No bag found with that GUID") return end

    local pos = bag.getPosition() + Vector(0, 4, 0)

    local objs_in_bowl = findItemsInSphere()
    for _, entry in ipairs(objs_in_bowl) do
        if entry.hit_object ~= self then
            local tableEntry = validCountItemList[entry.hit_object.getName()]
            if tableEntry ~= nil then
                entry.hit_object.setPositionSmooth(pos, false)
                entry.hit_object.setRotationSmooth({0,45,0}, false)
                return
            end
        end
    end
end

function loadSave()
    local json = self.getGMNotes()
    if json ~= "" then
        local data = JSON.decode(json)
        labelPos = data.labelPos
        labelRot = data.labelRot
        -- self.editButton({index=0, position=createVector(labelPos), rotation=createVector(labelRot)})
    end
end

function updateGMNote()
    local json = {
        labelPos = labelPos,
        labelRot = labelRot
    }
    self.setGMNotes(JSON.encode(json))
end

function isValidVector(str)
    local x = str:sub(1, str:find(" ")-1)
    local y = str:sub(str:find(" ")+1, str:find(" ", str:find(" ")+1)-1)
    local z = str:sub(str:find(" ", str:find(" ")+1)+1)
    return x ~= "" and y ~= "" and z ~= ""
end

function createVector(str)
    return { 
        tonumber(str:sub(1, str:find(" ")-1)), 
        tonumber(str:sub(str:find(" ")+1, str:find(" ", str:find(" ")+1)-1)), 
        tonumber(str:sub(str:find(" ", str:find(" ")+1)+1))
    }
end

--Activated once per second, counts items in bowls
function countItems()
    local totalValue = 0
    local itemsInBowl = findItemsInSphere()
    --Go through all items found by the cast
    for _, entry in ipairs(itemsInBowl) do
        --Ignore the bowl
        if entry.hit_object ~= self then
            local tableEntry = validCountItemList[entry.hit_object.getName()]
            --Ignore if not in validCountItemList
            if tableEntry ~= nil then
                local descValue = tonumber(entry.hit_object.getDescription())
                local stackMult = math.abs(entry.hit_object.getQuantity())
                --Use value in description if available
                if descValue ~= nil then
                    totalValue = totalValue + descValue * stackMult
                else
                    --Otherwise use the value in validCountItemList
                    totalValue = totalValue + tableEntry * stackMult
                end
            end
        end
    end
    --Updates the number display
    self.editButton({index=0, label=totalValue})
    self.setName("[F21D1D]Fear[-]: "..totalValue)
end

--Gets the items in the bowl for countItems to count
function findItemsInSphere()
    --Find scaling factor
    local scale = self.getScale()
    --Set position for the sphere
    local pos = self.getPosition()
    pos.y=pos.y+(1.25*scale.y)
    --Ray trace to get all objects
    return Physics.cast({
        origin=pos, direction={0,1,0}, type=2, max_distance=0,
        size={3.4*scale.x,3.4*scale.y,3.4*scale.z}, --debug=true
    })
end

function onDestroy()
    Timer.destroy(timerID)
end