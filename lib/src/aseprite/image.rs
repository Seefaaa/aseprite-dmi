use image::DynamicImage;
use mlua::{chunk, AnyUserData, Function, Lua, Result};

pub struct Image<'lua>(&'lua Lua, pub AnyUserData<'lua>);

impl<'lua> Image<'lua> {
    pub fn create(lua: &'lua Lua, width: u32, height: u32) -> Result<Self> {
        let constructor = lua.globals().get::<_, Function>("Image")?;
        let image = constructor.call((width, height))?;
        Ok(Self(lua, image))
    }
    pub fn set_image(&self, image: &DynamicImage) -> Result<()> {
        let bytes = self.0.create_string(image_to_bytes(image))?;
        let image = &self.1;
        self.0
            .load(chunk! {
                    local image = $image
                    image.bytes = $bytes
            })
            .exec()?;
        Ok(())
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
