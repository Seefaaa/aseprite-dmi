use mlua::prelude::*;

pub fn safe_lua_function<'lua, A, R, F>(
    lua: &'lua Lua,
    func: F,
    multi: A,
) -> LuaResult<(Option<R>, Option<String>)>
where
    A: FromLuaMulti<'lua>,
    R: IntoLuaMulti<'lua>,
    F: Fn(&'lua Lua, A) -> LuaResult<R>,
{
    match func(lua, multi) {
        Ok(r) => Ok((Some(r), None)),
        Err(err) => Ok((None, Some(err.to_string()))),
    }
}

macro_rules! safe {
    ($func:ident) => {
        |lua, args| $crate::macros::safe_lua_function(lua, $func, args)
    };
}

pub(crate) use safe;
