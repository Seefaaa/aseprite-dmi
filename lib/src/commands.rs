use anyhow::{bail, Context as _, Result};
use arboard::Clipboard;
use std::fs::{create_dir_all, remove_dir_all};
use std::path::Path;

use crate::dmi::{ClipboardState, Dmi, SerializedDmi, SerializedState, State};
use crate::utils::check_latest_release;

type CommandResult = Result<Option<String>>;

pub fn new_file(mut arguments: impl Iterator<Item = String>) -> CommandResult {
    let out_dir = arguments.next().context("No output provided")?;
    let name = arguments.next().context("No name provided")?;
    let width: u32 = arguments.next().context("No width provided")?.parse()?;
    let height: u32 = arguments.next().context("No height provided")?.parse()?;

    let out_dir = Path::new(&out_dir);

    if !out_dir.exists() {
        create_dir_all(out_dir)?;
    }

    let dmi = Dmi::new(name, width, height).serialize(out_dir)?;
    let dmi = serde_json::to_string(&dmi)?;

    Ok(Some(dmi))
}

pub fn open_file(mut arguments: impl Iterator<Item = String>) -> CommandResult {
    let file = arguments.next().context("No input provided")?;
    let out_dir = arguments.next().context("No output provided")?;

    let file = Path::new(&file);
    let output = Path::new(&out_dir);

    if file.is_file() {
        if output.is_file() {
            bail!("Output path must be a directory");
        }

        if !output.exists() {
            create_dir_all(output)?;
        }

        let dmi = Dmi::open(file)?.serialize(output)?;
        let dmi = serde_json::to_string(&dmi)?;

        return Ok(Some(dmi));
    }

    bail!("Input path must be a file");
}

pub fn save_file(mut arguments: impl Iterator<Item = String>) -> CommandResult {
    let path = arguments.next().context("No path provided")?;
    let dmi = arguments.next().context("No json provided")?;

    let path = Path::new(&path);

    if let Some(parent) = path.parent() {
        if !parent.exists() {
            create_dir_all(parent)?;
        }
    }

    let dmi = serde_json::from_str::<SerializedDmi>(dmi.as_str())?;

    let temp = Path::new(&dmi.temp);

    if !temp.exists() {
        bail!("Temp directory does not exist");
    }

    let dmi = Dmi::deserialize(dmi)?;

    dmi.save(path)?;

    Ok(None)
}

pub fn new_state(mut arguments: impl Iterator<Item = String>) -> CommandResult {
    let temp = arguments.next().context("No temp directory provided")?;
    let width: u32 = arguments.next().context("No width provided")?.parse()?;
    let height: u32 = arguments.next().context("No height provided")?.parse()?;

    let temp = Path::new(&temp);

    if !temp.exists() {
        bail!("Temp directory does not exist");
    }

    let state = State::new_blank(String::default(), width, height).serialize(temp)?;
    let state = serde_json::to_string(&state)?;

    Ok(Some(state))
}

pub fn copy_state(mut arguments: impl Iterator<Item = String>) -> CommandResult {
    let temp = arguments.next().context("No temp directory provided")?;
    let state = arguments.next().context("No json provided")?;

    let temp = Path::new(&temp);

    if !temp.exists() {
        bail!("Temp directory does not exist");
    }

    let state = serde_json::from_str::<SerializedState>(state.as_str())?;
    let state = State::deserialize(state, temp)?.into_clipboard()?;
    let state = serde_json::to_string(&state)?;

    let mut clipboard = Clipboard::new()?;
    clipboard.set_text(state)?;

    Ok(None)
}

pub fn paste_state(mut arguments: impl Iterator<Item = String>) -> CommandResult {
    let temp = arguments.next().context("No temp directory provided")?;
    let width: u32 = arguments.next().context("No width provided")?.parse()?;
    let height: u32 = arguments.next().context("No height provided")?.parse()?;

    let temp = Path::new(&temp);

    if !temp.exists() {
        bail!("Temp directory does not exist");
    }

    let mut clipboard = Clipboard::new()?;
    let state = clipboard.get_text()?;

    let state = serde_json::from_str::<ClipboardState>(state.as_str())?;
    let state = State::from_clipboard(state, width, height)?.serialize(temp)?;
    let state = serde_json::to_string(&state)?;

    Ok(Some(state))
}

pub fn remove_dir(mut arguments: impl Iterator<Item = String>) -> CommandResult {
    let dir = arguments.next().context("No directory provided")?;

    let dir = Path::new(&dir);

    if dir.exists() {
        remove_dir_all(dir)?;
    }

    Ok(None)
}

pub fn check_update() -> CommandResult {
    let is_up_to_date = check_latest_release().unwrap_or(true);

    Ok(Some(is_up_to_date.to_string()))
}

pub fn open_repo(mut arguments: impl Iterator<Item = String>) -> CommandResult {
    let path = arguments.next();

    let url = if let Some(path) = path {
        format!("{}/{}", env!("CARGO_PKG_REPOSITORY"), path)
    } else {
        env!("CARGO_PKG_REPOSITORY").to_string()
    };

    webbrowser::open(&url)?;

    Ok(None)
}
