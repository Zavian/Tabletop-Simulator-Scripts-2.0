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
-- Mirror Pin
--
-- Object script for a board mirror master pin. Drop the object on a board, then
-- right-click it for "Spawn slave". All the logic lives
-- in Global (src/core/board_mirror.lua); this only tags the object and tells
-- Global about it.

require("src.data.config")

function onLoad()
    self.addTag(OBJECT_TAGS.board_mirror_master)
    Global.call("boardMirror_registerMaster", { guid = self.getGUID() })
end

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
    flying = "flying",
    player = "player_token",
    board_mirror_master = "board_mirror_master",
    board_mirror_slave = "board_mirror_slave",
    board_mirror_ghost = "board_mirror_ghost"
}

SAVED_DATA = {
    PLAYER = {
        ["Black"] = {
            autoSnap = false
        },
    }
}
end)
return __bundle_require("__root")