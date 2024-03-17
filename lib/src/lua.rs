use mlua::{Lua, Result};

use crate::macros::create_safe_function;
use crate::userdata::Dmi;

#[mlua::lua_module(name = "dmi_module")]
fn module(lua: &Lua) -> Result<bool> {
    let module = lua.create_table()?;
    module.set("open", create_safe_function!(lua, Dmi::open)?)?;
    module.set("remove_file", create_safe_function!(lua, remove_file)?)?;

    lua.globals().set("libdmi", module)?;

    // lua.globals().set("Dmi", create_safe_function!(lua, Dmi::open)?)?;

    Ok(true)
}

fn remove_file(_: &Lua, path: String) -> Result<bool> {
    std::fs::remove_file(path)?;
    Ok(true)
}
