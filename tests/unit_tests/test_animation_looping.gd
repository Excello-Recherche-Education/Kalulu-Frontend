extends GutTest
## Pins the loop flag on every SpriteFrames that is generated rather than authored.
##
## These resources are rebuilt by the scripts in tools/, and the loop flag is the
## one property that carries no visible trace when it is wrong: the sheet is the
## right size, the frames are the right frames, the animation plays -- once -- and
## then sits on its last frame. Jellyfish that had been drifting and pulsing
## looked simply motionless.
##
## The cause is worth recording. Godot serialises this as `"loop": 1` in these
## files, not `"loop": true`, and the generators parsed it as `loop == "true"`,
## which is false for "1". Every regenerated animation came out non-looping.
##
## The values below are the originals, recovered from git and checked against
## them field by field.

const EXPECTED_LOOPS: Dictionary = {
	"res://sources/minigames/boss/friends/ant_boss_animations.tres": {"idle": true, "success": true},
	"res://sources/minigames/boss/friends/crab_boss_animations.tres": {"idle": false, "right": true},
	"res://sources/minigames/boss/friends/frog_boss_animations.tres": {"idle_front": false},
	"res://sources/minigames/boss/friends/jellyfish_boss_animations.tres": {"idle": true},
	"res://sources/minigames/boss/friends/monkey_boss_animations.tres": {"idle": false},
	"res://sources/minigames/boss/friends/parakeet_boss_animations.tres": {"happy": true, "idle_front": true},
	"res://sources/minigames/boss/friends/penguin_boss_animations.tres": {"happy": false, "idle": true},
	"res://sources/minigames/boss/friends/turtle_boss_animations.tres": {"swim": true},
	"res://sources/minigames/crabs/crab/crab_animations.tres": {"idle": false, "idle_blink": false, "right": true, "wrong": true},
	"res://sources/minigames/turtles/crab_decor_animations.tres": {"idle": true, "idle_claws": true, "victory_claws": true},
	"res://sources/minigames/jellyfish/blue_jellyfish_animations_body.tres": {"happy": true, "hit": true, "idle": true},
	"res://sources/minigames/jellyfish/blue_jellyfish_animations_arms.tres": {"happy": true, "hit": true, "idle": true},
	"res://sources/minigames/jellyfish/pink_jellyfish_animations_body.tres": {"happy": true, "hit": true, "idle": true},
	"res://sources/minigames/jellyfish/pink_jellyfish_animations_arms.tres": {"happy": true, "hit": true, "idle": true},
}
## Every animation these minigames keep alive by looping. If any of these stopped
## looping, the character would freeze mid-scene rather than error.
const MUST_LOOP: Dictionary = {
	"res://sources/minigames/jellyfish/pink_jellyfish_animations_body.tres": "idle",
	"res://sources/minigames/jellyfish/blue_jellyfish_animations_body.tres": "idle",
	"res://sources/minigames/turtles/crab_decor_animations.tres": "idle_claws",
	"res://sources/minigames/boss/friends/turtle_boss_animations.tres": "swim",
}


func test_every_generated_resource_keeps_its_loop_flag() -> void:
	for path: String in EXPECTED_LOOPS:
		var frames: SpriteFrames = load(path) as SpriteFrames
		assert_not_null(frames, "%s should load" % path)
		if not frames:
			continue
		var expected: Dictionary = EXPECTED_LOOPS[path]
		for animation: String in expected:
			var name: StringName = StringName(animation)
			assert_true(frames.has_animation(name), "%s should have '%s'" % [path.get_file(), animation])
			if not frames.has_animation(name):
				continue
			assert_eq(frames.get_animation_loop(name), expected[animation] as bool,
				"%s/%s should loop=%s" % [path.get_file(), animation, expected[animation]])


func test_the_animations_that_have_to_keep_moving_do() -> void:
	# Stated separately because these are the ones a reader would notice: a
	# jellyfish that plays idle once looks like a jellyfish that is broken.
	for path: String in MUST_LOOP:
		var frames: SpriteFrames = load(path) as SpriteFrames
		if not frames:
			continue
		var animation: StringName = StringName(MUST_LOOP[path])
		assert_true(frames.get_animation_loop(animation),
			"%s/%s has to loop or the character stops moving" % [path.get_file(), animation])


func test_no_generated_animation_is_left_empty() -> void:
	for path: String in EXPECTED_LOOPS:
		var frames: SpriteFrames = load(path) as SpriteFrames
		if not frames:
			continue
		for animation: StringName in frames.get_animation_names():
			assert_gt(frames.get_frame_count(animation), 0,
				"%s/%s has no frames" % [path.get_file(), animation])
			for index: int in frames.get_frame_count(animation):
				assert_almost_eq(frames.get_frame_duration(animation, index), 1.0, 0.001,
					"%s/%s frame %d duration" % [path.get_file(), animation, index])
