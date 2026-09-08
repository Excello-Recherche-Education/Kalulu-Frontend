class_name DecorativeParticles
extends GPUParticles2D
## Particles that are there to be pretty, and switch themselves off when they can't
## be afforded.
##
## The drifting stars behind the gardens and the brain: 256 and 100 live particles
## over a full-screen visibility rect. Unlike the rest of the decoration the cost
## here is not memory -- the speck they draw is 128x128 -- it is the GPU doing that
## work every frame on a tablet that has none to spare. So this one keeps its texture
## and simply stops. See HeavyGraphics.


func _ready() -> void:
	if HeavyGraphics.enabled():
		return
	emitting = false
	hide()
