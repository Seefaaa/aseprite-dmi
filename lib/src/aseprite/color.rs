use mlua::{chunk, AnyUserData, Function, Lua, Result, Table};

#[derive(Debug)]
pub struct Color<'lua>(&'lua Lua, pub AnyUserData<'lua>);

impl<'lua> Color<'lua> {
    pub fn _from_rgba(lua: &'lua Lua, r: u8, g: u8, b: u8, a: u8) -> Result<Self> {
        let constructor = lua.globals().get::<_, Function>("Color")?;
        let args = lua.create_table()?;
        args.raw_set("r", r)?;
        args.raw_set("g", g)?;
        args.raw_set("b", b)?;
        args.raw_set("a", a)?;
        let color = constructor.call(args)?;
        Ok(Self(lua, color))
    }
    pub fn from_theme(lua: &'lua Lua, color: &str) -> Result<Self> {
        let app = lua.globals().get::<_, Table>("app")?;
        let theme = app.get::<_, AnyUserData>("theme")?;
        let color = lua
            .load(chunk! {
                    local theme = $theme
                    return theme.color[$color]
            })
            .eval()?;
        Ok(Self(lua, color))
    }
    pub fn rgba(&self) -> Result<(u8, u8, u8, u8)> {
        let color = &self.1;
        let (r, g, b, a) = self
            .0
            .load(chunk! {
                    local color = $color
                    return color.red, color.green, color.blue, color.alpha
            })
            .eval()?;
        Ok((r, g, b, a))
    }
}
