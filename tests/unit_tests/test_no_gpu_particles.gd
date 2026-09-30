extends GutTest
## No GPU particles anywhere in the game.
##
## Some Android GPU drivers abort inside glLinkProgram while compiling Godot's GPU
## particle shader -- seen in Android vitals on a MediaTek mt6855, from
## GLES3::ParticlesStorage::update_particles down into the vendor's GLSL compiler.
## An abort is not an error Godot can report or recover from: the app is simply
## gone, the first time a scene with particles is drawn. CPUParticles2D draws the
## same effects without that shader, so every emitter in the game is one.
##
## The editor offers GPUParticles2D first, which is how a new effect would bring
## the crash back without anyone noticing on a device that is not affected.

## Where to sweep for scenes and resources.
const DIRECTORIES: Array[String] = ["res://sources", "res://resources"]
## What only the GPU particle path uses.
const FORBIDDEN: Array[String] = [
	"type=\"GPUParticles2D\"",
	"type=\"GPUParticles3D\"",
	"type=\"ParticleProcessMaterial\"",
]


func test_no_scene_or_resource_uses_gpu_particles() -> void:
	var files: PackedStringArray = PackedStringArray()
	for directory: String in DIRECTORIES:
		_collect(directory, files)
	assert_gt(files.size(), 0, "the sweep should have found some scenes to check")
	for path: String in files:
		var text: String = FileAccess.get_file_as_string(path)
		for needle: String in FORBIDDEN:
			assert_false(text.contains(needle),
				"%s uses %s -- use CPUParticles2D instead, some Android drivers crash compiling the GPU particle shader"
					% [path, needle])


func _collect(directory: String, found: PackedStringArray) -> void:
	for entry: String in DirAccess.get_directories_at(directory):
		_collect(directory.path_join(entry), found)
	for entry: String in DirAccess.get_files_at(directory):
		if entry.ends_with(".tscn") or entry.ends_with(".tres"):
			found.append(directory.path_join(entry))
