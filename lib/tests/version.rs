use dmi::check_latest_version;
use serde_json::Value;
use std::cmp::Ordering;
use std::env::current_dir;
use std::fs::read_to_string;

#[test]
fn check_version() {
    let crate_version = env!("CARGO_PKG_VERSION");

    let current_dir = current_dir().unwrap();
    let package = read_to_string(current_dir.join("../package.json")).unwrap();
    let package = serde_json::from_str::<Value>(&package).unwrap();

    let package_version = package["version"].as_str().unwrap();

    assert_eq!(crate_version, package_version);

    let version = check_latest_version().unwrap();

    match version {
        Ordering::Less | Ordering::Equal => panic!("Version is not updated after release!"),
        _ => {}
    }
}
