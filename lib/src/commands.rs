use anyhow::{anyhow, bail, Result};
use arboard::Clipboard;
use serde_json;
use std::fs;
use std::fs::create_dir_all;
use std::path::Path;

use crate::dmi::{ClipboardState, Dmi, SerializedDmi, SerializedState, State};

pub fn new_file(mut arguments: impl Iterator<Item = String>) -> Result<String> {
    let out_dir = arguments.next().ok_or(anyhow!("No output provided"))?;
    let name = arguments.next().ok_or(anyhow!("No name provided"))?;
    let width: u32 = arguments.next().expect("No width provided").parse()?;
    let height: u32 = arguments.next().expect("No height provided").parse()?;

    let out_dir = Path::new(&out_dir);

    if !out_dir.exists() {
        create_dir_all(out_dir)?;
    }

    let dmi = Dmi::new(name, width, height).serialize(out_dir)?;
    let dmi = serde_json::to_string(&dmi)?;

    Ok(dmi)
}

pub fn open_file(mut arguments: impl Iterator<Item = String>) -> Result<String> {
    let file = arguments.next().ok_or(anyhow!("No input provided"))?;
    let out_dir = arguments.next().ok_or(anyhow!("No output provided"))?;

    let file = Path::new(&file);
    let output = Path::new(&out_dir);

    if file.is_file() {
        if output.extension().is_some() {
            bail!("Output path must be a directory");
        }

        if !output.exists() {
            create_dir_all(output)?;
        }

        let dmi = Dmi::open(file)?.serialize(output)?;
        let dmi = serde_json::to_string(&dmi)?;

        Ok(dmi)
    } else {
        bail!("Input path must be a file");
    }
}

pub fn save_file(mut arguments: impl Iterator<Item = String>) -> Result<()> {
    let path = arguments.next().ok_or(anyhow!("No path provided"))?;
    let dmi = arguments.next().ok_or(anyhow!("No json provided"))?;

    let path = Path::new(&path);

    let parent = path.parent();
    if parent.is_some_and(|p| !p.exists()) {
        create_dir_all(parent.unwrap())?;
    }

    let dmi = serde_json::from_str::<SerializedDmi>(dmi.as_str())?;

    if !Path::new(&dmi.temp).exists() {
        bail!("Temp directory does not exist");
    }

    let dmi = Dmi::deserialize(dmi)?;

    dmi.save(path)?;

    Ok(())
}

pub fn new_state(mut arguments: impl Iterator<Item = String>) -> Result<String> {
    let temp = arguments
        .next()
        .ok_or(anyhow!("No temp directory provided"))?;
    let width: u32 = arguments
        .next()
        .ok_or(anyhow!("No width provided"))?
        .parse()?;
    let height: u32 = arguments
        .next()
        .ok_or(anyhow!("No height provided"))?
        .parse()?;

    let temp = Path::new(&temp);

    if !temp.exists() {
        bail!("Temp directory does not exist");
    }

    let state = State::new_blank(String::default(), width, height).serialize(temp)?;
    let state = serde_json::to_string(&state)?;

    Ok(state)
}

pub fn copy_state(mut arguments: impl Iterator<Item = String>) -> Result<()> {
    let temp = arguments
        .next()
        .ok_or(anyhow!("No temp directory provided"))?;
    let state = arguments.next().ok_or(anyhow!("No json provided"))?;

    let temp = Path::new(&temp);

    if !temp.exists() {
        bail!("Temp directory does not exist");
    }

    let state = serde_json::from_str::<SerializedState>(state.as_str())?;
    let state = State::deserialize(state, temp)?.into_clipboard()?;
    let state = serde_json::to_string(&state)?;

    let mut clipboard = Clipboard::new()?;
    clipboard.set_text(state)?;

    Ok(())
}

pub fn paste_state(mut arguments: impl Iterator<Item = String>) -> Result<String> {
    let temp = arguments
        .next()
        .ok_or(anyhow!("No temp directory provided"))?;
    let width: u32 = arguments
        .next()
        .ok_or(anyhow!("No width provided"))?
        .parse()?;
    let height: u32 = arguments
        .next()
        .ok_or(anyhow!("No height provided"))?
        .parse()?;

    let temp = Path::new(&temp);

    if !temp.exists() {
        bail!("Temp directory does not exist");
    }

    let mut clipboard = Clipboard::new()?;
    let state = clipboard.get_text()?;

    let state = serde_json::from_str::<ClipboardState>(state.as_str())?;
    let state = State::from_clipboard(state, width, height)?.serialize(temp)?;
    let state = serde_json::to_string(&state)?;

    Ok(state)
}

pub fn remove_dir(mut arguments: impl Iterator<Item = String>) -> Result<()> {
    let dir = arguments.next().ok_or(anyhow!("No directory provided"))?;
    let dir = Path::new(&dir);

    if dir.exists() {
        fs::remove_dir_all(dir)?;
    }

    Ok(())
}
