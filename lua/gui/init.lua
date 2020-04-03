--[[
This module handles the creation of GUIs, by managing a tree of GUI elements.
A GUI element can have many sub-elements, which are drawn relative to its
parent element.
]]
-- TODO: seperate modules for GUI in seperate files
-- TODO: Check: all arguments used at runtime
-- TODO: Check: never use upvalues for element properties(always use self.w, self.h, etc.)
-- TODO: Check: naming of callback arguments(surface, ox, oy, ...)
-- TODO: button text(update) use align_in_parent
-- TODO: horizontal_group/vertical_group autosize
-- TODO: resizeable windows
-- TODO: unified resize functions
-- TODO: graph element
-- TODO: Icons in buttons, contextmenu
-- TODO: grid group
-- TODO: Window
-- TODO: Text element alignment and autosize
-- TODO: optional responsive(declerative) item sizing/alignment
-- TODO: Text input
-- TODO: Multiline text, rich text(markdown?)
--luacheck: no max line length

local gui = {}

gui.style = {}


-- used in modules to append to global default styles
function gui:append_style(element_type, style)
	for k,v in pairs(style) do
		local global_key = element_type .. "_" .. k
		assert(not self.style[global_key])
		self.style[global_key] = v
	end
end

-- Load all gui modules
-- (Each module registers functions in the gui table, and appends the
-- default style to the gui.style table using the :append_style function)

-- basic GUI element(required for all other elements)
require("lua-db.gui.element")(gui)

-- alignment group element
require("lua-db.gui.align_group")(gui)

-- text element (using a bmpfont)
require("lua-db.gui.text_bmpfont")(gui)

-- button and togglebutton elements
require("lua-db.gui.button")(gui)

-- draggable element(required for slider and scroll container element)
require("lua-db.gui.draggable")(gui)

-- slider elements
require("lua-db.gui.slider")(gui)

-- scroll container element
require("lua-db.gui.scroll_container")(gui)

-- context menu element
require("lua-db.gui.context_menu")(gui)


return gui
