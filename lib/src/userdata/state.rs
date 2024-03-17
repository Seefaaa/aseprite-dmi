use image::{imageops, DynamicImage, ImageBuffer, Rgba};
use mlua::{AnyUserData, MetaMethod, MultiValue, Table, UserData, UserDataFields, UserDataMethods};
use std::{cell::RefCell, rc::Rc};

use crate::errors::ExternalError;

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
    fn add_fields<'lua, F: UserDataFields<'lua, Self>>(fields: &mut F) {
        fields.add_field_method_get("name", |_, this| Ok(this.name.clone()));
        fields.add_field_method_get("dirs", |_, this| Ok(this.dirs));
        // fields.add_field_method_get("frames", |_, this| Ok(this.frames.clone()));
        fields.add_field_method_get("frame_count", |_, this| Ok(this.frame_count));
        fields.add_field_method_get("delays", |_, this| Ok(this.delays.clone()));
        fields.add_field_method_get("loop", |_, this| Ok(this.r#loop));
        fields.add_field_method_get("rewind", |_, this| Ok(this.rewind));
        fields.add_field_method_get("movement", |_, this| Ok(this.movement));

        fields.add_field_method_set("frame_count", |_, this, value: u32| {
            this.frame_count = value;
            Ok(())
        });
        fields.add_field_method_set("delays", |_, this, value: Table| {
            let mut delays = Vec::new();

            for delay in value.sequence_values() {
                delays.push(delay?);
            }

            this.delays = delays;

            Ok(())
        });
    }
    fn add_methods<'lua, M: UserDataMethods<'lua, Self>>(methods: &mut M) {
        methods.add_meta_function(
            MetaMethod::Eq,
            |_, (this, other): (AnyUserData, AnyUserData)| {
                let this = this.borrow::<Rc<RefCell<State>>>()?;
                let other = other.borrow::<Rc<RefCell<State>>>()?;

                Ok(Rc::ptr_eq(&this, &other))
            },
        );
        methods.add_method("preview", |lua, this, (r, g, b): (u8, u8, u8)| {
            let frame = &this.frames[0];

            let mut bottom =
                ImageBuffer::from_pixel(frame.width(), frame.height(), Rgba([r, g, b, 255]));
            imageops::overlay(&mut bottom, frame, 0, 0);

            lua.create_string(image_to_bytes(bottom))
        });
        methods.add_method("frame", |lua, this, index: usize| {
            let frame = &this.frames[index];

            lua.create_string(image_to_bytes(frame.to_rgba8()))
        });
        methods.add_method_mut(
            "set_frame",
            |_, this, (index, width, height, bytes): (usize, u32, u32, MultiValue)| {
                let bytes = bytes
                    .into_iter()
                    .map(|v| v.as_u32().unwrap_or(0) as u8)
                    .collect::<Vec<_>>();
                let image = bytes_to_image(bytes, width, height)?;

                if index >= this.frames.len() {
                    this.frames
                        .resize(index + 1, DynamicImage::new_rgba8(width, height));
                }

                this.frames[index] = DynamicImage::ImageRgba8(image);

                Ok(())
            },
        );
    }
}

fn image_to_bytes(image: ImageBuffer<Rgba<u8>, Vec<u8>>) -> Vec<u8> {
    let mut bytes = Vec::with_capacity((image.width() * image.height() * 4) as usize);

    for pixel in image.pixels() {
        bytes.push(pixel[0]);
        bytes.push(pixel[1]);
        bytes.push(pixel[2]);
        bytes.push(pixel[3]);
    }

    bytes
}

fn bytes_to_image(
    bytes: Vec<u8>,
    width: u32,
    height: u32,
) -> Result<ImageBuffer<Rgba<u8>, Vec<u8>>, ExternalError> {
    ImageBuffer::from_vec(width, height, bytes).ok_or(ExternalError::SizeMismatch)
}
