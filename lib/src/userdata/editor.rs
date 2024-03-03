use mlua::{AnyUserData, Lua, Nil, Result, UserData, UserDataFields, Value};

use crate::aseprite::{Dialog, GraphicsContext, MouseButton, MouseEvent};
use crate::userdata::RefHolder;

const EDITOR_WIDTH: u32 = 185;
const EDITOR_HEIGHT: u32 = 215;

pub struct Editor<'lua> {
    this: Option<AnyUserData<'lua>>,
    filename: String,
    width: u32,
    height: u32,
    dialog: RefHolder<'lua>,
    #[allow(dead_code)]
    mouse: Mouse,
}

impl<'a: 'static> Editor<'a> {
    fn this(&self) -> Result<AnyUserData<'a>> {
        self.this.as_ref().unwrap().borrow::<RefHolder>()?.get()
    }
    pub fn open(lua: &'a Lua, filename: String) -> Result<AnyUserData<'a>> {
        let great_ref_holder = RefHolder::new(lua)?;
        great_ref_holder.set(RefHolder::new(lua)?)?;

        let ref_holder = great_ref_holder.get::<AnyUserData>()?;
        let ref_holder = ref_holder.borrow::<RefHolder>()?;

        let editor = Editor {
            this: None,
            filename,
            width: EDITOR_WIDTH,
            height: EDITOR_HEIGHT,
            dialog: RefHolder::new(lua)?,
            mouse: Mouse::default(),
        };

        ref_holder.set(editor)?;

        let editor = ref_holder.get::<AnyUserData>()?;
        let mut editor = editor.borrow_mut::<Editor>()?;

        editor.this = Some(great_ref_holder.get()?);
        editor
            .dialog
            .set(editor.create_dialog(lua, EDITOR_WIDTH, EDITOR_HEIGHT)?)?;

        great_ref_holder.get()
    }
    fn create_dialog<'lua>(
        &self,
        lua: &'lua Lua,
        width: u32,
        height: u32,
    ) -> Result<AnyUserData<'lua>> {
        let dialog = Dialog::create(lua, "Editor", Nil)?;

        let on_paint = lua.create_function(Self::on_paint)?;

        let this = self.this()?;
        let on_mouse_move = lua.create_function(move |lua, ev| {
            let mut this = this.borrow_mut::<Editor>()?;
            this.on_mouse_move(lua, ev)
        })?;

        dialog.canvas(width, height, on_paint, on_mouse_move)?;
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
    fn on_mouse_down(&mut self, _: &Lua, _: MouseEvent) -> Result<()> {
        //
        Ok(())
    }
    fn on_mouse_up(&mut self, _: &Lua, event: MouseEvent) -> Result<()> {
        self.mouse.x = event.x;
        self.mouse.y = event.y;
        match event.button {
            MouseButton::Left => self.mouse.left = false,
            MouseButton::Right => self.mouse.right = false,
            _ => {}
        }
        Ok(())
    }
    fn on_mouse_move(&mut self, _: &Lua, ev: MouseEvent) -> Result<()> {
        self.mouse.x = ev.x;
        self.mouse.y = ev.y;
        Ok(())
    }
    fn on_wheel(&mut self, _: &Lua, _: MouseEvent) -> Result<()> {
        //
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

#[derive(Default)]
struct Mouse {
    x: u32,
    y: u32,
    left: bool,
    right: bool,
}
