use image::io::Reader as ImageReader;
use mlua::{AnyUserData, Lua, Result, Table, UserData, UserDataFields};
use png::Decoder;
use std::{cmp::Ordering, fs::File};
use thiserror::Error;

use crate::errors::ExternalError;

use super::{RefHolder, State};

const DMI_VERSION: &str = "4.0";

pub struct Dmi<'lua> {
    pub name: String,
    pub width: u32,
    pub height: u32,
    pub states: RefHolder<'lua>,
}

impl<'a: 'static> Dmi<'a> {
    pub fn open(lua: &'a Lua, filename: String) -> Result<AnyUserData<'a>> {
        let decoder = Decoder::new(File::open(&filename)?);
        let reader = decoder.read_info().map_err(ExternalError::PngDecoding)?;
        let chunk = reader
            .info()
            .compressed_latin1_text
            .first()
            .ok_or(Error::MissingZTXT)?;
        let metadata = chunk.get_text().map_err(ExternalError::PngDecoding)?;

        let mut dmi = Self {
            name: filename.clone(),
            width: 32,
            height: 32,
            states: RefHolder::new(lua)?,
        };

        dmi.states.set(lua.create_table()?)?;
        dmi.set_metadata(lua, metadata)?;

        let mut reader = ImageReader::open(&filename).map_err(ExternalError::Io)?;
        reader.set_format(image::ImageFormat::Png);

        let mut image = reader.decode().map_err(ExternalError::Image)?;
        let grid_width = image.width() / dmi.width;

        let mut index = 0;
        let states = dmi.states.get::<Table>()?;
        states.for_each(|_: usize, state: AnyUserData| {
            let mut state = state.borrow_mut::<State>()?;
            let frame_count = state.frame_count as usize;
            if !state.delays.is_empty() {
                let delay_count = state.delays.len();
                match delay_count.cmp(&frame_count) {
                    Ordering::Less => {
                        let last_delay = *state.delays.last().unwrap();
                        let additional_delays = vec![last_delay; frame_count - delay_count];
                        state.delays.extend(additional_delays);
                    }
                    Ordering::Greater => {
                        state.delays.truncate(frame_count);
                    }
                    _ => {}
                }
            } else if state.frame_count > 1 {
                state.delays = vec![1.; frame_count];
            }

            for _ in 0..state.frame_count {
                for _ in 0..state.dirs {
                    let image = image.crop(
                        dmi.width * (index % grid_width),
                        dmi.height * (index / grid_width),
                        dmi.width,
                        dmi.height,
                    );
                    if image.width() != dmi.width || image.height() != dmi.height {
                        return Err(Error::SizeMismatch)?;
                    }
                    state.frames.push(image);
                    index += 1;
                }
            }

            Ok(())
        })?;

        lua.create_userdata(dmi)
    }
    fn set_metadata(&mut self, lua: &Lua, metadata: String) -> Result<()> {
        let mut lines = metadata.lines();

        if lines.next().ok_or(Error::MissingHeader)? != "# BEGIN DMI" {
            return Err(Error::MissingHeader)?;
        }

        if lines.next().ok_or(Error::InvalidVersion)? != format!("version = {}", DMI_VERSION) {
            return Err(Error::InvalidVersion)?;
        }

        let mut states = Vec::new();

        for line in lines {
            if line == "# END DMI" {
                break;
            }

            let mut split = line.trim().split(" = ");
            let (key, value) = (
                split.next().ok_or(Error::MissingValue)?,
                split.next().ok_or(Error::MissingValue)?,
            );

            match key {
                "width" => self.width = value.parse().map_err(ExternalError::ParseInt)?,
                "height" => self.height = value.parse().map_err(ExternalError::ParseInt)?,
                "state" => states.push(State::new(value.trim_matches('"').into())),
                "dirs" => {
                    states.last_mut().ok_or(Error::OutOfOrder)?.dirs =
                        value.parse().map_err(ExternalError::ParseInt)?;
                }
                "frames" => {
                    states.last_mut().ok_or(Error::OutOfOrder)?.frame_count =
                        value.parse().map_err(ExternalError::ParseInt)?;
                }
                "delay" => {
                    states.last_mut().ok_or(Error::OutOfOrder)?.delays = value
                        .split(',')
                        .map(|delay| delay.parse().map_err(ExternalError::ParseFloat))
                        .collect::<std::result::Result<_, _>>()?;
                }
                "loop" => {
                    states.last_mut().ok_or(Error::OutOfOrder)?.r#loop =
                        value.parse().map_err(ExternalError::ParseInt)?;
                }
                "rewind" => {
                    states.last_mut().ok_or(Error::OutOfOrder)?.rewind = value == "1";
                }
                "movement" => {
                    states.last_mut().ok_or(Error::OutOfOrder)?.movement = value == "1";
                }
                "hotspot" => {
                    states
                        .last_mut()
                        .ok_or(Error::OutOfOrder)?
                        .hotspots
                        .push(value.into());
                }
                _ => return Err(Error::UnknownKey)?,
            }
        }

        let table = self.states.get::<Table>()?;

        for (index, state) in states.into_iter().enumerate() {
            table.raw_set(index + 1, lua.create_userdata(state)?)?;
        }

        Ok(())
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

#[derive(Error, Debug)]
#[error(transparent)]
pub enum Error {
    #[error("Missing data")]
    MissingData,
    #[error("Missing ZTXT chunk")]
    MissingZTXT,
    #[error("Missing metadata header")]
    MissingHeader,
    #[error("Invalid metadata version")]
    InvalidVersion,
    #[error("Missing metadata value")]
    MissingValue,
    #[error("State info out of order")]
    OutOfOrder,
    #[error("Unknown metadata key")]
    UnknownKey,
    #[error("Failed to find available directory")]
    SizeMismatch,
    #[error("Failed to find available directory")]
    FindDir,
    #[error("Directory does not exist")]
    DirDoesNotExist,
}