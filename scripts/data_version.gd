class_name DataVersion
extends RefCounted
## The same manifest is imported by Convex. Wire prefixes describe containers;
## v describes the data inside them, independently of the game release.
static var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://version.json"))

static func current() -> int: return int(manifest.data_version)
static func legacy() -> int: return int(manifest.legacy_data_version)
static func release() -> String: return str(manifest.release)

static func readable(value: Variant) -> bool:
	if not (value is int or value is float) or not is_finite(float(value)): return false
	return float(value)==floor(float(value)) and value>=manifest.oldest_readable_data_version and value<=current()

static func accepts(data: Dictionary, allow_missing := false) -> bool:
	return readable(data.get("v",legacy() if allow_missing else null))

static func stamp(data: Dictionary) -> Dictionary:
	if not accepts(data): return {}
	# Version 1 and 2 share gameplay fields. Version 2 makes the version tag
	# explicit in every container, including packed editor levels.
	# Version 3 adds previously unused packed-cell values. Existing object
	# fields are unchanged, so migration only stamps their current version.
	# Future structural migrations belong here before advancing v.
	var result := data.duplicate(true)
	result.v=current()
	return result
