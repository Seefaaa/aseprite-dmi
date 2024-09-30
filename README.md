> [!WARNING]
> ⚠ I'm no longer maintaining this project, It's likely to be broken and not working properly. ⚠

# DMI Editor for Aseprite

This project is a DMI (BYOND's Dream Maker icon files) editor extension for Aseprite, a popular pixel art tool. It is written in Rust and Lua and aims to enhance the Aseprite experience by providing tools for editing and managing DMI files.

## Download

The latest version of this extension is available for download from the [Releases](https://github.com/Seefaaa/aseprite-dmi/releases) page on the project's GitHub repository.

## Usage

Once the project has been downloaded or built, the extension can be added to Aseprite by dragging and dropping it into the application or by selecting the 'Add Extension' button in the 'Edit > Preferences > Extensions' menu.

DMI files can now be opened in Aseprite in the same way as any other file format.

### Creating New Files

New files can be created via the following pathway: `File > DMI Editor > New DMI File`.

### Changing State Properties

The state properties, including the state name, can be modified by right clicking on the state or by clicking on the text below the state in the editor.

### Copy and Paste

Right-clicking on the state will bring up the context menu. The context menu allows the user to copy the state to the clipboard, which can then be pasted at a later stage. Right click on an empty space within the editor to paste the copied state. The states are copied in the JSON format, with PNG images, which are base64-encoded, included for the frames.

### Frames and Delays

In Aseprite's timeline, new frames can be added and delays between frames can be modified.

### Expand, Resize, Crop

The DMI file may be expanded, resized, or cropped via the `File > DMI Editor` menu. It should be noted that the active sprite must be a DMI state in order to utilise these commands.

## Building the Project

### Requirements

- [Rust](https://www.rust-lang.org/)
- [Python](https://www.python.org/) (build script)

To build the project, run `tools/build.py` Python script.

## Contact

For any questions or further discussion, feel free to contact me on Discord at `Seefaaa`.
