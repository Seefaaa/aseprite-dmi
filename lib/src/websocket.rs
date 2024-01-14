use anyhow::anyhow;
use std::env::current_exe;
use std::fs::{create_dir_all, write};
use std::net::{TcpListener, TcpStream};
use std::path::Path;
use std::process::{self, Command};
use std::thread::spawn;
use tungstenite::{accept, Message, WebSocket};

use crate::commands;
use crate::utils::split_args;

pub fn serve(mut arguments: impl Iterator<Item = String>) {
    let port = arguments
        .next()
        .expect("No port provided")
        .parse::<u16>()
        .expect("Invalid port");

    let server = TcpListener::bind(("127.0.0.1", port)).expect("Failed to bind to port");

    for stream in server.incoming() {
        if let Ok(stream) = stream {
            spawn(move || {
                if let Ok(mut websocket) = accept(stream) {
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
                            let response = process_command(message.to_text().unwrap());

                            if let Some(response) = response {
                                if let Err(e) = websocket.send(response) {
                                    eprintln!("{}", e);
                                }
                            }
                        }
                    }
                }
            });
        }
    }
}

fn exit(websocket: &mut WebSocket<TcpStream>) -> ! {
    if let Ok(_) = websocket.close(None) {
        websocket.flush().unwrap();
    }
    process::exit(0);
}

macro_rules! format_event {
    ($event:expr, $data:expr) => {
        if $data.is_empty() {
            format!("{{\"event\":\"{}\"}}", $event)
        } else {
            format!("{{\"event\":\"{}\",\"data\":{}}}", $event, $data)
        }
    };
}

macro_rules! format_error {
    ($event:expr, $error:expr) => {
        format!("{{\"event\":\"{}\",\"error\":\"{}\"}}", $event, $error)
    };
}

fn process_command(message: &str) -> Option<Message> {
    let mut args = split_args(message.to_string()).into_iter();
    let command_name = args.next()?.to_lowercase();

    let result = match command_name.as_str() {
        "newfile" => commands::new_file(args),
        "openfile" => commands::open_file(args),
        "savefile" => commands::save_file(args).map(|_| String::default()),
        "newstate" => commands::new_state(args),
        "copystate" => commands::copy_state(args).map(|_| String::default()),
        "pastestate" => commands::paste_state(args),
        "removedir" => commands::remove_dir(args).map(|_| String::default()),
        _ => Err(anyhow!("Unknown command")),
    };

    Some(match result {
        Ok(data) => Message::Text(format_event!(command_name, data)),
        Err(error) => Message::Text(format_error!(command_name, error)),
    })
}

pub fn init(mut arguments: impl Iterator<Item = String>) {
    let temp_dir = arguments.next().expect("No temp dir provided");
    let file_name = arguments.next().expect("No file name provided");

    let current_exe = current_exe().expect("Failed to get self path");

    let port = {
        let tcp = TcpListener::bind(("127.0.0.1", 0)).expect("Failed to bind to port");
        tcp.local_addr()
            .expect("Failed to get local address")
            .port()
            .to_string()
    };

    let temp_dir = Path::new(&temp_dir);

    if !temp_dir.exists() {
        create_dir_all(temp_dir).expect("Failed to create temp dir");
    }

    write(temp_dir.join(file_name), &port).expect("Failed to write port to file");

    let _ = Command::new(current_exe)
        .arg("ws_serve")
        .arg(port)
        .spawn()
        .expect("Failed to spawn child");
}
