use image::DynamicImage;
use mlua::UserData;

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
}
