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

            println!("pid:{}", process::id());

            loop {
                let message = websocket.read();

                if message.is_err() {
                    exit(&mut websocket);
                }

                let message = message.unwrap();

                if message.is_close() {
                    exit(&mut websocket);
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

fn open_state(message: &str, websocket: &mut WebSocket<TcpStream>) {
    let args = split_args(message.to_string()).into_iter();

    match commands::open(args) {
        Ok(json) => {
            let json = format_event!("openstate", json);
            println!("OUTGOING {}", json);
            websocket.send(Message::Text(json)).unwrap();
        }
        Err(e) => {
            let e = format_error!("openstate", e);
            println!("OUTGOING ERROR {}", e);
            websocket.send(Message::Text(e)).unwrap();
        }
    }
}

fn save_state(message: &str, websocket: &mut WebSocket<TcpStream>) {
    let args = split_args(message.to_string()).into_iter();

    match commands::save(args) {
        Ok(_) => {
            let json = format_event!("savestate");
            println!("OUTGOING {}", json);
            websocket.send(Message::Text(json)).unwrap();
        }
        Err(e) => {
            let e = format_error!("savestate", e);
            println!("OUTGOING ERROR {}", e);
            websocket.send(Message::Text(e)).unwrap();
        }
    }
}
