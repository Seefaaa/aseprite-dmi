use mlua::{
    AnyUserData, AnyUserDataExt, ExternalResult, Function, Lua, Nil, Result, Table, UserData,
    UserDataFields, UserDataMethods, Value,
};
use std::cmp::max;

use crate::aseprite::{Dialog, GraphicsContext, Image, MouseButton, MouseEvent};
use crate::macros::safe_function;
use crate::userdata::{Dmi, RefHolder};

use super::State;

const PADDING: u32 = 3;

#[derive(Debug)]
pub struct Editor<'lua> {
    lua: &'lua Lua,
    filename: String,
    width: u32,
    height: u32,
    dialog: RefHolder<'lua>,
    dmi: RefHolder<'lua>,
    mouse: Mouse,
    widgets: Vec<Widget<'lua>>,
}

impl<'a: 'static> Editor<'a> {
    pub fn open(lua: &'a Lua, filename: String) -> Result<AnyUserData<'a>> {
        let editor = lua.create_userdata(Self {
            lua,
            filename: filename.clone(),
            width: 185,
            height: 215,
            dialog: RefHolder::new(lua)?,
            dmi: RefHolder::new(lua)?,
            mouse: Mouse::default(),
            widgets: Vec::new(),
        })?;

        {
            let editor = editor.borrow::<Editor>()?;
            editor.dmi.set(Dmi::open(lua, filename)?)?;
        }

        {
            match editor.call_method("create_dialog", ())? {
                Value::UserData(dialog) => {
                    let editor = editor.borrow::<Editor>()?;
                    editor.dialog.set(dialog)?;
                }
                _ => return Err("Failed to create dialog".to_string()).into_lua_err(),
            }
        }

        Ok(editor)
    }
    fn create_dialog<'lua>(lua: &'lua Lua, this: AnyUserData) -> Result<AnyUserData<'lua>> {
        let ref_holder = RefHolder::new(lua)?;
        ref_holder.set(this)?;

        let this = ref_holder.get::<AnyUserData>()?;
        let dialog = Dialog::create(lua, this, "Editor", Nil)?;

        let this = ref_holder.get::<AnyUserData>()?;
        let width = this.get::<_, u32>("width")?;
        let height = this.get::<_, u32>("height")?;
        let on_paint = this.get::<_, Function>("on_paint")?;
        let on_mouse_move = this.get::<_, Function>("on_mouse_move")?;

        dialog.canvas(width, height, on_paint, on_mouse_move)?;
        dialog.button("Save", Nil)?;
        dialog.show(false)?;

        Ok(dialog.1)
    }
    fn on_paint(lua: &Lua, (this, ctx): (AnyUserData, AnyUserData)) -> Result<()> {
        let mut this = this.borrow_mut::<Editor>()?;
        let ctx = GraphicsContext(lua, &ctx);

        if let Value::UserData(dmi) = this.dmi.get::<Value>()? {
            let (canvas_width, canvas_height) = ctx.size()?;
            let dmi = dmi.borrow::<Dmi>()?;

            this.width = canvas_width;
            this.height = canvas_height;

            if this.widgets.is_empty() {
                this.create_widgets()?;
            }

            for widget in this.widgets.iter() {
                match widget {
                    Widget::_Text(text, color, x, y) => {
                        ctx.fill_text(text, color, *x, *y)?;
                    }
                    Widget::State(image, x, y) => {
                        ctx.draw_theme_rect(
                            "sunken_normal",
                            *x,
                            *y,
                            dmi.width + 4,
                            dmi.height + 4,
                        )?;
                        ctx.draw_image(image, x + 2, y + 2)?;
                    }
                }
            }
        }

        Ok(())
    }
    fn create_widgets(&mut self) -> Result<()> {
        self.widgets.clear();

        if let Value::UserData(dmi) = self.dmi.get::<Value>()? {
            let dmi = dmi.borrow::<Dmi>()?;
            let states = dmi.states.get::<Table>()?;

            let max_rows = max(self.width / dmi.width, 1);
            let max_columns = max(self.height / dmi.height, 1);
            let max_states = max_rows * (max_columns + 1);

            states.for_each(|index: u32, state: AnyUserData| {
                let index = index - 1;
                if index <= max_states {
                    let state = state.borrow::<State>()?;

                    let width = dmi.width + 2 + PADDING;
                    let height = dmi.height + 2 + PADDING;
                    let x = width * (index % max_rows) + 1;
                    let y = height * (index / max_rows) + 1;

                    let image = Image::create(self.lua, dmi.width, dmi.height)?;
                    let Some(frame) = state.frames.first() else {
                        return Err("There is a state with no frames".to_string()).into_lua_err();
                    };
                    image.set_image(frame)?;

                    self.widgets
                        .push(Widget::State(image.1, x as i32, y as i32));
                }
                Ok(())
            })?;
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
        methods.add_function_mut("create_dialog", safe_function!(Self::create_dialog));
        methods.add_function_mut("on_paint", safe_function!(Self::on_paint));
        methods.add_function_mut("on_mouse_move", safe_function!(Self::on_mouse_move));
    }
}

#[derive(Debug, Default)]
struct Mouse {
    x: u32,
    y: u32,
    _left: bool,
    _right: bool,
}

#[derive(Debug)]
pub enum Widget<'lua> {
    State(AnyUserData<'lua>, i32, i32),
    _Text(String, String, i32, i32),
}
