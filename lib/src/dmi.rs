use base64::{engine::general_purpose, Engine as _};
use image::{imageops, ImageBuffer};
use image::{io::Reader as ImageReader, DynamicImage};
use png::{Compression, Decoder, Encoder};
use serde::{Deserialize, Serialize};
use std::cmp::Ordering;
use std::ffi::OsStr;
use std::fs::{self, File};
use std::io::{BufWriter, Cursor};
use std::path::Path;
use thiserror::Error;

use crate::utils::{find_dir, image_to_base64, optimal_size};

const DMI_VERSION: &str = "4.0";

#[derive(Debug)]
pub struct Dmi {
    pub name: String,
    pub width: u32,
    pub height: u32,
    pub states: Vec<State>,
}

impl Dmi {
    pub fn new(name: String, width: u32, height: u32) -> Dmi {
        Dmi {
            name,
            width,
            height,
            states: Vec::new(),
        }
    }
    pub fn with_metadata(&mut self, metadata: String) -> DmiResult<()> {
        let mut lines = metadata.lines();

        if lines.next().ok_or(DmiError::MissingMetadataHeader)? != "# BEGIN DMI" {
            return Err(DmiError::MissingMetadataHeader);
        }

        if lines.next().ok_or(DmiError::InvalidMetadataVersion)?
            != format!("version = {}", DMI_VERSION)
        {
            return Err(DmiError::InvalidMetadataVersion);
        }

        for line in lines {
            if line == "# END DMI" {
                break;
            }

            let mut split = line.trim().split(" = ");
            let (key, value) = (
                split.next().ok_or(DmiError::MissingMetadataValue)?,
                split.next().ok_or(DmiError::MissingMetadataValue)?,
            );

            match key {
                "width" => self.width = value.parse()?,
                "height" => self.height = value.parse()?,
                "state" => self.states.push(State::new(value.trim_matches('"').into())),
                "dirs" => {
                    self.states
                        .last_mut()
                        .ok_or(DmiError::OutOfOrderStateInfo)?
                        .dirs = value.parse()?;
                }
                "frames" => {
                    self.states
                        .last_mut()
                        .ok_or(DmiError::OutOfOrderStateInfo)?
                        .frame_count = value.parse()?;
                }
                "delay" => {
                    self.states
                        .last_mut()
                        .ok_or(DmiError::OutOfOrderStateInfo)?
                        .delays = value
                        .split(',')
                        .map(|delay| delay.parse())
                        .collect::<Result<_, _>>()?;
                }
                "loop" => {
                    self.states
                        .last_mut()
                        .ok_or(DmiError::OutOfOrderStateInfo)?
                        .loop_ = value.parse()?;
                }
                "rewind" => {
                    self.states
                        .last_mut()
                        .ok_or(DmiError::OutOfOrderStateInfo)?
                        .rewind = value == "1";
                }
                "movement" => {
                    self.states
                        .last_mut()
                        .ok_or(DmiError::OutOfOrderStateInfo)?
                        .movement = value == "1";
                }
                "hotspot" => {
                    self.states
                        .last_mut()
                        .ok_or(DmiError::OutOfOrderStateInfo)?
                        .hotspots
                        .push(value.into());
                }
                _ => return Err(DmiError::UnknownMetadataKey),
            }
        }

        Ok(())
    }
    pub fn metadata(&self) -> String {
        let mut string = String::default();
        string.push_str("# BEGIN DMI\n");
        string.push_str(format!("version = {}\n", DMI_VERSION).as_str());
        string.push_str(format!("\twidth = {}\n", self.width).as_str());
        string.push_str(format!("\theight = {}\n", self.height).as_str());
        for state in self.states.iter() {
            string.push_str(format!("state = \"{}\"\n", state.name).as_str());
            string.push_str(format!("\tdirs = {}\n", state.dirs).as_str());
            string.push_str(format!("\tframes = {}\n", state.frame_count).as_str());
            if !state.delays.is_empty() {
                let delays = state
                    .delays
                    .iter()
                    .map(|delay| delay.to_string())
                    .collect::<Vec<_>>()
                    .join(",");
                string.push_str(format!("\tdelay = {}\n", delays).as_str())
            };
            if state.loop_ > 0 {
                string.push_str(format!("\tloop = {}\n", state.loop_).as_str())
            };
            if state.rewind {
                string.push_str(format!("\trewind = {}\n", state.rewind as u32).as_str())
            };
            if state.movement {
                string.push_str(format!("\tmovement = {}\n", state.movement as u32).as_str())
            };
            if !state.hotspots.is_empty() {
                for hotspot in state.hotspots.iter() {
                    string.push_str(format!("\thotspot = {}\n", hotspot).as_str());
                }
            }
        }
        string.push_str("# END DMI\n");
        string
    }
    pub fn open<P: AsRef<Path>>(path: P) -> DmiResult<Self> {
        let decoder = Decoder::new(File::open(&path)?);
        let reader = decoder.read_info()?;
        let chunk = reader
            .info()
            .compressed_latin1_text
            .first()
            .ok_or(DmiError::MissingZTXTChunk)?;
        let metadata = chunk.get_text()?;

        let mut dmi = Self::new(
            path.as_ref().file_stem().unwrap().to_str().unwrap().into(),
            32,
            32,
        );

        dmi.with_metadata(metadata)?;

        let mut reader = ImageReader::open(&path)?;
        reader.set_format(image::ImageFormat::Png);

        let mut image = reader.decode()?;
        let grid_width = image.width() / dmi.width;

        let mut index = 0;
        for state in dmi.states.iter_mut() {
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
                        return Err(DmiError::ImageSizeMismatch);
                    }
                    state.frames.push(image);
                    index += 1;
                }
            }
        }

        Ok(dmi)
    }
    pub fn save<P: AsRef<Path>>(&self, path: P) -> DmiResult<()> {
        let total_frames = self
            .states
            .iter()
            .map(|state| state.frames.len() as u32)
            .sum::<u32>() as usize;

        let (sqrt, width, height) = optimal_size(total_frames, self.width, self.height);

        let mut image_buffer = ImageBuffer::new(width, height);

        let mut index: u32 = 0;
        for state in self.states.iter() {
            for frame in state.frames.iter() {
                let (x, y) = (
                    (index as f32 % sqrt) as u32 * self.width,
                    (index as f32 / sqrt) as u32 * self.height,
                );
                imageops::replace(&mut image_buffer, frame, x as i64, y as i64);
                index += 1;
            }
        }

        let mut writer = BufWriter::new(File::create(path)?);
        let mut encoder = Encoder::new(&mut writer, width, height);

        encoder.set_compression(Compression::Best);
        encoder.set_color(png::ColorType::Rgba);
        encoder.set_depth(png::BitDepth::Eight);

        encoder.add_ztxt_chunk("Description".to_string(), self.metadata())?;

        let mut writer = encoder.write_header()?;

        writer.write_image_data(&image_buffer)?;

        Ok(())
    }
    pub fn serialize<P: AsRef<Path>>(&self, path: P) -> DmiResult<SerializedDmi> {
        let path = find_dir(path.as_ref().join(self.name.clone())).ok_or(DmiError::FindDirError)?;
        let path = Path::new(&path);

        fs::create_dir_all(path)?;

        let mut serialized_dmi = SerializedDmi {
            name: self.name.clone(),
            width: self.width,
            height: self.height,
            states: Vec::new(),
            temp: path.to_str().unwrap().to_string(),
        };

        for state in self.states.iter() {
            serialized_dmi.states.push(state.serialize(path)?);
        }

        Ok(serialized_dmi)
    }
    pub fn deserialize(serialized: SerializedDmi) -> DmiResult<Dmi> {
        let mut dmi = Self {
            name: serialized.name,
            width: serialized.width,
            height: serialized.height,
            states: Vec::new(),
        };

        for state in serialized.states {
            dmi.states
                .push(State::deserialize(state, &serialized.temp)?);
        }

        Ok(dmi)
    }
}

#[derive(Debug)]
pub struct State {
    pub name: String,
    pub dirs: u32,
    pub frames: Vec<DynamicImage>,
    pub frame_count: u32,
    pub delays: Vec<f32>,
    pub loop_: u32,
    pub rewind: bool,
    pub movement: bool,
    pub hotspots: Vec<String>,
}

impl State {
    fn new(name: String) -> Self {
        State {
            name,
            dirs: 1,
            frames: Vec::new(),
            frame_count: 0,
            delays: Vec::new(),
            loop_: 0,
            rewind: false,
            movement: false,
            hotspots: Vec::new(),
        }
    }
    pub fn new_blank(name: String, width: u32, height: u32) -> Self {
        let mut state = Self::new(name);
        state.frames.push(DynamicImage::new_rgba8(width, height));
        state.frame_count = 1;
        state
    }
    pub fn serialize<P: AsRef<OsStr>>(&self, path: P) -> DmiResult<SerializedState> {
        let mut state = SerializedState {
            name: self.name.clone(),
            dirs: self.dirs,
            frame_key: String::default(),
            frame_count: self.frame_count,
            delays: self.delays.clone(),
            loop_: self.loop_,
            rewind: self.rewind,
            movement: self.movement,
            hotspots: self.hotspots.clone(),
        };

        {
            let mut index = 1;
            let mut path = Path::new(&path).join(".png");
            loop {
                let frame_key = format!("{}.{}", self.name, index);
                path.set_file_name(format!("{}.{}.png", frame_key, 0));
                if !path.exists() {
                    state.frame_key = frame_key;
                    break;
                }
                index += 1;
            }
        }

        let mut index: u32 = 0;
        for frame in 0..self.frame_count {
            for direction in 0..self.dirs {
                let image = &self.frames[(frame * self.dirs + direction) as usize];
                image.save(Path::new(&path).join(format!("{}.{}.png", state.frame_key, index)))?;
                index += 1;
            }
        }

        Ok(state)
    }
    pub fn deserialize<P: AsRef<OsStr>>(serialized: SerializedState, path: P) -> DmiResult<Self> {
        let mut state = Self {
            name: serialized.name,
            dirs: serialized.dirs,
            frames: Vec::new(),
            frame_count: serialized.frame_count,
            delays: serialized.delays,
            loop_: serialized.loop_,
            rewind: serialized.rewind,
            movement: serialized.movement,
            hotspots: serialized.hotspots,
        };

        for frame in 0..(serialized.frame_count * serialized.dirs) {
            let path = Path::new(&path).join(format!("{}.{}.png", serialized.frame_key, frame));
            state.frames.push(ImageReader::open(path)?.decode()?);
        }

        Ok(state)
    }
    pub fn from_clipboard(state: ClipboardState, width: u32, height: u32) -> DmiResult<Self> {
        let mut frames = Vec::new();

        for frame in state.frames.iter() {
            let base64 = frame
                .split(',')
                .nth(1)
                .ok_or_else(|| DmiError::MissingData)?;
            let image_data = general_purpose::STANDARD.decode(base64)?;
            let reader = ImageReader::with_format(Cursor::new(image_data), image::ImageFormat::Png);
            let mut image = reader.decode()?;

            if image.width() != width || image.height() != height {
                image = image.resize(width, height, imageops::FilterType::Nearest);
            }

            frames.push(image);
        }

        let frame_count = state.frames.len() as u32 / state.dirs;

        Ok(Self {
            name: state.name,
            dirs: state.dirs,
            frames,
            frame_count,
            delays: state.delays,
            loop_: state.loop_,
            rewind: state.rewind,
            movement: state.movement,
            hotspots: state.hotspots,
        })
    }
    pub fn into_clipboard(self) -> DmiResult<ClipboardState> {
        let frames = self
            .frames
            .iter()
            .map(image_to_base64)
            .collect::<Result<Vec<_>, _>>()?;

        Ok(ClipboardState {
            name: self.name,
            dirs: self.dirs,
            frames,
            delays: self.delays,
            loop_: self.loop_,
            rewind: self.rewind,
            movement: self.movement,
            hotspots: self.hotspots,
        })
    }
}

#[derive(Serialize, Deserialize, Debug)]
pub struct SerializedDmi {
    pub name: String,
    pub width: u32,
    pub height: u32,
    pub states: Vec<SerializedState>,
    pub temp: String,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct SerializedState {
    pub name: String,
    pub dirs: u32,
    pub frame_key: String,
    pub frame_count: u32,
    pub delays: Vec<f32>,
    pub loop_: u32,
    pub rewind: bool,
    pub movement: bool,
    pub hotspots: Vec<String>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct ClipboardState {
    pub name: String,
    pub dirs: u32,
    pub frames: Vec<String>,
    pub delays: Vec<f32>,
    pub loop_: u32,
    pub rewind: bool,
    pub movement: bool,
    pub hotspots: Vec<String>,
}

type DmiResult<T> = Result<T, DmiError>;

#[derive(Error, Debug)]
#[error(transparent)]
pub enum DmiError {
    Io(#[from] std::io::Error),
    Image(#[from] image::ImageError),
    PngDecoding(#[from] png::DecodingError),
    PngEncoding(#[from] png::EncodingError),
    ParseInt(#[from] std::num::ParseIntError),
    ParseFloat(#[from] std::num::ParseFloatError),
    DecodeError(#[from] base64::DecodeError),
    ToBase64(#[from] crate::utils::ToBase64Error),
    #[error("Missing data")]
    MissingData,
    #[error("Missing ZTXT chunk")]
    MissingZTXTChunk,
    #[error("Missing metadata header")]
    MissingMetadataHeader,
    #[error("Invalid metadata version")]
    InvalidMetadataVersion,
    #[error("Missing metadata value")]
    MissingMetadataValue,
    #[error("State info out of order")]
    OutOfOrderStateInfo,
    #[error("Unknown metadata key")]
    UnknownMetadataKey,
    #[error("Failed to find available directory")]
    ImageSizeMismatch,
    #[error("Failed to find available directory")]
    FindDirError,
}
