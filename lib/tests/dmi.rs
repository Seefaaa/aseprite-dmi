use std::fs::{remove_dir_all, remove_file};
use std::path::Path;

use dmi::Dmi;

#[test]
fn open_and_save() {
    let manifest_dir = Path::new(env!("CARGO_MANIFEST_DIR"));
    let sample_file = manifest_dir.join("tests/assets/anomaly.dmi");

    let dmi = Dmi::open(sample_file).unwrap();

    assert_eq!(dmi.name, "anomaly");
    assert_eq!(dmi.width, 32);
    assert_eq!(dmi.height, 32);
    assert_eq!(dmi.states.len(), 9);

    let state = &dmi.states[0];

    assert_eq!(state.name, "carp_rift");
    assert_eq!(state.dirs, 1);
    assert_eq!(state.frames.len(), 3);
    assert_eq!(state.frame_count, 3);
    assert_eq!(state.delays.len(), 3);
    assert_eq!(state.loop_, 0);

    assert!(!state.rewind);
    assert!(!state.movement);

    assert_eq!(state.hotspots.len(), 0);

    let frame = &state.frames[0];

    assert_eq!(frame.width(), 32);
    assert_eq!(frame.height(), 32);

    let delay = &state.delays[0];

    assert_eq!(delay, &2.0);

    let temp_dir = Path::new(env!("CARGO_TARGET_TMPDIR"));
    let temp_file = temp_dir.join("anomaly.dmi");

    if let Err(e) = dmi.save(&temp_file) {
        let _ = remove_file(temp_file);
        panic!("{e:?}");
    }

    let _ = remove_file(temp_file);
}

#[test]
fn serialize_and_deserialize() {
    let dmi = Dmi::open("tests/assets/anomaly.dmi").unwrap();

    let temp_dir = Path::new(env!("CARGO_TARGET_TMPDIR"));

    let serialized = dmi.to_serialized(temp_dir, false).unwrap();

    let temp = serialized.temp.clone();

    let deserialized = Dmi::from_serialized(serialized);

    let Ok(deserialized) = deserialized else {
        let _ = remove_dir_all(temp);
        panic!("{:?}", deserialized.unwrap_err());
    };

    let _ = remove_dir_all(temp);

    assert_eq!(dmi.name, deserialized.name);
    assert_eq!(dmi.width, deserialized.width);
    assert_eq!(dmi.height, deserialized.height);
    assert_eq!(dmi.states.len(), deserialized.states.len());

    let state = &dmi.states[0];
    let deserialized_state = &deserialized.states[0];

    assert_eq!(state.name, deserialized_state.name);
    assert_eq!(state.dirs, deserialized_state.dirs);
    assert_eq!(state.frames.len(), deserialized_state.frames.len());
    assert_eq!(state.frame_count, deserialized_state.frame_count);
    assert_eq!(state.delays.len(), deserialized_state.delays.len());
    assert_eq!(state.loop_, deserialized_state.loop_);
    assert_eq!(state.rewind, deserialized_state.rewind);
    assert_eq!(state.movement, deserialized_state.movement);
    assert_eq!(state.hotspots.len(), deserialized_state.hotspots.len());

    let frame = &state.frames[0];
    let deserialized_frame = &deserialized_state.frames[0];

    assert_eq!(frame.width(), deserialized_frame.width());
    assert_eq!(frame.height(), deserialized_frame.height());

    let delay = &state.delays[0];
    let deserialized_delay = &deserialized_state.delays[0];

    assert_eq!(delay, deserialized_delay);
}
