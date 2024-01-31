use std::{cmp::Ordering, ffi::OsStr, io::BufWriter, path::Path, time::Duration};

use anyhow::Context as _;
use base64::{engine::general_purpose, Engine as _};
use image::DynamicImage;
use png::{Compression, Encoder};
use thiserror::Error;

#[derive(Error, Debug)]
#[error(transparent)]
pub enum ToBase64Error {
    Image(#[from] image::ImageError),
    PngEncoding(#[from] png::EncodingError),
}

pub fn image_to_base64(image: &DynamicImage) -> Result<String, ToBase64Error> {
    let mut image_data = Vec::new();

    {
        let image_buffer = image.to_rgba8();
        let mut writer = BufWriter::new(&mut image_data);
        let mut encoder = Encoder::new(&mut writer, image.width(), image.height());

        encoder.set_compression(Compression::Best);
        encoder.set_color(png::ColorType::Rgba);
        encoder.set_depth(png::BitDepth::Eight);

        let mut writer = encoder.write_header()?;

        writer.write_image_data(&image_buffer)?;
    }

    Ok(format!(
        "data:image/png;base64,{}",
        general_purpose::STANDARD.encode(image_data)
    ))
}

pub fn find_dir<P: AsRef<OsStr>>(path: P) -> Option<String> {
    let mut path = Path::new(&path).to_path_buf();
    let file_name = path.file_name().unwrap().to_str().unwrap().to_string();

    let mut index: u32 = 0;
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

    parts_quotes
}

pub fn check_latest_release() -> anyhow::Result<bool> {
    let current_version = env!("CARGO_PKG_VERSION");

    let repository = env!("CARGO_PKG_REPOSITORY");
    let repository = repository.split('/').collect::<Vec<_>>();
    let repository = format!("{}/{}", repository[3], repository[4]);

    let user_agent = format!("{}/{}", env!("CARGO_PKG_NAME"), current_version);

    let client = reqwest::blocking::Client::builder()
        .user_agent(user_agent)
        .timeout(Duration::from_secs(10))
        .build()?;

    let url = format!("https://api.github.com/repos/{repository}/releases/latest");

    let response = client.get(url).send()?.json::<serde_json::Value>()?;

    let latest_version = response["tag_name"].as_str().context("No tag_name found")?;
    let latest_version = &latest_version[1..];

    Ok(compare_versions(current_version, latest_version) != Ordering::Less)
}

fn compare_versions(version1: &str, version2: &str) -> Ordering {
    let v1: Vec<u32> = version1
        .split('.')
        .map(|s| s.parse().unwrap_or(0))
        .collect();
    let v2: Vec<u32> = version2
        .split('.')
        .map(|s| s.parse().unwrap_or(0))
        .collect();

    v1.cmp(&v2)
}
