use mlua::ExternalError as _;
use thiserror::Error;

use crate::userdata::DmiError;

#[derive(Error, Debug)]
#[error(transparent)]
pub enum ExternalError {
    Arboard(#[from] arboard::Error),
    Dmi(#[from] DmiError),
    Image(#[from] image::ImageError),
    Io(#[from] std::io::Error),
    ParseFloat(#[from] std::num::ParseFloatError),
    ParseInt(#[from] std::num::ParseIntError),
    PngDecoding(#[from] png::DecodingError),
}

impl From<ExternalError> for mlua::Error {
    fn from(error: ExternalError) -> Self {
        error.into_lua_err()
    }
}

impl From<DmiError> for mlua::Error {
    fn from(error: DmiError) -> Self {
        error.into_lua_err()
    }
}
