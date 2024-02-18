------------------- CONSTANTS -------------------

DIRECTION_NAMES = { "South", "North", "East", "West", "Southeast", "Southwest", "Northeast", "Northwest" }
WS_TIMEOUT = 5
DIALOG_NAME = "DMI Editor"
TEMP_NAME = "aseprite-dmi"
LUA_LIB = app.fs.pathSeparator == "\\" and "lua54" or "liblua54"
DMI_LIB = "dmi"
TEMP_DIR = app.fs.joinPath(app.fs.tempPath, TEMP_NAME)
