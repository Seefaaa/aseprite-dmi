#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::env::args;

mod commands;
mod dmi;
mod macros;
mod utils;
mod websocket;

fn main() {
    let mut arguments = args().skip(1);

    if let Some(command) = arguments.next() {
        if let Err(e) = match command.to_lowercase().as_str() {
            "serve" => websocket::serve(arguments),
            "init" => websocket::init(arguments),
            _ => Ok(()),
        } {
            println!("{}", e);
        }
    }
}
