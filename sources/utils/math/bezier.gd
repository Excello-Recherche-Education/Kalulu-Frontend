extends Node
class_name Bezier


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
	for index: int in range(number_of_samples + 1):
		var sample: Vector2 = bezier(float(index) / float(number_of_samples), points)
		sample_points.append(sample)
	
	return sample_points


static func bezier(t: float, points: Array) -> Vector2:
	var n: int = points.size() - 1
	var r: Vector2 = Vector2.ZERO
	for index: int in range(n + 1):
		var bern: float = bernstein(t, n, index)
		r += bern * points[index]
	
	return r


static func bernstein(t: float, m: int, i: int) -> float:
	var b_i_m: float = float(binomial(i, m))
	var t_i: float = pow(t, i)
	var t_m_i: float = pow(1.0 - t, m - i)
	var result: float = b_i_m * t_i * t_m_i
	
	return result


static func binomial(k: int, n: int) -> int:	
	var n_f: int = factorial(n)
	var k_f: int = factorial(k)
	var n_k_f: int = factorial(n - k)
	return int(float(n_f) / (float(k_f) * float(n_k_f)))


static func factorial(k: int) -> int:
	if k == 0:
		return 1
	
	var result: int = 1
	for index: int in range(1, k + 1):
		result *= index
	
	return result
