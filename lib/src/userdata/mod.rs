use std::marker::PhantomData;

use mlua::{AnyUserData, FromLua, IntoLua, Lua, Result, UserData};

mod dmi;
mod state;

pub use dmi::{Dmi, Error as DmiError};
pub use state::State;
struct EmptyUserData;

impl UserData for EmptyUserData {}

#[derive(Debug)]
pub struct RefHolder<'lua, V>(AnyUserData<'lua>, PhantomData<V>);

impl<'lua, V: IntoLua<'lua> + FromLua<'lua>> RefHolder<'lua, V> {
    pub fn new(lua: &'lua Lua) -> Result<RefHolder<'lua, V>> {
        Ok(RefHolder::<V>(
            lua.create_userdata(EmptyUserData)?,
            PhantomData,
        ))
    }
    pub fn set(&self, value: V) -> Result<()> {
        self.0.set_user_value(value)
    }
    pub fn get(&self) -> Result<V> {
        self.0.user_value()
    }
}

impl<V> UserData for RefHolder<'_, V> {}
