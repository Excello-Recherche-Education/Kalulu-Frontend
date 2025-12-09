class_name Bezier
extends Node

static var factorial_cache: Dictionary = {}


static func bezier_square_error(current_points: Array, ref_points: Array) -> float:
	var samples: Array[Vector2] = bezier_sampling(current_points, 25)
	var curve: Curve2D = Curve2D.new()
	for point: Vector2 in samples:
		curve.add_point(point)
	var error: float = 0.0
	for point: Vector2 in ref_points:
		var curve_point: Vector2 = curve.get_closest_point(point)
		error += pow(curve_point.distance_to(point), 2.0)
	return error


static func bezier_sampling(points: Array, number_of_samples: int) -> Array[Vector2]:
	var sample_points: Array[Vector2] = []
	if number_of_samples <= 0:
		return sample_points
	for index: int in range(number_of_samples + 1):
		var sample: Vector2 = bezier(float(index) / float(number_of_samples), points)
		sample_points.append(sample)
	return sample_points


static func bezier(t: float, control_points: Array) -> Vector2:
	var degree: int = control_points.size() - 1
	var result: Vector2 = Vector2.ZERO
	# Compute the weighted sum of the control points using Bernstein polynomials
	for point_index: int in range(degree + 1):
		var bernstein_weight: float = bernstein(t, degree, point_index)
		var weighted_point: Vector2 = bernstein_weight * control_points[point_index]
		result += weighted_point
	return result


static func bernstein(time_ratio: float, degree: int, index: int) -> float:
	var binomial_coefficient: float = float(binomial(index, degree))
	var time_power_index: float = pow(time_ratio, index)
	var inverse_time_power: float = pow(1.0 - time_ratio, degree - index)
	var result: float = binomial_coefficient * time_power_index * inverse_time_power
	return result


static func binomial(index: int, degree: int) -> int:
	if index < 0 or degree < 0 or index > degree:
		return 0
	var degree_factorial: int = factorial(degree)
	var index_factorial: int = factorial(index)
	var degree_minus_index_factorial: int = factorial(degree - index)
	return int(float(degree_factorial) / (float(index_factorial) * float(degree_minus_index_factorial)))


static func factorial(number: int) -> int:
	assert(number >= 0, "Factorial is undefined for negative numbers")
	if number in factorial_cache:
		return factorial_cache[number]
	var result: int = 1
	for value: int in range(1, number + 1):
		result *= value
	factorial_cache[number] = result
	return result
