use anyhow::{Context as _, Result};
use base64::{engine::general_purpose, Engine as _};
use image::DynamicImage;
use png::{Compression, Encoder};
use serde_json::Value;
use std::cmp::Ordering;
use std::ffi::OsStr;
use std::io::BufWriter;
use std::path::{Path, PathBuf};
use std::time::Duration;

pub fn image_to_base64(image: &DynamicImage) -> Result<String> {
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

pub fn find_directory<P>(path: P) -> PathBuf
where
    P: AsRef<OsStr>,
{
    let mut path = Path::new(&path).to_path_buf();
    let file_name = path.file_name().unwrap().to_str().unwrap().to_string();

    let mut index = 1u32;
    loop {
        path.set_file_name(format!("{file_name}.{index}"));
        if !path.exists() {
            break;
        }
        index += 1;
    }

    path
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

pub fn check_latest_version() -> Result<Ordering> {
    let current_version = env!("CARGO_PKG_VERSION");
    let package_name = env!("CARGO_PKG_NAME");

    let repository = env!("CARGO_PKG_REPOSITORY")
        .split('/')
        .skip(3)
        .collect::<Vec<_>>()
        .join("/");

    let client = reqwest::blocking::Client::builder()
        .user_agent(format!("{package_name}/{current_version}"))
        .timeout(Duration::from_secs(3))
        .build()?;

    let url = format!("https://api.github.com/repos/{repository}/releases/latest");

    let response = client.get(url).send()?.json::<Value>()?;

    let latest_version = response["tag_name"]
        .as_str()
        .context(format!("No tag name found\n{response}"))?;
    let latest_version = &latest_version[1..];

    Ok(compare_versions(current_version, latest_version))
}

fn compare_versions(v1: &str, v2: &str) -> Ordering {
    let v1 = v1
        .split('.')
        .map(|s| s.parse().unwrap_or(0u8))
        .collect::<Vec<_>>();
    let v2 = v2
        .split('.')
        .map(|s| s.parse().unwrap_or(0u8))
        .collect::<Vec<_>>();

    v1.cmp(&v2)
}
