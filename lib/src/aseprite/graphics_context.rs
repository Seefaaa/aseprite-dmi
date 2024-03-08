use mlua::{chunk, AnyUserData, Lua, Result};

pub struct GraphicsContext<'lua>(pub &'lua Lua, pub &'lua AnyUserData<'lua>);

impl<'lua> GraphicsContext<'lua> {
    pub fn size(&self) -> Result<(u32, u32)> {
        let ctx = self.1;
        self.0
            .load(chunk! {
                local ctx = $ctx
                return ctx.width, ctx.height
            })
            .eval()
    }
    pub fn measure_text(&self, text: &str) -> Result<(u32, u32)> {
        let ctx = self.1;
        self.0
            .load(chunk! {
                local size = $ctx:measureText($text)
                return size.width, size.height
            })
            .eval()
    }
    pub fn fill_text(&self, text: &str, color: &str, x: i32, y: i32) -> Result<()> {
        let ctx = self.1;
        let color = color.to_string();
        self.0
            .load(chunk! {
                local ctx = $ctx
                ctx.color = app.theme.color[$color]
                ctx:fillText($text, $x, $y)
            })
            .exec()?;
        Ok(())
    }
    pub fn draw_image(&self, image: &AnyUserData, x: i32, y: i32) -> Result<()> {
        let ctx = self.1;
        self.0
            .load(chunk! {
                local image = $image
                $ctx:drawImage(image, image.bounds, Rectangle($x, $y, image.bounds.width, image.bounds.height))
            })
            .exec()?;
        Ok(())
    }
    pub fn draw_theme_rect(
        &self,
        part: &str,
        x: i32,
        y: i32,
        width: u32,
        height: u32,
    ) -> Result<()> {
        let ctx = self.1;
        let part = part.to_string();
        self.0
            .load(chunk! {
                $ctx:drawThemeRect($part, Rectangle($x, $y, $width, $height))
            })
            .exec()?;
        Ok(())
    }
}
