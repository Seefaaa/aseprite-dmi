use anyhow::{anyhow, bail, Result};
use arboard::Clipboard;
use serde_json;
use std::fs;
use std::fs::create_dir_all;
use std::path::Path;

use crate::dmi::{ClipboardState, Dmi, SerializedDmi, SerializedState, State};

pub fn open(mut arguments: impl Iterator<Item = String>) -> Result<String> {
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

        let dmi = Dmi::open(file)?;
        let dmi = dmi.serialize(output)?;
        let json = serde_json::to_string(&dmi)?;

        Ok(json)
    } else {
        bail!("Input path must be a file");
    }
}

pub fn save(mut arguments: impl Iterator<Item = String>) -> Result<()> {
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

pub fn new(mut arguments: impl Iterator<Item = String>) {
    let out_dir = arguments.next().expect("No output provided");
    let name = arguments.next().expect("No name provided");
    let width: u32 = arguments
        .next()
        .expect("No width provided")
        .parse()
        .expect("Failed to parse width");
    let height: u32 = arguments
        .next()
        .expect("No height provided")
        .parse()
        .expect("Failed to parse height");

    let out_dir = Path::new(&out_dir);

    if !out_dir.exists() {
        create_dir_all(out_dir).expect("Failed to create output directory");
    }

    let dmi = Dmi::new(name, width, height);
    let dmi = dmi.serialize(out_dir).expect("Failed to serialize DMI");
    let json = serde_json::to_string(&dmi).expect("Failed to serialize");

    print!("{}", json);
}

pub fn new_state(mut arguments: impl Iterator<Item = String>) {
    let temp = arguments.next().expect("No temp directory provided");
    let width: u32 = arguments
        .next()
        .expect("No width provided")
        .parse()
        .expect("Failed to parse width");
    let height: u32 = arguments
        .next()
        .expect("No height provided")
        .parse()
        .expect("Failed to parse height");

    let temp = Path::new(&temp);

    if !temp.exists() {
        panic!("Temp directory does not exist");
    }

    let state = State::new_blank(String::default(), width, height);
    let state = state.serialize(temp).expect("Failed to serialize state");
    let json = serde_json::to_string(&state).expect("Failed to serialize");

    print!("{}", json);
}

pub fn copy_state(mut arguments: impl Iterator<Item = String>) {
    let temp = arguments.next().expect("No temp directory provided");
    let state = arguments.next().expect("No state provided");

    let temp = Path::new(&temp);
    let state = Path::new(&state);

    if !temp.exists() {
        panic!("Temp directory does not exist");
    }

    if !state.exists() {
        panic!("Json file does not exist");
    }

    let state = fs::read_to_string(state).expect("Failed to read json file");
    let state =
        serde_json::from_str::<SerializedState>(state.as_str()).expect("Failed to parse data");
    let state = State::deserialize(state, temp).expect("Failed to deserialize state");
    let state = state.into_clipboard().expect("Failed to convert state");

    let json = serde_json::to_string(&state).expect("Failed to serialize");

    let mut clipboard = Clipboard::new().expect("Failed to create clipboard");

    clipboard
        .set_text(json)
        .expect("Failed to set clipboard text");
}

pub fn paste_state(mut arguments: impl Iterator<Item = String>) {
    let temp = arguments.next().expect("No temp directory provided");
    let width: u32 = arguments
        .next()
        .expect("No width provided")
        .parse()
        .expect("Failed to parse width");
    let height: u32 = arguments
        .next()
        .expect("No height provided")
        .parse()
        .expect("Failed to parse height");

    let temp = Path::new(&temp);

    if !temp.exists() {
        panic!("Temp directory does not exist");
    }

    let mut clipboard = Clipboard::new().expect("Failed to create clipboard");
    let state = clipboard.get_text().expect("Failed to get clipboard text");

    let state =
        serde_json::from_str::<ClipboardState>(state.as_str()).expect("Failed to parse data");
    let state = State::from_clipboard(state, width, height).expect("Failed to convert state");

    let state = state.serialize(temp).expect("Failed to serialize state");
    let json = serde_json::to_string(&state).expect("Failed to serialize");

    print!("{}", json);
}

pub fn rm(mut arguments: impl Iterator<Item = String>) {
    let dir = arguments.next().expect("No directory provided");
    let dir = Path::new(&dir);

    if dir.exists() {
        fs::remove_dir_all(dir).expect("Failed to remove directory");
    }
}
