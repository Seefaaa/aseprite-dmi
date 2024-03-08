use mlua::{FromLuaMulti, IntoLuaMulti, Lua, MultiValue, Result as LuaResult};

macro_rules! lua_print {
		($lua:ident, $($args:expr),*) => {
			if let Ok(print) = $lua.globals().get::<_, mlua::Function>("print") {
				let _ = print.call::<_, ()>(format!($($args),*));
			}
		};
}

pub fn safe_lua_function<'lua, A, R, F>(lua: &'lua Lua, func: F, multi: A) -> LuaResult<MultiValue>
where
    A: FromLuaMulti<'lua>,
    R: IntoLuaMulti<'lua>,
    F: Fn(&'lua Lua, A) -> LuaResult<R>,
{
    match func(lua, multi) {
        Ok(r) => Ok(r.into_lua_multi(lua)?),
        Err(err) => {
            lua_print!(lua, "Error: {:?}", err);
            Ok(().into_lua_multi(lua)?)
        }
    }
}

macro_rules! safe_function {
    ($func:expr) => {
        |lua, args| $crate::macros::safe_lua_function(lua, $func, args)
    };
}

macro_rules! create_safe_function {
    ($lua:ident, $func:expr) => {
        $lua.create_function($crate::macros::safe_function!($func))
    };
}

pub(crate) use {create_safe_function, lua_print, safe_function};
