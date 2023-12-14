extends Node2D

signal finished()

const letter_segment_class: = preload("res://sources/look_and_learn/letter_segment.tscn")

@export var workspace_size: = Vector2(1200.0, 1200.0)
@export var solo_lower_workspace_size: = Vector2(1200.0, 800.0)
@export var letter_size: = Vector2(200.0, 200.0)
@export var position_margin: = 10.0

@onready var sprites_parent: = $Sprites
@onready var segments_parent: = $Segments

var data_directory: = "res://language_resources/french/look_and_learn/tracing_data/"

var letters: Array
var letter_index: = 0
var is_playing: = false
var is_in_demo: = false


func reset() -> void:
	letters = []
	letter_index = 0
	is_playing = false
	is_in_demo = false
	
	for child in segments_parent.get_children():
		child.queue_free()
	
	for child in sprites_parent.get_children():
		child.queue_free()


# --- Setup ---

func setup(grapheme: Array) -> void:
	letters = []
	
	if not _is_grapheme_valid(grapheme):
		return
	
	var max_size: = workspace_size
	if grapheme.size() == 1 and grapheme[0].count("lower") > 0:
		max_size = solo_lower_workspace_size
	
	var grapheme_size: = grapheme.size()
	var grapheme_size_vector: = letter_size * Vector2(grapheme_size, 1.0) + Vector2(position_margin, 0.0) * Vector2(grapheme_size - 1.0, 0.0)
	var grapheme_scale_factor_vector: = max_size / grapheme_size_vector
	var grapheme_scale_factor: float = min(grapheme_scale_factor_vector.x, grapheme_scale_factor_vector.y)
	
	var letters_min: = []
	var letters_max: = []
	var grapheme_letter_min: = Vector2(letter_size)
	var grapheme_letter_max: = Vector2(-1.0, -1.0)
	var grapheme_points: = []
	var letter_x_positions: = []
	var letter_sprites: = []
	for ind_letter in range(grapheme_size):
		var layers: = _load_letter_layers(grapheme[ind_letter])
		
		var letter_sprite_path: String = data_directory + grapheme[ind_letter] + ".png"
		var letter_texture: = load(letter_sprite_path)
		var letter_sprite: = Sprite2D.new()
		sprites_parent.add_child(letter_sprite)
		letter_sprite.centered = false
		letter_sprite.texture = letter_texture
		letter_sprites.append(letter_sprite)
		
		var letter_max: = Vector2(-1.0, -1.0)
		var letter_min: = Vector2(letter_size)
		var letter_points: = []
		for layer in layers:
			var points: = _layer_to_segment(layer)
			letter_points.append(points)
			
			for point in points:
				if point.x < grapheme_letter_min.x:
					grapheme_letter_min.x = point.x
				if point.y < grapheme_letter_min.y:
					grapheme_letter_min.y = point.y
				if point.x > grapheme_letter_max.x:
					grapheme_letter_max.x = point.x
				if point.y > grapheme_letter_max.y:
					grapheme_letter_max.y = point.y
				
				if point.x < letter_min.x:
					letter_min.x = point.x
				if point.y < letter_min.y:
					letter_min.y = point.y
				if point.x > letter_max.x:
					letter_max.x = point.x
				if point.y > letter_max.y:
					letter_max.y = point.y
		
		var position_ind: = -(grapheme_size - 1.0) + 2.0 * ind_letter
		var letter_x_position: = ((letter_size.x / 2.0) + position_margin) * position_ind
		
		grapheme_points.append(letter_points)
		letter_x_positions.append(letter_x_position)
		letters_min.append(letter_min)
		letters_max.append(letter_max)
	
	var letter_scale_factor_vector: = letter_size / (grapheme_letter_max - grapheme_letter_min + Vector2.ONE)
	var letter_scale_factor: float = min(letter_scale_factor_vector.x, letter_scale_factor_vector.y)
	
	for i in grapheme_points.size():
		var letter_points = grapheme_points[i]
		var letter_x_position = letter_x_positions[i]
		
#		var letter_offset: Vector2 = letters_min[i] + (Vector2(letters_max[i].x - letters_min[i].x + 1.0, grapheme_letter_max.y - grapheme_letter_min.y + 1.0) / 2.0)
		var letter_min: = Vector2(letters_min[i].x, grapheme_letter_min.y)
		var letter_half_size: = 0.5 * Vector2((letters_max[i] - letters_min[i]).x + 1.0, (grapheme_letter_max - grapheme_letter_min).y + 1.0)
		var letter_offset: Vector2 = letter_min + letter_half_size
		
		var letter_sprite: Sprite2D = letter_sprites[i]
		letter_sprite.position = grapheme_scale_factor * (Vector2(letter_x_position, 0) - letter_scale_factor * letter_offset)
		
		var sprite_size: = Vector2(letter_sprite.texture.get_width(), letter_sprite.texture.get_height())
		var sprite_scale: = letter_size / sprite_size
		letter_sprite.scale = grapheme_scale_factor * letter_scale_factor * sprite_scale
		
		var segments: = []
		for points in letter_points:
			var segment: LetterSegment = letter_segment_class.instantiate()
			segments_parent.add_child(segment)
			segments_parent.move_child(segment, 0)
			
			points = _center_and_scale_points(points, letter_offset, letter_x_position, letter_scale_factor, grapheme_scale_factor)
			segment.setup(points, grapheme_size)
			
			segments.append(segment)
		letters.append(segments)


func _is_grapheme_valid(grapheme: Array) -> bool:
	for ind_letter in range(grapheme.size()-1, -1, -1):
		#print("CHECK ", grapheme[lIndex] + "_" + str(1) + ".json")
		if not (ResourceLoader.exists(data_directory + grapheme[ind_letter] + "_" + str(1) + ".png")):
				grapheme.remove_at(ind_letter)
	
	return grapheme.size() != 0


func _load_letter_layers(letter_name: String) -> Array:
	var layers: = []
	
	var tex_id = 1
	var path = data_directory + letter_name + "_" + str(tex_id) + ".png"
	while(ResourceLoader.exists(path)):
		layers.append(_load_layer(letter_name + "_" + str(tex_id)))
		tex_id += 1
		path = data_directory + letter_name + "_" + str(tex_id) + ".png"
	
	return layers


func _load_layer(layer_name: String) -> Image:
	var image: Image = load(data_directory + layer_name + ".png").get_image()
	return image


func _layer_to_segment(layer: Image) -> Array:
	var points: = _find_points(layer)
	
	return points


func _find_points(layer: Image) -> Array:
	var size: = layer.get_size()
	var start_pos: = Vector2(0, 0)
	for x in size.x:
		for y in size.y:
			if layer.get_pixel(x, y).g > 0.5:
				start_pos = Vector2(x, y)
				break
	
	var points: = [start_pos]
	var current_pos: = start_pos
	var flagged: = {current_pos: true}
	var test_positions: = [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]
	var test_positions_opt: = [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)]
	while true:
		if not _test_neighbors(test_positions, current_pos, size, flagged, layer, points):
			if not _test_neighbors(test_positions_opt, current_pos, size, flagged, layer, points):
				break
		current_pos = points[-1]
	
	return points


func _test_neighbors(test_positions: Array, current_pos: Vector2, size: Vector2, flagged: Dictionary, layer: Image, points: Array) -> bool:
	for test_pos in test_positions:
		test_pos += current_pos
		if test_pos.x >= size.x or test_pos.x < 0 or\
			test_pos.y >= size.y or test_pos.y < 0:
			continue
		if not flagged.has(test_pos) and layer.get_pixelv(test_pos).b > 0.5:
			points.append(test_pos)
			current_pos = test_pos
			flagged[test_pos] = true
			return true
	return false


func _center_and_scale_points(points: Array, letter_offset: Vector2, letter_x_position: float, letter_scale_factor, grapheme_scale_factor: float) -> Array:
	var new_points: = []
	for point in points:
		var new_point: Vector2 = letter_scale_factor * (point - letter_offset)
		new_point += Vector2(letter_x_position, 0.0)
		new_point *= grapheme_scale_factor
		new_points.append(new_point)
	
	return new_points


# --- Start ---


func start() -> void:
	is_playing = true
	for letter in letters:
		for segment in letter:
			segment.start()
			if segment.is_playing:
				await segment.finished
				
			segments_parent.move_child(segment, 0)
	
	is_playing = false
	
	emit_signal("finished")


func demo() -> void:
	is_in_demo = true
	for letter in letters:
		for segment in letter:
			segment.demo()
			if segment.is_in_demo:
				await segment.finished
	
	is_in_demo = false
	
	emit_signal("finished")

