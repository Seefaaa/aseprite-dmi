use anyhow::{anyhow, Context as _, Result};
use std::env::current_exe;
use std::fs::{copy, create_dir_all, remove_dir_all, remove_file, write};
use std::net::TcpListener;
use std::path::Path;
use std::process::{self, Command};
use std::sync::{Arc, Mutex};
use std::thread::{sleep, spawn};
use std::time::Duration;
use tungstenite::{accept, Message};

use crate::utils::split_args;
use crate::{commands, format_error, format_event};

pub fn serve(mut arguments: impl Iterator<Item = String>) -> Result<()> {
    let parent_exe = arguments.next().context("No parent exe provided")?;
    let port: u16 = arguments.next().context("No port provided")?.parse()?;
    let server = TcpListener::bind(("127.0.0.1", port))?;

    let parent_exe = Arc::new(parent_exe);
    let connected = Arc::new(Mutex::new(false));

    {
        let parent_exe = Arc::clone(&parent_exe);
        let connected = Arc::clone(&connected);
        spawn(move || {
            sleep(Duration::from_secs(30));

            let connected = connected.lock().unwrap();
            if !*connected {
                exit(&parent_exe);
            }
        });
    }

    for stream in server.incoming().flatten() {
        let connected = Arc::clone(&connected);

        if *connected.lock().unwrap() {
            continue;
        }

        let parent_exe = Arc::clone(&parent_exe);

        spawn(move || {
            if let Ok(mut websocket) = accept(stream) {
                {
                    let mut connected = connected.lock().unwrap();
                    *connected = true;
                }

                loop {
                    let Ok(message) = websocket.read() else {
                        exit(&parent_exe)
                    };

                    if message.is_close() {
                        exit(&parent_exe)
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
        "resize" => commands::resize(args),
        "removedir" => commands::remove_dir(args),
        "checkupdate" => commands::check_update(),
        "openrepo" => commands::open_repo(args),
        _ => Err(anyhow!("Unknown command: {command_name}")),
    };

    Some(match result {
        Ok(data) => Message::Text(format_event!(command_name, data)),
        Err(error) => Message::Text(format_error!(command_name, error)),
    })
}

pub fn start(mut arguments: impl Iterator<Item = String>) -> Result<()> {
    let temp_dir = arguments.next().context("No temp dir provided")?;

    let current_exe = current_exe()?;
    let port = TcpListener::bind(("127.0.0.1", 0))?
        .local_addr()?
        .port()
        .to_string();

    let temp_dir = Path::new(&temp_dir);

    if !temp_dir.exists() {
        create_dir_all(temp_dir)?;
    }

    copy(&current_exe, temp_dir.join("lib.exe"))?;
    write(temp_dir.join("port"), &port)?;
    Command::new(&current_exe)
        .arg("serve")
        .arg(current_exe)
        .arg(port)
        .spawn()?;

    Ok(())
}

pub fn delete(mut arguments: impl Iterator<Item = String>) -> Result<()> {
    let path = arguments.next().context("No path provided")?;
    let path = Path::new(&path);

    if path.exists() {
        if path.is_file() {
            remove_file(path)?;
        } else {
            remove_dir_all(path)?;
        }
    }

    Ok(())
}

fn exit(parent_exe: &str) -> ! {
    if let Ok(current_exe) = current_exe() {
        let mut command = Command::new(parent_exe);

        command.arg("delete");

        if let Some(temp_dir) = current_exe.parent() {
            command.arg(temp_dir);
        } else {
            command.arg(current_exe);
        }

        let _ = command.spawn();
    }

    process::exit(0)
}
