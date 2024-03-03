use mlua::{FromLua, Lua, Result, Value};

use super::MouseButton;

pub struct MouseEvent {
    pub x: u32,
    pub y: u32,
    pub button: MouseButton,
}

impl<'lua> FromLua<'lua> for MouseEvent {
    fn from_lua(value: Value<'lua>, _: &'lua Lua) -> Result<Self> {
        match value {
            Value::Table(table) => {
                let x = table.get("x")?;
                let y = table.get("y")?;
                let button = table.get::<_, MouseButton>("button")?;
                Ok(MouseEvent { x, y, button })
            }
            _ => unreachable!("Invalid mouse event"),
        }
    }
}
