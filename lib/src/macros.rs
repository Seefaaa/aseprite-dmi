#[macro_export]
macro_rules! format_event {
    ($event:expr) => {
        format!("{{\"event\":\"{}\"}}", $event)
    };
    ($event:expr, $data:expr) => {
        if let Some(data) = $data {
            format!("{{\"event\":\"{}\",\"data\":{}}}", $event, data)
        } else {
            format!("{{\"event\":\"{}\"}}", $event)
        }
    };
}

#[macro_export]
macro_rules! format_error {
    ($event:expr, $error:expr) => {
        format!("{{\"event\":\"{}\",\"error\":\"{}\"}}", $event, $error)
    };
}
