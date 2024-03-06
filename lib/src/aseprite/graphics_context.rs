use mlua::{chunk, AnyUserData, Lua, Result};

pub struct GraphicsContext<'lua>(pub &'lua Lua, pub &'lua AnyUserData<'lua>);

impl<'lua> GraphicsContext<'lua> {
    pub fn size(&self) -> Result<(i32, i32)> {
        let ctx = self.1;
        self.0
            .load(chunk! {
                local ctx = $ctx
                return ctx.width, ctx.height
            })
            .eval()
    }
    pub fn measure_text(&self, text: &str) -> Result<(i32, i32)> {
        let ctx = self.1;
        self.0
            .load(chunk! {
                local ctx = $ctx
                local size = ctx:measureText($text)
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
}
