#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::env;

mod commands;
mod dmi;
mod utils;
mod websocket;

fn main() {
    std::panic::set_hook(Box::new(|info| {
        println!("{}", info);
    }));

    let mut arguments = env::args().skip(1);

    if let Some(command) = arguments.next() {
        match command.to_lowercase().as_str() {
            "ws_serve" => {
                websocket::serve(arguments);
            }
            "ws_init" => {
                websocket::init(arguments);
            }
            _ => {}
        }
    }
}
