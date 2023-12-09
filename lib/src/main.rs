use serde_json;
use std::env;
use std::fs;
use std::path::Path;

use crate::dmi::{Dmi, SerializedDmi, State};

mod dmi;

fn main() {
    std::panic::set_hook(Box::new(|info| {
        println!("{}", info);
    }));

    let mut arguments = env::args().skip(1);
    let command = arguments.next().expect("No command provided");

    match command.as_str() {
        "OPEN" => {
            let file = arguments.next().expect("No input provided");
            let out_dir = arguments.next().expect("No output provided");

            let file = Path::new(&file);
            let output = Path::new(&out_dir);

            if file.exists() && file.is_file() {
                if output.extension().is_some() {
                    eprintln!("Output path must be a directory");
                    panic!("Output path must be a directory");
                }
                if !output.exists() {
                    fs::create_dir_all(output).expect("Failed to create output directory");
                }
                let dmi = Dmi::open(file).expect("Failed to open DMI file");
                let dmi = dmi.serialize(output).expect("Failed to save DMI");
                let json = serde_json::to_string(&dmi).expect("Failed to serialize");

                print!("{}", json);
            }
        }
        "SAVE" => {
            let path = arguments.next().expect("No path provided");
            let json = arguments.next().expect("No json path provided");

            let path = Path::new(&path);
            let json = Path::new(&json);

            if !json.exists() {
                panic!("Json file does not exist");
            }

            let dmi = fs::read_to_string(json).expect("Failed to read json file");

            let parent = path.parent();
            if parent.is_some_and(|p| !p.exists()) {
                fs::create_dir_all(parent.unwrap()).expect("Failed to create output directory");
            }

            let dmi =
                serde_json::from_str::<SerializedDmi>(dmi.as_str()).expect("Failed to parse data");

            if !Path::new(&dmi.temp).exists() {
                panic!("Temp directory does not exist");
            }

            let dmi = Dmi::deserialize(dmi).expect("Failed to deserialize DMI");

            dmi.save(path).expect("Failed to save DMI");
        }
        "NEW" => {
            let out_dir = arguments.next().expect("No output provided");
            let name = arguments.next().expect("No name provided");
            let width: u32 = arguments
                .next()
                .expect("No width provided")
                .parse()
                .expect("Failed to parse width");
            let height: u32 = arguments
                .next()
                .expect("No height provided")
                .parse()
                .expect("Failed to parse height");

            let out_dir = Path::new(&out_dir);

            if !out_dir.exists() {
                fs::create_dir_all(out_dir).expect("Failed to create output directory");
            }

            let dmi = Dmi::new(name, width, height);
            let dmi = dmi.serialize(out_dir).expect("Failed to serialize DMI");
            let json = serde_json::to_string(&dmi).expect("Failed to serialize");

            print!("{}", json);
        }
        "NEWSTATE" => {
            let temp = arguments.next().expect("No temp directory provided");
            let width: u32 = arguments
                .next()
                .expect("No width provided")
                .parse()
                .expect("Failed to parse width");
            let height: u32 = arguments
                .next()
                .expect("No height provided")
                .parse()
                .expect("Failed to parse height");

            let temp = Path::new(&temp);

            if !temp.exists() {
                panic!("Temp directory does not exist");
            }

            let state: State = State::new_blank(String::new(), width, height);
            let state = state.serialize(temp).expect("Failed to serialize state");
            let json = serde_json::to_string(&state).expect("Failed to serialize");

            print!("{}", json);
        }
        "RM" => {
            let dir = arguments.next().expect("No directory provided");
            let dir = Path::new(&dir);

            if dir.exists() {
                fs::remove_dir_all(dir).expect("Failed to remove directory");
            }
        }
        _ => panic!("Unknown command"),
    }
}
