use std::{env::{self, current_exe}, process::Command};

mod commands;
mod dmi;
mod utils;

fn main() {
    std::panic::set_hook(Box::new(|info| {
        println!("{}", info);
    }));

    let mut arguments = env::args().skip(1);
    let command = arguments.next().expect("No command provided");

    match command.as_str() {
        "OPEN" => {
            match commands::open(&mut arguments) {
                Ok(json) => {
                    print!("{}", json);
                }
                Err(e) => {
                    eprintln!("{}", e);
                }
            }
        }
        "SAVE" => {
            commands::save(&mut arguments);
        }
        "NEW" => {
            commands::new(&mut arguments);
        }
        "NEWSTATE" => {
            commands::new_state(&mut arguments);
        }
        "COPYSTATE" => {
            commands::copy_state(&mut arguments);
        }
        "PASTESTATE" => {
            commands::paste_state(&mut arguments);
        }
        "RM" => {
            commands::rm(&mut arguments);
        }
        "NEWWS" => {
            let current_exe = current_exe().expect("Failed to get self path");
            let _ = Command::new(current_exe)
                .arg("WS")
                .arg(arguments.next().expect("No port provided"))
                .spawn()
                .expect("Failed to spawn child");
        }
        "WS" => {
            commands::websocket(&mut arguments);
        }
        _ => panic!("Unknown command"),
    }
}
