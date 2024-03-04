#!/usr/bin/python
import os
import shutil
import subprocess
import urllib.request
import urllib.error
import zipfile

EXTENSION_NAME = "aseprite-dmi"
LIBRARY_NAME = "dmi"
TARGET = "debug"
CI = False
REPLACE = False

import sys
args = sys.argv[1:]

if "--release" in args:
    TARGET = "release"
elif "--ci" in args:
    try:
        index = args.index("--ci")
        TARGET = args[index + 1]
        CI = True
    except IndexError:
        print("Error: Please provide a target name after --ci flag.")
        sys.exit(1)

win = sys.platform.startswith('win')

if "--replace" in args:
    REPLACE = True
    extensions_dir = os.path.join(os.getenv("APPDATA"), "Aseprite", "extensions") if win else os.path.join(os.getenv("HOME"), ".config", "aseprite", "extensions")

working_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
os.chdir(working_dir)

if not CI:
    try:
        rust_version_output = subprocess.check_output(["rustc", "--version"]).decode()
    except FileNotFoundError:
        print("Error: Rust is not installed.")
        sys.exit(1)
    os.chdir(os.path.join(working_dir, "lib"))
    try:
        print("Building main library...")
        if TARGET == "debug":
            subprocess.run(["cargo", "build"], check=True)
        else:
            subprocess.run(["cargo", "build", "--release"], check=True)
    except subprocess.CalledProcessError:
        print("Error: lib build failed. Please check for errors.")
        sys.exit(1)

os.chdir(working_dir)

if win:
    library_extension = ".dll"
    library_prefix = ""
elif sys.platform.startswith('darwin'):
    library_extension = ".dylib"
    library_prefix = "lib"
else:
    library_extension = ".so"
    library_prefix = "lib"

library_source = os.path.join("lib", "target", TARGET if not CI else os.path.join(TARGET, "release"), f"{library_prefix}{LIBRARY_NAME}{library_extension}")

if not os.path.exists(library_source):
    print("Error: lib was not built. Please check for errors.")
    sys.exit(1)

if win:
    lua_library = f"{library_prefix}lua54{library_extension}"
    if not os.path.exists(lua_library):
        print("Lua library not found. Downloading...")
        zip_path = os.path.join(working_dir, "lua54.zip")
        try:
            url = "https://netix.dl.sourceforge.net/project/luabinaries/5.4.2/Windows%20Libraries/Dynamic/lua-5.4.2_Win64_dllw6_lib.zip"
            urllib.request.urlretrieve(url, zip_path)
        except urllib.error.URLError as e:
            if os.path.exists(zip_path):
                os.remove(zip_path)
            print(f"Could not download lua library. Please check your internet connection and try again.")
            print(f"Error details: {e}")
            sys.exit(1)
        else:
            with zipfile.ZipFile(zip_path, "r") as zip_ref:
                zip_ref.extract(lua_library, working_dir)
            os.remove(zip_path)

dist_dir = os.path.join(working_dir, "dist")
unzipped_dir = os.path.join(dist_dir, "unzipped")

if os.path.exists(dist_dir):
    shutil.rmtree(dist_dir)

os.makedirs(dist_dir)
os.makedirs(unzipped_dir)

shutil.copy("package.json", unzipped_dir)
shutil.copy("LICENSE", unzipped_dir)
shutil.copy("README.md", unzipped_dir)
shutil.copy(library_source, unzipped_dir)

if win:
    shutil.copy(lua_library, unzipped_dir)

shutil.copytree(os.path.join("scripts"), os.path.join(unzipped_dir, "scripts"))

if CI:
    if TARGET.find("windows") != -1:
        target_name = "-windows"
    elif TARGET.find("linux") != -1:
        target_name = "-linux"
    elif TARGET.find("darwin") != -1:
        target_name = "-macos"
else:
    target_name = ""

zip_path = os.path.join(dist_dir, f"{EXTENSION_NAME}{target_name}.zip")
with zipfile.ZipFile(zip_path, "w") as zipf:
    for root, dirs, files in os.walk(unzipped_dir):
        for file in files:
            zipf.write(os.path.join(root, file), os.path.relpath(os.path.join(root, file), unzipped_dir))

extension_path = os.path.join(dist_dir, f"{EXTENSION_NAME}{target_name}.aseprite-extension")
if os.path.exists(extension_path):
    os.remove(extension_path)

shutil.copy(zip_path, extension_path)

if REPLACE:
    extension_dir = os.path.join(extensions_dir, f"{EXTENSION_NAME}")
    if os.path.exists(extension_dir):
        shutil.rmtree(extension_dir)
    shutil.copytree(unzipped_dir, extension_dir)

print("Build completed successfully.")
