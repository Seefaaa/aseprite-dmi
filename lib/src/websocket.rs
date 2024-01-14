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

            websocket.send(Message::Ping(Vec::new())).unwrap();
            websocket
                .send(Message::Text(format!("pid:{}", process::id())))
                .unwrap();

            loop {
                let message = websocket.read();

                if message.is_err() {
                    exit(&mut websocket);
                    break;
                }

                let message = message.unwrap();

                if message.is_close() {
                    exit(&mut websocket);
                    break;
                }

                if message.is_pong() {
                    println!("RECEIVED PONG");
                }

                if message.is_text() {
                    let message = message.to_text().unwrap();
                    let command = message.split_whitespace().next().unwrap();

                    println!("INCOMING {}", message);

                    match command {
                        "openstate" => open_state(message, &mut websocket),
                        "savestate" => save_state(message, &mut websocket),
                        "copystate" => copy_state(message, &mut websocket),
                        _ => {}
                    }
                }
            }
        });
    }
}

fn exit(websocket: &mut WebSocket<TcpStream>) {
    if let Ok(_) = websocket.close(None) {
        websocket.flush().unwrap();
    }
    println!("EXITING");
    // process::exit(0);
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

fn open_state(message: &str, websocket: &mut WebSocket<TcpStream>) {
    let args = split_args(message.to_string()).into_iter().skip(1);

    match commands::open(args) {
        Ok(json) => {
            let json = format_event!("openstate", json);
            websocket.send(Message::Text(json)).unwrap();
        }
        Err(e) => {
            let e = format_error!("openstate", e);
            websocket.send(Message::Text(e)).unwrap();
        }
    }
}

fn save_state(message: &str, websocket: &mut WebSocket<TcpStream>) {
    let args = split_args(message.to_string()).into_iter().skip(1);

    match commands::save(args) {
        Ok(_) => {
            let json = format_event!("savestate");
            websocket.send(Message::Text(json)).unwrap();
        }
        Err(e) => {
            let e = format_error!("savestate", e);
            websocket.send(Message::Text(e)).unwrap();
        }
    }
}

fn copy_state(message: &str, websocket: &mut WebSocket<TcpStream>) {
    let args = split_args(message.to_string()).into_iter().skip(1);

    match commands::copy_state(args) {
        Ok(_) => {
            let json = format_event!("copystate");
            websocket.send(Message::Text(json)).unwrap();
        }
        Err(e) => {
            let e = format_error!("copystate", e);
            websocket.send(Message::Text(e)).unwrap();
        }
    }
}
