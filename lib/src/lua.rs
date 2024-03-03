use mlua::{Lua, Nil, Result, Table, Value};

use crate::userdata::Editor;

#[mlua::lua_module(name = "dmi_module")]
fn module(lua: &'static Lua) -> Result<Value> {
    let module = lua.create_table()?;
    module.set("hello", lua.create_function(|_, ()| Ok("world"))?)?;

    lua.globals().set("libdmi", module)?;
    lua.globals().set("Editor", editor(lua)?)?;

    Ok(Nil)
}

fn editor(lua: &'static Lua) -> Result<Table> {
    let table = lua.create_table()?;

    let open = |lua, filename: String| Editor::open(lua, filename);
    table.set("open", lua.create_function(open)?)?;

    Ok(table)
}
