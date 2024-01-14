use std::net::{TcpListener, TcpStream};
use std::process;
use std::thread::spawn;
use tungstenite::{accept, Message, WebSocket};

use crate::commands;
use crate::utils::split_args;

pub fn websocket(mut arguments: impl Iterator<Item = String>) {
    let port = arguments.next().expect("No port provided");

    let server = TcpListener::bind(format!("127.0.0.1:{}", port)).expect("Failed to bind to port");

    for stream in server.incoming() {
        spawn(move || {
            let mut websocket = accept(stream.unwrap()).unwrap();

            websocket
                .send(Message::Text(format!("pid:{}", process::id())))
                .unwrap();

            loop {
                let message = websocket.read();

                if message.is_err() {
                    exit(&mut websocket);
                }

                let message = message.unwrap();

                if message.is_close() {
                    exit(&mut websocket);
                }

                if message.is_text() {
                    let message = message.to_text().unwrap();
                    let command = message.split_whitespace().next().unwrap();

                    let response = match command {
                        "newfile" => Some(new_file(message)),
                        "openfile" => Some(open_file(message)),
                        "savefile" => Some(save_file(message)),
                        "newstate" => Some(new_state(message)),
                        "copystate" => Some(copy_state(message)),
                        "pastestate" => Some(paste_state(message)),
                        "removedir" => Some(remove_dir(message)),
                        _ => None,
                    };

                    if let Some(response) = response {
                        websocket.send(response).unwrap();
                    }
                }
            }
        });
    }
}

fn exit(websocket: &mut WebSocket<TcpStream>) -> ! {
    if let Ok(_) = websocket.close(None) {
        websocket.flush().unwrap();
    }
    process::exit(0);
}

macro_rules! format_event {
    ($event:expr) => {
        format!("{{\"event\":\"{}\"}}", $event)
    };
    ($event:expr, $data:expr) => {
        format!("{{\"event\":\"{}\",\"data\":{}}}", $event, $data)
    };
}

macro_rules! format_error {
    ($event:expr, $error:expr) => {
        format!("{{\"event\":\"{}\",\"error\":\"{}\"}}", $event, $error)
    };
}

fn new_file(message: &str) -> Message {
    let args = split_args(message.to_string()).into_iter().skip(1);

    match commands::new_file(args) {
        Ok(dmi) => {
            let dmi = format_event!("newfile", dmi);
            Message::Text(dmi)
        }
        Err(e) => {
            let e = format_error!("newfile", e);
            Message::Text(e)
        }
    }
}

fn open_file(message: &str) -> Message {
    let args = split_args(message.to_string()).into_iter().skip(1);

    match commands::open_file(args) {
        Ok(dmi) => {
            let dmi = format_event!("openfile", dmi);
            Message::Text(dmi)
        }
        Err(e) => {
            let e = format_error!("openfile", e);
            Message::Text(e)
        }
    }
}

fn save_file(message: &str) -> Message {
    let args = split_args(message.to_string()).into_iter().skip(1);

    match commands::save_file(args) {
        Ok(_) => {
            let json = format_event!("savefile");
            Message::Text(json)
        }
        Err(e) => {
            let e = format_error!("savefile", e);
            Message::Text(e)
        }
    }
}

fn new_state(message: &str) -> Message {
    let args = split_args(message.to_string()).into_iter().skip(1);

    match commands::new_state(args) {
        Ok(state) => {
            let state = format_event!("newstate", state);
            Message::Text(state)
        }
        Err(e) => {
            let e = format_error!("newstate", e);
            Message::Text(e)
        }
    }
}

fn copy_state(message: &str) -> Message {
    let args = split_args(message.to_string()).into_iter().skip(1);

    match commands::copy_state(args) {
        Ok(_) => {
            let json = format_event!("copystate");
            Message::Text(json)
        }
        Err(e) => {
            let e = format_error!("copystate", e);
            Message::Text(e)
        }
    }
}

fn paste_state(message: &str) -> Message {
    let args = split_args(message.to_string()).into_iter().skip(1);

    match commands::paste_state(args) {
        Ok(state) => {
            let state = format_event!("pastestate", state);
            Message::Text(state)
        }
        Err(e) => {
            let e = format_error!("pastestate", e);
            Message::Text(e)
        }
    }
}

fn remove_dir(message: &str) -> Message {
    let args = split_args(message.to_string()).into_iter().skip(1);

    match commands::remove_dir(args) {
        Ok(_) => {
            let json = format_event!("removedir");
            Message::Text(json)
        }
        Err(e) => {
            let e = format_error!("removedir", e);
            Message::Text(e)
        }
    }
}
