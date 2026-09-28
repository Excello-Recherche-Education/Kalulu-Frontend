#!/usr/bin/env sh
# Switches project.godot between the two applications this repository holds.
#
# The game and the Prof Tool differ by exactly three settings: the application
# name, the scene it opens on, and the icon. Everything else -- the scripts, the
# scenes, the export presets -- is shared, so flipping those three is the whole
# of "building the other one".
#
# This replaces prof_tool_patch.diff, which was applied with `git apply` and
# could not survive a release. A diff matches on context, and the context around
# run/main_scene is config/version on one side and config/features on the other:
# the version changes at every release and the features string at every engine
# upgrade, so the patch stopped applying the moment either moved -- which is the
# state it was found in, still naming version 3.0.0 and Godot 4.6.
#
# Setting the keys by name instead has no context to drift. It is also
# idempotent in both directions and can be asked which mode it is in, none of
# which a patch could do.
#
# Usage:
#   tools/prof_tool_mode.sh on       build the Prof Tool
#   tools/prof_tool_mode.sh off      build the Kalulu game
#   tools/prof_tool_mode.sh status   say which one project.godot is set to
#
# Never commit the result of `on`: main carries the game, and the Prof Tool is
# built from a working tree that is put back afterwards.

set -eu

GAME_NAME='Kalulu'
GAME_SCENE='res://sources/menus/splash_screen/splash_screen.tscn'
GAME_ICON='res://assets/kalulu_icon.png'

TOOL_NAME='Prof_Tool'
TOOL_SCENE='res://sources/language_tool/prof_tool_menu.tscn'
TOOL_ICON='res://assets/prof_tool_icon.png'

project_file="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)/project.godot"

if [ ! -f "$project_file" ]; then
	echo "prof_tool_mode: no project.godot at $project_file" >&2
	exit 1
fi

current_value() {
	# The value of one key, without its quotes. Anchored at the start of the line
	# so a key mentioned inside a comment cannot answer for the real one, and
	# delimited with | because every key here contains a slash of its own.
	sed -n "s|^$1=\"\(.*\)\"$|\1|p" "$project_file" | head -n 1
}

apply() {
	name="$1"
	scene="$2"
	icon="$3"
	tmp="$project_file.prof_tool_mode.$$"
	# awk rather than `sed -i`, whose in-place flag takes an argument on macOS and
	# none on Linux, and whose replacement text would need the paths escaped.
	awk -v name="$name" -v scene="$scene" -v icon="$icon" '
		/^config\/name=/     { print "config/name=\"" name "\""; next }
		/^run\/main_scene=/  { print "run/main_scene=\"" scene "\""; next }
		/^config\/icon=/     { print "config/icon=\"" icon "\""; next }
		{ print }
	' "$project_file" > "$tmp"
	mv "$tmp" "$project_file"
}

report() {
	printf 'config/name     = %s\n' "$(current_value 'config/name')"
	printf 'run/main_scene  = %s\n' "$(current_value 'run/main_scene')"
	printf 'config/icon     = %s\n' "$(current_value 'config/icon')"
}

case "${1:-}" in
	on)
		apply "$TOOL_NAME" "$TOOL_SCENE" "$TOOL_ICON"
		echo "project.godot now builds the Prof Tool."
		report
		echo "Put it back with: tools/prof_tool_mode.sh off"
		;;
	off)
		apply "$GAME_NAME" "$GAME_SCENE" "$GAME_ICON"
		echo "project.godot now builds the Kalulu game."
		report
		;;
	status)
		case "$(current_value 'config/name')" in
			"$TOOL_NAME") echo "Prof Tool" ;;
			"$GAME_NAME") echo "Kalulu game" ;;
			*)            echo "neither: config/name is $(current_value 'config/name')" ;;
		esac
		report
		;;
	*)
		echo "usage: $0 on|off|status" >&2
		exit 2
		;;
esac
