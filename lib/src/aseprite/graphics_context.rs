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
            .eval::<(u32, u32)>()
    }
    pub fn measure_text(&self, text: &str) -> Result<(u32, u32)> {
        let ctx = self.1;
        self.0
            .load(chunk! {
                local ctx = $ctx
                local size = ctx:measureText($text)
                return size.width, size.height
            })
            .eval::<(u32, u32)>()
    }
    pub fn fill_text(&self, text: &str, color: &str, x: u32, y: u32) -> Result<()> {
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
}
