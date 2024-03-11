#!/usr/bin/python
import os
import time
import subprocess
import sys
from watchdog.observers import Observer
from watchdog.events import RegexMatchingEventHandler

working_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
os.chdir(working_dir)

replace = True if "--replace" in sys.argv[1:] else False

regexes = [".*lib.*\\.rs", ".*scripts.*\\.lua", ".*\\.toml", "\\..package\\.json"]
ignore_regexes = []
ignore_directories = False
case_sensitive = True
event_handler = RegexMatchingEventHandler(regexes, ignore_regexes, ignore_directories, case_sensitive)

changed = False
building = False

def on_changed(event):
		global changed, building
		if not building:
			changed = True

event_handler.on_created = on_changed
event_handler.on_deleted = on_changed
event_handler.on_modified = on_changed
event_handler.on_moved = on_changed

path = "."
recursive = True
observer = Observer()
observer.schedule(event_handler, path, recursive)

observer.start()

print("Watching for changes...")

try:
	while True:
		time.sleep(1)
		if changed:
			changed = False
			building = True
			print("Rebuilding...")
			subprocess.run(["python", "tools/build.py", "--replace" if replace else ""])
			building = False
except KeyboardInterrupt:
	observer.stop()
	observer.join()
