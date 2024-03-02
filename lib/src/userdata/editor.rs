use mlua::{AnyUserData, Lua, Nil, Result, UserData, UserDataFields, Value};

use crate::aseprite::{Dialog, GraphicsContext};
use crate::userdata::RefHolder;

pub struct Editor<'lua> {
    filename: String,
    dialog: RefHolder<'lua>,
    width: u32,
    height: u32,
}

impl<'a> Editor<'a> {
    pub fn open(lua: &'a Lua, filename: String) -> Result<Self> {
        let editor = Self {
            filename,
            width: 185,
            height: 215,
            dialog: RefHolder::new(lua)?,
        };

        editor.dialog.set(editor.create_dialog(lua)?)?;

        Ok(editor)
    }
    fn create_dialog<'lua>(&self, lua: &'lua Lua) -> Result<AnyUserData<'lua>> {
        let dialog = Dialog::create(lua, "Editor", Nil)?;
        let on_paint = lua.create_function(Self::on_paint)?;

        dialog.canvas(self.width, self.height, on_paint)?;
        dialog.button("Save", Nil)?;
        dialog.show(false)?;

        Ok(dialog.1)
    }
    fn on_paint(lua: &Lua, ctx: AnyUserData) -> Result<()> {
        let ctx = GraphicsContext(lua, &ctx);

        let text = "Loading file...";
        let (ctx_width, ctx_height) = ctx.size()?;
        let (text_width, text_height) = ctx.measure_text(text)?;

        ctx.fill_text(
            text,
            "text",
            (ctx_width - text_width) / 2,
            (ctx_height - text_height) / 2,
        )?;

        Ok(())
    }
}

impl<'a: 'static> UserData for Editor<'a> {
    fn add_fields<'lua, F: UserDataFields<'lua, Self>>(fields: &mut F) {
        fields.add_field_method_get("filename", |_, this| Ok(this.filename.clone()));
        fields.add_field_method_get("dialog", |_, this| {
            Ok(this.dialog.get::<Value>().unwrap_or(Nil))
        });
        fields.add_field_method_get("width", |_, this| Ok(this.width));
        fields.add_field_method_get("height", |_, this| Ok(this.height));
    }
}
