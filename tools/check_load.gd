extends SceneTree
## =====================================================================
## LOAD CHECK: loads every .gd and .tscn in the project (about 1 second).
## CI runs this on every PR. Run it yourself before you push:
## =====================================================================
##   godot --headless --path . -s tools/check_load.gd
##
## Catches: a script that does not compile, a scene that points at a
## file that was moved or deleted. Exit code 0 = everything loads.

const SKIP_DIRS := [".godot", ".git", ".claude", "art_source"]
const MUSIC_DIR := "res://assets/audio/music"


func _initialize() -> void:
	var failures := 0
	var paths := _collect("res://")
	for path in paths:
		if not _loads(path):
			failures += 1
			print("FAIL  %s" % path)
	# Background music must loop (set Loop in the Import dock, then Reimport).
	for f in DirAccess.get_files_at(MUSIC_DIR):
		if f.get_extension() == "ogg":
			var music: AudioStream = load(MUSIC_DIR.path_join(f))
			if not (music is AudioStreamOggVorbis and music.loop):
				failures += 1
				print("FAIL  %s does not loop" % MUSIC_DIR.path_join(f))
	print("")
	print("ALL %d FILES LOAD" % paths.size() if failures == 0 else "%d FILE(S) FAILED TO LOAD" % failures)
	quit(1 if failures > 0 else 0)


func _loads(path: String) -> bool:
	var res := load(path)
	if res is GDScript:
		return res.can_instantiate()   # false when the script has a compile error
	if res == null:
		return false
	# A scene still loads when a file it uses is gone, so check each one.
	for dep in ResourceLoader.get_dependencies(path):
		var dep_path := dep.get_slice("::", 2) if "::" in dep else dep   # "uid::type::path" or just a path
		if not ResourceLoader.exists(dep_path):
			print("      missing: %s" % dep_path)
			return false
	return true


func _collect(dir_path: String) -> PackedStringArray:
	var found := PackedStringArray()
	for d in DirAccess.get_directories_at(dir_path):
		if d not in SKIP_DIRS:
			found.append_array(_collect(dir_path.path_join(d)))
	for f in DirAccess.get_files_at(dir_path):
		if f.get_extension() in ["gd", "tscn"]:
			found.append(dir_path.path_join(f))
	return found
