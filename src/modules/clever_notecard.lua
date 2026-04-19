
local events = require("src.core.events")
local utils = require("src.core.utils")

--[[StartXML
<Defaults>
    <Text class="title" fontSize="25" alignment="MiddleCenter" />
    <Text class="description" fontSize="14" alignment="UpperLeft" />

</Defaults>
<Text id="title" class="title" rotation="180 180 0" position="0 -110 -10" width="400" height="50">Title</Text>
<Text id="description" class="description" rotation="180 180 0" position="0 30 -10" width="400" height="220">Description</Text>
StopXML--xml]]
function onload()
    utils.setXML()
    self.setTags({OBJECT_TAGS.clever_notecard})

    setData()
    local data = {
        click_function = "parse",
        function_owner = self,
        label = "Parse",
        position = {1.92, 0.1, 1.33},
        scale = {0.3, 0.3, 0.3},
        width = 1200,
        height = 500,
        font_size = 400,
        color = {0.1341, 0.1341, 0.1341, 1},
        font_color = {1, 1, 1, 1},
        tooltip = "Parse"
    }
    self.createButton(data)
end

function onHover()
    setData()
end

function setData()
    self.UI.setAttribute("title", "text", self.getName())
    self.UI.setAttribute("description", "text", self.getDescription())
end

function parse()
    events.broadcast(events.EVENT_NAMES.parse_monster_data, self.getDescription())
end

