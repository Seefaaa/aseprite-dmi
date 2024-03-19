use image::io::Reader as ImageReader;
use image::{imageops, ImageBuffer};
use mlua::{Lua, Result, UserData, UserDataFields, UserDataMethods};
use png::{BitDepth, ColorType, Compression, Decoder, Encoder};
use std::cell::RefCell;
use std::cmp::Ordering;
use std::fs::{create_dir_all, File};
use std::io::BufWriter;
use std::path::Path;
use std::rc::Rc;
use thiserror::Error;

use crate::error::ExternalError;

use super::State;

const DMI_VERSION: &str = "4.0";

#[derive(Debug)]
pub struct Dmi {
    pub name: String,
    pub width: u32,
    pub height: u32,
    pub states: Vec<Rc<RefCell<State>>>,
}

impl Dmi {
    pub fn open(_: &Lua, filename: String) -> Result<Dmi> {
        let decoder = Decoder::new(File::open(&filename)?);
        let reader = decoder.read_info().map_err(ExternalError::PngDecoding)?;
        let chunk = reader
            .info()
            .compressed_latin1_text
            .first()
            .ok_or(Error::MissingZTXT)?;
        let metadata = chunk.get_text().map_err(ExternalError::PngDecoding)?;

        let dmi = Self::from_metadata(&filename, metadata)?;

        let mut reader = ImageReader::open(&filename).map_err(ExternalError::Io)?;
        reader.set_format(image::ImageFormat::Png);

        let mut image = reader.decode().map_err(ExternalError::Image)?;

        for pixel in image.as_mut_rgba8().ok_or(Error::NotRgba8)?.pixels_mut() {
            if pixel[3] == 0 {
                pixel[0] = 0;
                pixel[1] = 0;
                pixel[2] = 0;
            }
        }

        let grid_width = image.width() / dmi.width;

        let mut index = 0;
        for state in dmi.states.iter() {
            let mut state = state.borrow_mut();
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
                        return Err(Error::ImageSizeMismatch)?;
                    }
                    state.frames.push(image);
                    index += 1;
                }
            }
        }

        Ok(dmi)
    }
    fn from_metadata(filename: &str, metadata: String) -> Result<Self> {
        let filename = Path::new(filename)
            .file_stem()
            .unwrap()
            .to_string_lossy()
            .into_owned();

        let mut dmi = Self {
            name: filename,
            width: 32,
            height: 32,
            states: Vec::new(),
        };

        let mut lines = metadata.lines();

        if lines.next().ok_or(Error::MissingHeader)? != "# BEGIN DMI" {
            return Err(Error::MissingHeader)?;
        }

        if lines.next().ok_or(Error::InvalidVersion)? != format!("version = {DMI_VERSION}") {
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
                "width" => dmi.width = value.parse().map_err(ExternalError::ParseInt)?,
                "height" => dmi.height = value.parse().map_err(ExternalError::ParseInt)?,
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

        for state in states {
            dmi.states.push(Rc::new(RefCell::new(state)));
        }

        Ok(dmi)
    }
    fn save(&self, filename: String) -> Result<()> {
        let total_frames: usize = self.states.iter().map(|s| s.borrow().frames.len()).sum();
        let (sqrt, width, height) = size(total_frames, self.width, self.height);

        let mut image_buffer = ImageBuffer::new(width, height);

        let mut index = 0;
        for state in self.states.iter() {
            let state = state.borrow();
            for frame in state.frames.iter() {
                let x = (index as f32 % sqrt) as u32 * self.width;
                let y = (index as f32 / sqrt) as u32 * self.height;
                imageops::replace(&mut image_buffer, frame, x as i64, y as i64);
                index += 1;
            }
        }

        if let Some(path) = Path::new(&filename).parent() {
            if !path.exists() {
                create_dir_all(path).map_err(ExternalError::Io)?;
            }
        }

        let file = File::create(&filename).map_err(ExternalError::Io)?;
        let mut writer = BufWriter::new(file);
        let mut encoder = Encoder::new(&mut writer, width, height);

        encoder.set_color(ColorType::Rgba);
        encoder.set_depth(BitDepth::Eight);
        encoder.set_compression(Compression::Best);

        encoder
            .add_ztxt_chunk("Description".to_string(), self.metadata())
            .map_err(ExternalError::PngEncoding)?;

        let mut writer = encoder.write_header().map_err(ExternalError::PngEncoding)?;

        writer
            .write_image_data(&image_buffer)
            .map_err(ExternalError::PngEncoding)?;

        Ok(())
    }
    fn metadata(&self) -> String {
        let mut metadata = String::new();

        metadata.push_str("# BEGIN DMI\n");
        metadata.push_str(&format!("version = {DMI_VERSION}\n"));
        metadata.push_str(&format!("width = {}\n", self.width));
        metadata.push_str(&format!("height = {}\n", self.height));

        for state in self.states.iter() {
            let state = state.borrow();

            metadata.push_str(&format!("state = \"{}\"\n", state.name));
            metadata.push_str(&format!("\tdirs = {}\n", state.dirs));
            metadata.push_str(&format!("\tframes = {}\n", state.frame_count));

            if !state.delays.is_empty() {
                metadata.push_str("\tdelay = ");
                for delay in state.delays.iter() {
                    metadata.push_str(&format!("{delay},"));
                }
                metadata.pop();
                metadata.push('\n');
            }

            metadata.push_str(&format!("\tloop = {}\n", state.r#loop));
            metadata.push_str(&format!("\trewind = {}\n", state.rewind as u8));
            metadata.push_str(&format!("\tmovement = {}\n", state.movement as u8));

            for hotspot in state.hotspots.iter() {
                metadata.push_str(&format!("\thotspot = {hotspot}\n"));
            }
        }

        metadata.push_str("# END DMI\n");

        metadata
    }
}

impl UserData for Dmi {
    fn add_fields<'lua, F: UserDataFields<'lua, Self>>(fields: &mut F) {
        fields.add_field_method_get("name", |_, this| Ok(this.name.clone()));
        fields.add_field_method_get("width", |_, this| Ok(this.width));
        fields.add_field_method_get("height", |_, this| Ok(this.height));
        fields.add_field_method_get("states", |_, this| Ok(this.states.clone()));
    }
    fn add_methods<'lua, M: UserDataMethods<'lua, Self>>(methods: &mut M) {
        methods.add_method("save", |_, this, filename: String| this.save(filename));
        methods.add_method_mut("new_state", |_, this, ()| {
            let state = Rc::new(RefCell::new(State::blank(this.width, this.height)));

            this.states.push(state.clone());

            Ok(state)
        });
    }
}

fn size(frames: usize, width: u32, height: u32) -> (f32, u32, u32) {
    if frames == 0 {
        return (1., width, height);
    }

    let sqrt = (frames as f32).sqrt().ceil();
    let width = width * sqrt as u32;
    let height = height * (frames as f32 / sqrt).ceil() as u32;

    (sqrt, width, height)
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
    #[error("The size of the states does not match the size of the DMI")]
    ImageSizeMismatch,
    #[error("Failed to find available directory")]
    FindDir,
    #[error("Directory does not exist")]
    DirDoesNotExist,
    #[error("The image is not in RGBA8 format")]
    NotRgba8,
    #[error("The size of the buffer does not match the size of the image")]
    BufSizeMismatch,
}
