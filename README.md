# DMI Editor for Aseprite

This project is a DMI (BYOND's Dream Maker icon files) editor extension for Aseprite, a popular pixel art tool. It is built with Rust and Lua, and is designed to enhance the Aseprite experience by providing tools for editing and managing DMI files.

## Download

You can download the ready-to-use version of this extension from the [Releases](https://github.com/Seefaaa/aseprite-dmi/releases) page on the project's GitHub repository.

## Usage

After downloading or building the project, you can add the extension to Aseprite by dragging and dropping it into Aseprite or by using `Add Extension` button in `Edit > Preferences > Extensions`.

You can now open DMI files in Aseprite just like other file formats.

### Creating New Files

You can create new files in `File > DMI Editor > New DMI File`

### Changing State Properties

You can change properties of states like state name by right clicking the state or clicking the text below state in the editor.

### Copying and Pasting

You can right click the state to open the context menu. In context menu you can `Copy` state to the clipboard and paste in anywhere. States are copied in `JSON` format with `base64` encoded png-s for frames.

Right click to empty space in the editor to paste the state you copied.

### Frames and Delays

In Aseprite's timeline you can add new frames and change the delays between frames.

### Expanding, Resizing, Cropping

You can `Expand`, `Resize`, and `Crop` DMI files in `File > DMI Editor`. The active sprite must be a state of an editor to use these commands.

## Building the Project

### Requirements

- [Rust](https://www.rust-lang.org/)

### Windows

To build the project, execute the `build.cmd` file or run `build` or `build --release` in the command line.

## Contact

For any questions or further discussion, feel free to reach out to me on Discord at `Seefaaa`.
