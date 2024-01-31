use anyhow::{anyhow, Context as _, Result};
use std::env::current_exe;
use std::fs::{create_dir_all, write};
use std::net::{TcpListener, TcpStream};
use std::path::Path;
use std::process::{exit, Command};
use std::sync::{Arc, Mutex};
use std::thread::{sleep, spawn};
use std::time::Duration;
use tungstenite::{accept, Message, WebSocket};

use crate::utils::split_args;
use crate::{commands, format_error, format_event};

pub fn serve(mut arguments: impl Iterator<Item = String>) -> Result<()> {
    let port: u16 = arguments.next().context("No port provided")?.parse()?;
    let server = TcpListener::bind(("127.0.0.1", port))?;

    let connected = Arc::new(Mutex::new(false));
    let connected_ = Arc::clone(&connected);
    spawn(move || {
        sleep(Duration::from_secs(30));

        let connected = connected_.lock().unwrap();
        if !*connected {
            exit(0);
        }
    });

    for stream in server.incoming().flatten() {
        let connected = Arc::clone(&connected);

        if *connected.lock().unwrap() {
            continue;
        }

        spawn(move || {
            if let Ok(mut websocket) = accept(stream) {
                {
                    let mut connected = connected.lock().unwrap();
                    *connected = true;
                }

                loop {
                    let Ok(message) = websocket.read() else {
                        exit_websocket(&mut websocket);
                    };

                    if message.is_close() {
                        exit_websocket(&mut websocket);
                    }

                    if message.is_text() {
                        let message = message.to_text().unwrap();
                        let response = process_command(message);

                        if let Some(response) = response {
                            let _ = websocket.send(response);
                        }
                    }
                }
            }
        });
    }

    Ok(())
}

fn exit_websocket(websocket: &mut WebSocket<TcpStream>) -> ! {
    if websocket.close(None).is_ok() {
        websocket.flush().unwrap();
    }
    exit(0)
}

fn process_command(message: &str) -> Option<Message> {
    let mut args = split_args(message.to_string()).into_iter();
    let command_name = args.next()?.to_lowercase();

    let result = match command_name.as_str() {
        "newfile" => commands::new_file(args),
        "openfile" => commands::open_file(args),
        "savefile" => commands::save_file(args),
        "newstate" => commands::new_state(args),
        "copystate" => commands::copy_state(args),
        "pastestate" => commands::paste_state(args),
        "removedir" => commands::remove_dir(args),
        "browser" => commands::browser(),
        _ => Err(anyhow!("Unknown command")),
    };

    Some(match result {
        Ok(data) => Message::Text(format_event!(command_name, data)),
        Err(error) => Message::Text(format_error!(command_name, error)),
    })
}

pub fn init(mut arguments: impl Iterator<Item = String>) -> Result<()> {
    let file_name = arguments.next().context("No file name provided")?;

    let current_exe = current_exe()?;
    let port = TcpListener::bind(("127.0.0.1", 0))?
        .local_addr()?
        .port()
        .to_string();

    let file_name = Path::new(&file_name);

    if let Some(parent) = file_name.parent() {
        if !parent.exists() {
            create_dir_all(parent)?;
        }
    }

    write(file_name, &port)?;
    Command::new(current_exe).arg("serve").arg(port).spawn()?;

    Ok(())
}
