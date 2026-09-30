class_name DecorativeParticles
extends CPUParticles2D
## Particles that are there to be pretty, and switch themselves off when they can't
## be afforded.
##
## The drifting stars behind the gardens and the brain: 256 and 100 live particles
## over a full-screen visibility rect. Unlike the rest of the decoration the cost
## here is not memory -- the speck they draw is 128x128 -- it is simulating and
## drawing them every frame on a tablet that has nothing to spare. So this one keeps
## its texture and simply stops. See HeavyGraphics.
##
## CPU particles, like every emitter in the game: some Android GPU drivers abort
## while compiling Godot's GPU particle shader, which takes the whole app down.


func _ready() -> void:
	if HeavyGraphics.enabled():
		return
	emitting = false
	hide()
