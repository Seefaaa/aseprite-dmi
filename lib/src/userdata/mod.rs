use mlua::{AnyUserData, FromLua, IntoLua, Lua, Result, UserData};

mod dmi;
mod editor;

pub use dmi::Dmi;
pub use editor::Editor;

struct EmptyUserData;

impl UserData for EmptyUserData {}

pub struct RefHolder<'lua>(AnyUserData<'lua>);

impl<'lua> RefHolder<'lua> {
    pub fn new(lua: &Lua) -> Result<RefHolder> {
        Ok(RefHolder(lua.create_userdata(EmptyUserData)?))
    }
    pub fn set<V>(&self, value: V) -> Result<()>
    where
        V: IntoLua<'lua>,
    {
        self.0.set_user_value(value)
    }
    pub fn get<V>(&self) -> Result<V>
    where
        V: FromLua<'lua>,
    {
        self.0.user_value()
    }
}

impl UserData for RefHolder<'_> {}
