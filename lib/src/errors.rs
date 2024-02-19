use mlua::ExternalError as _;

pub enum ExternalError {
    Arboard(arboard::Error),
    Serde(serde_json::Error),
}

impl mlua::ExternalError for ExternalError {
    fn into_lua_err(self) -> mlua::Error {
        match self {
            Self::Arboard(err) => err.into_lua_err(),
            Self::Serde(err) => err.into_lua_err(),
        }
    }
}

impl From<ExternalError> for mlua::Error {
    fn from(error: ExternalError) -> Self {
        error.into_lua_err()
    }
}

impl From<crate::dmi::DmiError> for mlua::Error {
    fn from(error: crate::dmi::DmiError) -> Self {
        error.into_lua_err()
    }
}
