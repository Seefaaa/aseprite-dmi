use arboard::Clipboard;
use serde_json;
use std::fs::create_dir_all;
use std::{fs, process::exit};
use std::net::TcpListener;
use std::path::Path;
use std::thread::spawn;
use tungstenite::{accept, Message};
use anyhow::{Result, anyhow, bail};

use crate::commands;
use crate::dmi::{ClipboardState, Dmi, SerializedDmi, SerializedState, State};
use crate::utils::split_args;

pub fn open(arguments: &mut impl Iterator<Item = String>) -> Result<String> {
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

pub fn save(arguments: &mut impl Iterator<Item = String>) {
    let path = arguments.next().expect("No path provided");
    let json = arguments.next().expect("No json path provided");

    let path = Path::new(&path);
    let json = Path::new(&json);

    if !json.exists() {
        panic!("Json file does not exist");
    }

    let dmi = fs::read_to_string(json).expect("Failed to read json file");

    let parent = path.parent();
    if parent.is_some_and(|p| !p.exists()) {
        create_dir_all(parent.unwrap()).expect("Failed to create output directory");
    }

    let dmi = serde_json::from_str::<SerializedDmi>(dmi.as_str()).expect("Failed to parse data");

    if !Path::new(&dmi.temp).exists() {
        panic!("Temp directory does not exist");
    }

    let dmi = Dmi::deserialize(dmi).expect("Failed to deserialize DMI");

    dmi.save(path).expect("Failed to save DMI");
}

pub fn new(arguments: &mut impl Iterator<Item = String>) {
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

pub fn new_state(arguments: &mut impl Iterator<Item = String>) {
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

pub fn copy_state(arguments: &mut impl Iterator<Item = String>) {
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

pub fn paste_state(arguments: &mut impl Iterator<Item = String>) {
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

pub fn rm(arguments: &mut impl Iterator<Item = String>) {
    let dir = arguments.next().expect("No directory provided");
    let dir = Path::new(&dir);

    if dir.exists() {
        fs::remove_dir_all(dir).expect("Failed to remove directory");
    }
}

pub fn websocket(arguments: &mut impl Iterator<Item = String>) {
    let port = arguments.next().expect("No port provided");

    let server = TcpListener::bind(format!("127.0.0.1:{}", port)).expect("Failed to bind to port");
    for stream in server.incoming() {
        spawn(move || {
            let mut websocket = accept(stream.unwrap()).unwrap();
            loop {
                let message = websocket.read();

                if message.is_err() {
                    break;
                }

                let message = message.unwrap();

                if message.is_text() {
                    let message = message.to_text().unwrap();
                    let command = message.split_whitespace().next().unwrap();

                    println!("INCOMING {}", message);

                    match command {
                        "exit" => {
                            websocket.close(None).unwrap();
                            websocket.flush().unwrap();
                            exit(0);
                        },
                        "openstate" => {
                            let args = split_args(message.to_string());
                            let file = args.get(1).expect("No input provided");
                            let out_dir = args.get(2).expect("No output provided");
                            match commands::open(&mut vec![file.to_string(), out_dir.to_string()].into_iter()) {
                                Ok(json) => {
                                    let json = format!("{{\"event\":\"openstate\",\"data\":{}}}", json);
                                    println!("OUTGOING {}", json);
                                    websocket.send(Message::Text(json)).unwrap();
                                }
                                Err(e) => {
                                    let e = format!("{{\"event\":\"openstate\",\"error\":\"{}\"}}", e);
                                    println!("OUTGOING ERROR {}", e);
                                    websocket.send(Message::Text(e)).unwrap();
                                }
                            }
                        }
                        _ => {}
                    }
                }
            }
        });
    }
}
