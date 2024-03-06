use mlua::{
    AnyUserData, AnyUserDataExt, Function, Lua, Nil, Result, UserData, UserDataFields,
    UserDataMethods, Value,
};

use crate::aseprite::{Dialog, GraphicsContext, MouseButton, MouseEvent};
use crate::userdata::{Dmi, RefHolder};

pub struct Editor<'lua> {
    filename: String,
    width: u32,
    height: u32,
    dialog: RefHolder<'lua>,
    dmi: RefHolder<'lua>,
    mouse: Mouse,
}

impl<'a: 'static> Editor<'a> {
    pub fn open(lua: &'a Lua, filename: String) -> Result<AnyUserData<'a>> {
        let editor = lua.create_userdata(Self {
            filename: filename.clone(),
            width: 185,
            height: 215,
            dialog: RefHolder::new(lua)?,
            dmi: RefHolder::new(lua)?,
            mouse: Mouse::default(),
        })?;

        {
            let editor = editor.borrow::<Editor>()?;
            editor.dmi.set(Dmi::open(lua, filename)?)?;
        }

        {
            let dialog = editor.call_method::<_, AnyUserData>("create_dialog", ())?;
            let editor = editor.borrow::<Editor>()?;
            editor.dialog.set(dialog)?;
        }

        Ok(editor)
    }
    fn create_dialog<'lua>(lua: &'lua Lua, this: AnyUserData) -> Result<AnyUserData<'lua>> {
        let ref_holder = RefHolder::new(lua)?;
        ref_holder.set(this)?;

        let this = ref_holder.get::<AnyUserData>()?;

        let width = this.get::<_, u32>("width")?;
        let height = this.get::<_, u32>("height")?;

        let dialog = Dialog::create(lua, this, "Editor", Nil)?;

        let this = ref_holder.get::<AnyUserData>()?;
        let on_paint = this.get::<_, Function>("on_paint")?;
        let on_mouse_move = this.get::<_, Function>("on_mouse_move")?;

        dialog.canvas(width, height, on_paint, on_mouse_move)?;
        dialog.button("Save", Nil)?;
        dialog.show(false)?;

        Ok(dialog.1)
    }
    fn on_paint(lua: &Lua, (this, ctx): (AnyUserData, AnyUserData)) -> Result<()> {
        let this = this.borrow::<Editor>()?;
        let ctx = GraphicsContext(lua, &ctx);

        let dmi = this.dmi.get::<Value>()?;

        if let Value::UserData(dmi) = dmi {
            let dmi = dmi.borrow::<Dmi>()?;
            let (ctx_width, ctx_height) = ctx.size()?;
            let (name_width, name_height) = ctx.measure_text(&dmi.name)?;
            ctx.fill_text(
                &dmi.name,
                "text",
                (ctx_width - name_width) / 2,
                (ctx_height - name_height) / 2,
            )?
        }

        Ok(())
    }
    fn on_mouse_move(_: &Lua, (this, event): (AnyUserData, MouseEvent)) -> Result<()> {
        let mut this = this.borrow_mut::<Editor>()?;
        this.mouse.x = event.x;
        this.mouse.y = event.y;
        Ok(())
    }
}

impl UserData for Editor<'static> {
    fn add_fields<'lua, F: UserDataFields<'lua, Self>>(fields: &mut F) {
        fields.add_field_method_get("filename", |_, this| Ok(this.filename.clone()));
        fields.add_field_method_get("width", |_, this| Ok(this.width));
        fields.add_field_method_get("height", |_, this| Ok(this.height));
        fields.add_field_method_get("dialog", |_, this| {
            Ok(this.dialog.get::<Value>().unwrap_or(Nil))
        });
        fields.add_field_method_get("dmi", |_, this| Ok(this.dmi.get::<Value>().unwrap_or(Nil)));
    }
    fn add_methods<'lua, M: UserDataMethods<'lua, Self>>(methods: &mut M) {
        methods.add_function_mut("create_dialog", Self::create_dialog);
        methods.add_function_mut("on_paint", Self::on_paint);
        methods.add_function_mut("on_mouse_move", Self::on_mouse_move);
    }
}

#[derive(Default)]
struct Mouse {
    x: u32,
    y: u32,
    left: bool,
    right: bool,
}
