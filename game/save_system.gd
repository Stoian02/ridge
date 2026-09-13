class_name SaveSystem
extends RefCounted
## Reads and writes save data as JSON (spec §5.5). A write goes to a temporary file
## that then replaces the real one, so closing the app mid-save can't corrupt
## progress. A file that isn't a valid save is kept aside as <path>.bad and loading
## starts fresh, so nothing is silently lost.


## The Dictionary saved at `path`, or {} when the file is missing or damaged.
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) == OK and json.data is Dictionary:
		return json.data
	var bad := path + ".bad"
	if FileAccess.file_exists(bad):
		DirAccess.remove_absolute(bad)
	DirAccess.rename_absolute(path, bad)
	print("SaveSystem: %s was not a valid save; kept it as %s and started fresh" % [path, bad])
	return {}


## Saves `data` as JSON at `path`. Returns OK, or the error that stopped the write;
## a failure is also printed, so a lost save shows up in the log instead of vanishing.
static func write(path: String, data: Dictionary) -> Error:
	var folder := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(folder):
		DirAccess.make_dir_recursive_absolute(folder)
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return _report_failure(path, FileAccess.get_open_error())
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var renamed := DirAccess.rename_absolute(temp, path)
	if renamed != OK:
		return _report_failure(path, renamed)
	return OK


static func _report_failure(path: String, error: Error) -> Error:
	print("SaveSystem: could not save %s (%s)" % [path, error_string(error)])
	return error
