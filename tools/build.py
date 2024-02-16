import os
import shutil
import subprocess
import zipfile

EXTENSION_NAME = "dmi-editor"
TARGET = "debug"
SKIP = False

import sys
args = sys.argv[1:]

if "--release" in args:
    TARGET = "release"
elif "--ci" in args:
    try:
        index = args.index("--ci")
        TARGET = args[index + 1] + "\\release"
        SKIP = True
    except IndexError:
        print("Error: Please provide a target name after --ci flag.")
        sys.exit(1)

working_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
os.chdir(working_dir)

if not SKIP:
    try:
        rust_version_output = subprocess.check_output(["rustc", "--version"]).decode()
    except FileNotFoundError:
        print("Error: Rust is not installed.")
        sys.exit(1)

    os.chdir(os.path.join(working_dir, "lib"))
    try:
        if TARGET == "debug":
            subprocess.run(["cargo", "build"], check=True)
        else:
            subprocess.run(["cargo", "build", "--release"], check=True)
    except subprocess.CalledProcessError:
        print("Error: lib build failed. Please check for errors.")
        sys.exit(1)


os.chdir(working_dir)

if sys.platform.startswith('win'):
    binary_extension = ".exe"
else:
    binary_extension = ""

binary_source = os.path.join("lib", "target", TARGET, f"lib{binary_extension}")

if not os.path.exists(binary_source):
    print("Error: lib binary was not built. Please check for errors.")
    sys.exit(1)

dist_dir = os.path.join(working_dir, "dist")
unzipped_dir = os.path.join(dist_dir, "unzipped")

if os.path.exists(dist_dir):
    shutil.rmtree(dist_dir)

os.makedirs(dist_dir)
os.makedirs(unzipped_dir)

shutil.copy("package.json", unzipped_dir)
shutil.copy("LICENSE", unzipped_dir)

shutil.copy(binary_source, unzipped_dir)

shutil.copytree(os.path.join("scripts"), os.path.join(unzipped_dir, "scripts"))

zip_path = os.path.join(dist_dir, f"{EXTENSION_NAME}.zip")
with zipfile.ZipFile(zip_path, "w") as zipf:
    for root, dirs, files in os.walk(unzipped_dir):
        for file in files:
            zipf.write(os.path.join(root, file), os.path.relpath(os.path.join(root, file), unzipped_dir))

extension_path = os.path.join(dist_dir, f"{EXTENSION_NAME}.aseprite-extension")
if os.path.exists(extension_path):
    os.remove(extension_path)

shutil.copy(zip_path, extension_path)

print("Build completed successfully.")
