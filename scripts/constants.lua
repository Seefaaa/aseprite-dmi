------------------- CONSTANTS -------------------

DIRECTION_NAMES = { "South", "North", "East", "West", "Southeast", "Southwest", "Northeast", "Northwest" }
DIALOG_NAME = "DMI Editor"
TEMP_NAME = "aseprite-dmi"
LUA_LIB = app.fs.pathSeparator ~= "/" and "lua54" or nil
DMI_LIB = app.fs.pathSeparator ~= "/" and "dmi" or "libdmi"
TEMP_DIR = app.fs.joinPath(app.fs.tempPath, TEMP_NAME)

COMMON_STATE = {
	normal = { part = "sunken_normal", color = "button_normal_text" },
	hot = { part = "sunken_focused", color = "button_hot_text" },
} --[[@as WidgetState]]
