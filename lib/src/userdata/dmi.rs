use mlua::{AnyUserData, Lua, Result, Table, UserData, UserDataFields};

use super::RefHolder;

pub struct Dmi<'lua> {
    pub name: String,
    pub width: u32,
    pub height: u32,
    pub states: RefHolder<'lua>,
}

impl<'a: 'static> Dmi<'a> {
    pub fn open(lua: &'a Lua, name: String) -> Result<AnyUserData<'a>> {
        let dmi = Self {
            name,
            width: 32,
            height: 32,
            states: RefHolder::new(lua)?,
        };

        dmi.states.set(lua.create_table()?)?;

        lua.create_userdata(dmi)
    }
}

impl<'a: 'static> UserData for Dmi<'a> {
    fn add_fields<'lua, F: UserDataFields<'lua, Self>>(fields: &mut F) {
        fields.add_field_method_get("name", |_, this| Ok(this.name.clone()));
        fields.add_field_method_get("width", |_, this| Ok(this.width));
        fields.add_field_method_get("height", |_, this| Ok(this.height));
        fields.add_field_method_get("states", |_, this| this.states.get::<Table<'a>>());
    }
}
