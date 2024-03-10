use image::{imageops, DynamicImage, ImageBuffer, Rgba};
use mlua::UserData;

#[derive(Debug)]
pub struct State {
    pub name: String,
    pub dirs: u8,
    pub frames: Vec<DynamicImage>,
    pub frame_count: u32,
    pub delays: Vec<f32>,
    pub r#loop: u32,
    pub rewind: bool,
    pub movement: bool,
    pub hotspots: Vec<String>,
}

impl State {
    pub fn new(name: String) -> Self {
        Self {
            name,
            dirs: 1,
            frames: Vec::new(),
            frame_count: 0,
            delays: Vec::new(),
            r#loop: 0,
            rewind: false,
            movement: false,
            hotspots: Vec::new(),
        }
    }
}

impl UserData for State {
    fn add_fields<'lua, F: mlua::prelude::LuaUserDataFields<'lua, Self>>(fields: &mut F) {
        fields.add_field_method_get("name", |_, this| Ok(this.name.clone()));
        fields.add_field_method_get("dirs", |_, this| Ok(this.dirs));
        // fields.add_field_method_get("frames", |_, this| Ok(this.frames.clone()));
        fields.add_field_method_get("frame_count", |_, this| Ok(this.frame_count));
        fields.add_field_method_get("delays", |_, this| Ok(this.delays.clone()));
        fields.add_field_method_get("loop", |_, this| Ok(this.r#loop));
        fields.add_field_method_get("rewind", |_, this| Ok(this.rewind));
        fields.add_field_method_get("movement", |_, this| Ok(this.movement));
    }
    fn add_methods<'lua, M: mlua::prelude::LuaUserDataMethods<'lua, Self>>(methods: &mut M) {
        methods.add_method("preview", |lua, this, (r, g, b): (u8, u8, u8)| {
            let frame = &this.frames[0];

            let mut bottom =
                ImageBuffer::from_pixel(frame.width(), frame.height(), Rgba([r, g, b, 255]));
            imageops::overlay(&mut bottom, frame, 0, 0);

            let bytes = image_to_bytes(&DynamicImage::ImageRgba8(bottom));
            let string = lua.create_string(&bytes)?;

            Ok(string)
        });
    }
}

fn image_to_bytes(image: &DynamicImage) -> Vec<u8> {
    let mut bytes = Vec::with_capacity((image.width() * image.height() * 4) as usize);

    for pixel in image.to_rgba8().pixels() {
        bytes.push(pixel[0]);
        bytes.push(pixel[1]);
        bytes.push(pixel[2]);
        bytes.push(pixel[3]);
    }

    bytes
}
