use mlua::{Lua, Nil, Result, Value};

use crate::userdata::Editor;

#[mlua::lua_module(name = "dmi_module")]
fn module(lua: &'static Lua) -> Result<Value> {
    let module = lua.create_table()?;
    module.set("hello", lua.create_function(|_, ()| Ok("world"))?)?;

    lua.globals().set("libdmi", module)?;

    lua.globals()
        .set("Editor", lua.create_function(Editor::open)?)?;

    Ok(Nil)
}
