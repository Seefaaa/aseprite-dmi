use mlua::{chunk, AnyUserData, IntoLua, Lua, Result};

pub struct Dialog<'lua>(pub &'lua Lua, pub AnyUserData<'lua>, pub AnyUserData<'lua>);

impl<'lua> Dialog<'lua> {
    pub fn create<F>(
        lua: &'lua Lua,
        editor: AnyUserData<'lua>,
        title: &str,
        on_close: F,
    ) -> Result<Self>
    where
        F: IntoLua<'lua>,
    {
        let title = title.into_lua(lua)?;
        let dialog = lua
            .load(chunk! {
                    return Dialog {
                            title = $title,
                            onclose = $on_close,
                    }
            })
            .eval::<AnyUserData>()?;

        Ok(Self(lua, dialog, editor))
    }
    pub fn canvas(
        &self,
        width: u32,
        height: u32,
        on_paint: impl IntoLua<'lua>,
        on_mouse_move: impl IntoLua<'lua>,
    ) -> Result<()> {
        let dialog = &self.1;
        let editor = &self.2;
        self.0
            .load(chunk! {
                    local dialog = $dialog
                    local editor = $editor
                    local on_paint = $on_paint
                    dialog:canvas {
                            width = $width,
                            height = $height,
                            onpaint = on_paint and function(ev) on_paint(editor, ev.context) end or nil,
                            onmousemove = $on_mouse_move,
                    }
            })
            .exec()?;
        Ok(())
    }
    pub fn button<F>(&self, text: &str, on_click: F) -> Result<()>
    where
        F: IntoLua<'lua>,
    {
        let dialog = &self.1;
        self.0
            .load(chunk! {
                    local dialog = $dialog
                    local onclick = $on_click
                    dialog:button {
                            text = $text,
                            onclick = onclick and function(ev) onclick(ev.context) end or nil,
                    }
            })
            .exec()?;
        Ok(())
    }
    pub fn show(&self, wait: bool) -> Result<()> {
        let dialog = &self.1;
        self.0
            .load(chunk! {
                    local dialog = $dialog
                    dialog:show { wait = $wait }
            })
            .exec()?;
        Ok(())
    }
    pub fn _close(&self) -> Result<()> {
        let dialog = &self.1;
        self.0
            .load(chunk! {
                    local dialog = $dialog
                    dialog:close()
            })
            .exec()?;
        Ok(())
    }
}
