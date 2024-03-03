use mlua::{FromLua, Lua, Result, Value};

pub enum MouseButton {
    Left,
    Middle,
    Right,
    X1,
    X2,
    Other(u8),
}

impl<'lua> FromLua<'lua> for MouseButton {
    fn from_lua(value: Value<'lua>, _: &'lua Lua) -> Result<Self> {
        match value {
            Value::Integer(button) => match button {
                1 => Ok(MouseButton::Left),
                2 => Ok(MouseButton::Right),
                3 => Ok(MouseButton::Middle),
                4 => Ok(MouseButton::X1),
                5 => Ok(MouseButton::X2),
                _ => Ok(MouseButton::Other(button as u8)),
            },
            _ => unreachable!("Invalid mouse button"),
        }
    }
}
