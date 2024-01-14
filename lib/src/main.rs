use std::{
    env::{self, current_exe},
    process::Command,
};

mod commands;
mod dmi;
mod utils;
mod websocket;

fn main() {
    std::panic::set_hook(Box::new(|info| {
        println!("{}", info);
    }));

    let mut arguments = env::args().skip(1);
    let command = arguments.next().expect("No command provided");

    match command.as_str() {
        "OPEN" => match commands::open(arguments) {
            Ok(json) => {
                print!("{}", json);
            }
            Err(e) => {
                eprintln!("{}", e);
            }
        },
        "SAVE" => {
            if let Err(e) = commands::save(arguments) {
                eprintln!("{}", e);
            }
        }
        "NEW" => {
            commands::new(arguments);
        }
        "NEWSTATE" => {
            commands::new_state(arguments);
        }
        "COPYSTATE" => {
            if let Err(e) = commands::copy_state(arguments) {
                eprintln!("{}", e);
            }
        }
        "PASTESTATE" => {
            commands::paste_state(arguments);
        }
        "RM" => {
            commands::rm(arguments);
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
            websocket::websocket(arguments);
        }
        _ => panic!("Unknown command"),
    }
}
