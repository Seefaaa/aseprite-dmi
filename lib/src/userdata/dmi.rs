use mlua::UserData;

pub struct Dmi {
    pub name: String,
}

impl UserData for Dmi {}
