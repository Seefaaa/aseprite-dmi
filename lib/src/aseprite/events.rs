use mlua::{FromLua, Lua, Result, Value};

use super::MouseButton;

#[derive(Debug)]
pub struct MouseEvent {
    pub x: u32,
    pub y: u32,
    pub button: MouseButton,
}

impl<'lua> FromLua<'lua> for MouseEvent {
    fn from_lua(value: Value<'lua>, _: &'lua Lua) -> Result<Self> {
        match value {
            Value::Table(table) => {
                let x = table.get("x").unwrap_or(0);
                let y = table.get("y").unwrap_or(0);

                let button = match table.get::<_, MouseButton>("button") {
                    Ok(button) => button,
                    Err(_) => MouseButton::None,
                };

                Ok(MouseEvent { x, y, button })
            }
            _ => unreachable!("Invalid mouse event"),
        }
    }
}
