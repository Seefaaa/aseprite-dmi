use mlua::prelude::*;
use std::fs::{self, read_dir, remove_dir_all};
use std::path::Path;

use crate::dmi::{ClipboardState, Dmi, SerializedDmi, SerializedState, State};
use crate::utils::check_latest_release;

mod dmi;
mod utils;

fn new_file(
    lua: &Lua,
    (name, width, height, temp): (String, u32, u32, String),
) -> LuaResult<LuaTable> {
    let dmi = Dmi::new(name, width, height).to_serialized(temp, false)?;
    let table = dmi.into_lua_table(lua)?;

    Ok(table)
}

fn open_file(lua: &Lua, (filename, temp): (String, String)) -> LuaResult<LuaTable> {
    if !Path::new(&filename).is_file() {
        Err("File does not exist".to_string()).into_lua_err()?
    }

    let dmi = Dmi::open(filename)?.to_serialized(temp, false)?;
    let table: LuaTable<'_> = dmi.into_lua_table(lua)?;

    Ok(table)
}

fn save_file<'lua>(_: &'lua Lua, (dmi, filename): (LuaTable, String)) -> LuaResult<LuaValue<'lua>> {
    let dmi = SerializedDmi::from_lua_table(dmi)?;
    let dmi = Dmi::from_serialized(dmi)?;
    dmi.save(filename)?;

    Ok(LuaValue::Nil)
}

fn new_state(lua: &Lua, (width, height, temp): (u32, u32, String)) -> LuaResult<LuaTable> {
    if !Path::new(&temp).exists() {
        Err("Temp directory does not exist".to_string()).into_lua_err()?
    }

    let state = State::new_blank(String::default(), width, height).to_serialized(temp)?;
    let table = state.into_lua_table(lua)?;

    Ok(table)
}

fn copy_state<'lua>(_: &'lua Lua, (state, temp): (LuaTable, String)) -> LuaResult<LuaValue<'lua>> {
    if !Path::new(&temp).exists() {
        Err("Temp directory does not exist".to_string()).into_lua_err()?
    }

    let state = SerializedState::from_lua_table(state)?;
    let state = State::from_serialized(state, temp)?.into_clipboard()?;
    let state = serde_json::to_string(&state).map_err(ExternalError::Serde)?;

    let mut clipboard = arboard::Clipboard::new().map_err(ExternalError::Arboard)?;
    clipboard.set_text(state).map_err(ExternalError::Arboard)?;

    Ok(LuaValue::Nil)
}

fn paste_state(lua: &Lua, (width, height, temp): (u32, u32, String)) -> LuaResult<LuaTable> {
    if !Path::new(&temp).exists() {
        Err("Temp directory does not exist".to_string()).into_lua_err()?
    }

    let mut clipboard = arboard::Clipboard::new().map_err(ExternalError::Arboard)?;
    let state = clipboard.get_text().map_err(ExternalError::Arboard)?;
    let state = serde_json::from_str::<ClipboardState>(&state).map_err(ExternalError::Serde)?;
    let state = State::from_clipboard(state, width, height)?.to_serialized(temp)?;
    let table = state.into_lua_table(lua)?;

    Ok(table)
}

fn resize<'lua>(
    _: &'lua Lua,
    (dmi, width, height, method): (LuaTable, u32, u32, String),
) -> LuaResult<LuaValue<'lua>> {
    let dmi = SerializedDmi::from_lua_table(dmi)?;

    let temp = dmi.temp.clone();
    let method = match method.as_str() {
        "nearest" => image::imageops::FilterType::Nearest,
        "triangle" => image::imageops::FilterType::Triangle,
        "catmullrom" => image::imageops::FilterType::CatmullRom,
        "gaussian" => image::imageops::FilterType::Gaussian,
        "lanczos3" => image::imageops::FilterType::Lanczos3,
        _ => unreachable!(),
    };

    let mut dmi = Dmi::from_serialized(dmi)?;
    dmi.resize(width, height, method);
    dmi.to_serialized(temp, true)?;

    Ok(LuaValue::Nil)
}

fn crop<'lua>(
    _: &'lua Lua,
    (dmi, x, y, width, height): (LuaTable, u32, u32, u32, u32),
) -> LuaResult<LuaValue<'lua>> {
    let dmi = SerializedDmi::from_lua_table(dmi)?;
    let temp = dmi.temp.clone();

    let mut dmi = Dmi::from_serialized(dmi)?;
    dmi.crop(x, y, width, height);
    dmi.to_serialized(temp, true)?;

    Ok(LuaValue::Nil)
}

fn remove_dir(_: &Lua, (path, soft): (String, bool)) -> LuaResult<LuaValue> {
    let path = Path::new(&path);

    if path.is_dir() {
        if !soft {
            remove_dir_all(path)?;
        } else if read_dir(path)?.next().is_none() {
            fs::remove_dir(path)?;
        }
    }

    Ok(LuaValue::Nil)
}

fn exists(_: &Lua, path: String) -> LuaResult<bool> {
    let path = Path::new(&path);

    Ok(path.exists())
}

fn instances(_: &Lua, _: ()) -> LuaResult<usize> {
    let mut system = sysinfo::System::new();
    let refresh_kind =
        sysinfo::ProcessRefreshKind::new().with_exe(sysinfo::UpdateKind::OnlyIfNotSet);
    system.refresh_processes_specifics(refresh_kind);

    Ok(system.processes_by_name("aseprite").count())
}

fn check_update(_: &Lua, (): ()) -> LuaResult<bool> {
    let is_up_to_date = check_latest_release().unwrap_or(true);

    Ok(!is_up_to_date)
}

fn open_repo(_: &Lua, path: Option<String>) -> LuaResult<LuaValue> {
    let url = if let Some(path) = path {
        format!("{}/{}", env!("CARGO_PKG_REPOSITORY"), path)
    } else {
        env!("CARGO_PKG_REPOSITORY").to_string()
    };

    if webbrowser::open(&url).is_err() {
        return Err("Failed to open browser".to_string()).into_lua_err();
    }

    Ok(LuaValue::Nil)
}

fn safe_lua_function<'lua, A, R, F>(
    lua: &'lua Lua,
    func: F,
    multi: A,
) -> LuaResult<(Option<R>, Option<String>)>
where
    A: FromLuaMulti<'lua>,
    R: IntoLuaMulti<'lua>,
    F: Fn(&'lua Lua, A) -> LuaResult<R>,
{
    match func(lua, multi) {
        Ok(r) => Ok((Some(r), None)),
        Err(err) => Ok((None, Some(err.to_string()))),
    }
}

macro_rules! safe {
    ($func:ident) => {
        |lua, args| safe_lua_function(lua, $func, args)
    };
}

#[mlua::lua_module]
fn dmi_module(lua: &Lua) -> LuaResult<LuaTable> {
    let exports = lua.create_table()?;

    exports.set("new_file", lua.create_function(safe!(new_file))?)?;
    exports.set("open_file", lua.create_function(safe!(open_file))?)?;
    exports.set("save_file", lua.create_function(safe!(save_file))?)?;
    exports.set("new_state", lua.create_function(safe!(new_state))?)?;
    exports.set("copy_state", lua.create_function(safe!(copy_state))?)?;
    exports.set("paste_state", lua.create_function(safe!(paste_state))?)?;
    exports.set("resize", lua.create_function(safe!(resize))?)?;
    exports.set("crop", lua.create_function(safe!(crop))?)?;
    exports.set("remove_dir", lua.create_function(safe!(remove_dir))?)?;
    exports.set("exists", lua.create_function(exists)?)?;
    exports.set("check_update", lua.create_function(check_update)?)?;
    exports.set("open_repo", lua.create_function(safe!(open_repo))?)?;
    exports.set("instances", lua.create_function(instances)?)?;

    Ok(exports)
}

enum ExternalError {
    Arboard(arboard::Error),
    Serde(serde_json::Error),
}

impl mlua::ExternalError for ExternalError {
    fn into_lua_err(self) -> LuaError {
        match self {
            Self::Arboard(err) => err.into_lua_err(),
            Self::Serde(err) => err.into_lua_err(),
        }
    }
}

impl From<ExternalError> for mlua::Error {
    fn from(error: ExternalError) -> Self {
        error.into_lua_err()
    }
}

impl From<dmi::DmiError> for mlua::Error {
    fn from(error: dmi::DmiError) -> Self {
        error.into_lua_err()
    }
}

trait IntoLuaTable {
    fn into_lua_table(self, lua: &Lua) -> LuaResult<LuaTable>;
}

trait FromLuaTable {
    type Result;
    fn from_lua_table(table: LuaTable) -> LuaResult<Self::Result>;
}

impl IntoLuaTable for SerializedState {
    fn into_lua_table(self, lua: &Lua) -> LuaResult<LuaTable> {
        let table = lua.create_table()?;

        table.set("name", self.name)?;
        table.set("dirs", self.dirs)?;
        table.set("frame_key", self.frame_key)?;
        table.set("frame_count", self.frame_count)?;
        table.set("delays", self.delays)?;
        table.set("loop", self.loop_)?;
        table.set("rewind", self.rewind)?;
        table.set("movement", self.movement)?;
        table.set("hotspots", self.hotspots)?;

        Ok(table)
    }
}

impl IntoLuaTable for SerializedDmi {
    fn into_lua_table(self, lua: &Lua) -> LuaResult<LuaTable> {
        let table = lua.create_table()?;
        let mut states = Vec::new();

        for state in self.states.into_iter() {
            let table = state.into_lua_table(lua)?;
            states.push(table);
        }

        table.set("name", self.name)?;
        table.set("width", self.width)?;
        table.set("height", self.height)?;
        table.set("states", states)?;
        table.set("temp", self.temp)?;

        Ok(table)
    }
}

impl FromLuaTable for SerializedState {
    type Result = SerializedState;
    fn from_lua_table(table: LuaTable) -> LuaResult<Self::Result> {
        let name = table.get::<&str, String>("name")?;
        let dirs = table.get::<&str, u32>("dirs")?;
        let frame_key = table.get::<&str, String>("frame_key")?;
        let frame_count = table.get::<&str, u32>("frame_count")?;
        let delays = table.get::<&str, Vec<f32>>("delays")?;
        let loop_ = table.get::<&str, u32>("loop")?;
        let rewind = table.get::<&str, bool>("rewind")?;
        let movement = table.get::<&str, bool>("movement")?;
        let hotspots = table.get::<&str, Vec<String>>("hotspots")?;

        Ok(SerializedState {
            name,
            dirs,
            frame_key,
            frame_count,
            delays,
            loop_,
            rewind,
            movement,
            hotspots,
        })
    }
}

impl FromLuaTable for SerializedDmi {
    type Result = SerializedDmi;
    fn from_lua_table(table: LuaTable) -> LuaResult<Self::Result> {
        let name = table.get::<&str, String>("name")?;
        let width = table.get::<&str, u32>("width")?;
        let height = table.get::<&str, u32>("height")?;
        let states_table = table.get::<&str, Vec<LuaTable>>("states")?;
        let temp = table.get::<&str, String>("temp")?;

        let mut states = Vec::new();

        for table in states_table {
            states.push(SerializedState::from_lua_table(table)?);
        }

        Ok(SerializedDmi {
            name,
            width,
            height,
            states,
            temp,
        })
    }
}
