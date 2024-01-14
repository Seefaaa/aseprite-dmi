use std::{ffi::OsStr, io::BufWriter, path::Path};

use base64::{engine::general_purpose, Engine as _};
use image::DynamicImage;
use png::{Compression, Encoder};
use thiserror::Error;

pub trait ToBase64 {
    type Error;
    fn to_base64(&self) -> Result<String, Self::Error>;
}

impl ToBase64 for DynamicImage {
    type Error = ToBase64Error;

    fn to_base64(&self) -> Result<String, Self::Error> {
        let mut image_data = Vec::new();

        {
            let image_buffer = self.to_rgba8();
            let mut writer = BufWriter::new(&mut image_data);
            let mut encoder = Encoder::new(&mut writer, self.width(), self.height());

            encoder.set_compression(Compression::Best);
            encoder.set_color(png::ColorType::Rgba);
            encoder.set_depth(png::BitDepth::Eight);

            let mut writer = encoder.write_header()?;

            writer.write_image_data(&image_buffer)?;
        }

        let base64 = general_purpose::STANDARD.encode(image_data);
        Ok(format!("data:image/png;base64,{}", base64))
    }
}

#[derive(Error, Debug)]
#[error(transparent)]
pub enum ToBase64Error {
    Image(#[from] image::ImageError),
    PngEncoding(#[from] png::EncodingError),
}

pub fn find_available_dir<P: AsRef<OsStr>>(path: P) -> Option<String> {
    let mut index: u32 = 0;
    let mut path = Path::new(&path).to_path_buf();
    let file_name = path.file_name().unwrap().to_str().unwrap().to_string();

    loop {
        index += 1;
        path.set_file_name(format!("{}.{}", file_name, index));
        if !path.exists() {
            break;
        }
    }

    path.to_str().map(|s| s.to_string())
}

pub fn optimal_size(frames: usize, width: u32, height: u32) -> (f32, u32, u32) {
    if frames == 0 {
        return (0., width, height);
    }

    let sqrt = (frames as f32).sqrt().ceil();
    let (width, height) = (
        (width as f32 * sqrt) as u32,
        height * (frames as f32 / sqrt).ceil() as u32,
    );

    (sqrt, width, height)
}

pub fn split_args(string: String) -> Vec<String> {
    let input_string = string;

    let mut parts_quotes: Vec<String> = Vec::new();
    let mut inside_quotes = false;
    let mut inside_single_quotes = false;
    let mut current_part = String::new();

    for char in input_string.chars() {
        match char {
            '"' => {
                if !inside_single_quotes {
                    inside_quotes = !inside_quotes;
                    if !inside_quotes {
                        parts_quotes.push(current_part.clone());
                        current_part.clear();
                    }
                } else {
                    current_part.push(char);
                }
            }
            '\'' => {
                inside_single_quotes = !inside_single_quotes;
                if !inside_single_quotes {
                    parts_quotes.push(current_part.clone());
                    current_part.clear();
                }
            }
            ' ' => {
                if !inside_quotes && !inside_single_quotes && !current_part.is_empty() {
                    parts_quotes.push(current_part.clone());
                    current_part.clear();
                } else if inside_quotes || inside_single_quotes && !current_part.is_empty() {
                    current_part.push(char);
                }
            }
            _ => {
                current_part.push(char);
            }
        }
    }

    if !current_part.is_empty() {
        parts_quotes.push(current_part);
    }

    return parts_quotes;
}
