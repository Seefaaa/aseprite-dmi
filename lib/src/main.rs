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
        "OPEN" => match commands::open_file(arguments) {
            Ok(dmi) => {
                print!("{}", dmi);
            }
            Err(e) => {
                eprintln!("{}", e);
            }
        },
        "SAVE" => {
            if let Err(e) = commands::save_file(arguments) {
                eprintln!("{}", e);
            }
        }
        "NEW" => match commands::new_file(arguments) {
            Ok(dmi) => {
                print!("{}", dmi);
            }
            Err(e) => {
                eprintln!("{}", e);
            }
        },
        "NEWSTATE" => match commands::new_state(arguments) {
            Ok(state) => {
                print!("{}", state);
            }
            Err(e) => {
                eprintln!("{}", e);
            }
        },
        "COPYSTATE" => {
            if let Err(e) = commands::copy_state(arguments) {
                eprintln!("{}", e);
            }
        }
        "PASTESTATE" => match commands::paste_state(arguments) {
            Ok(state) => {
                print!("{}", state);
            }
            Err(e) => {
                eprintln!("{}", e);
            }
        },
        "RM" => {
            if let Err(e) = commands::remove_dir(arguments) {
                eprintln!("{}", e);
            }
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
