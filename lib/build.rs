#[cfg(windows)]
fn main() {
    use winres::WindowsResource;
    let res = WindowsResource::new();
    res.compile().unwrap();
}
