extends Node
class_name Bezier


static func bezier_square_error(current_points: Array, ref_points: Array) -> float:
	var samples: = bezier_sampling(current_points, 25)
	var curve: = Curve2D.new()
	
	for point in samples:
		curve.add_point(point)
	
	var error: = 0.0
	for point in ref_points:
		var curve_point: = curve.get_closest_point(point)
		error += pow(curve_point.distance_to(point), 2.0)
	
	return error


static func bezier_sampling(points: Array, number_of_samples: int) -> Array:
	var sample_points: = []
	for i in range(number_of_samples + 1):
		var sample: = bezier(float(i) / float(number_of_samples), points)
		sample_points.append(sample)
	
	return sample_points


static func bezier(t: float, points: Array) -> Vector2:
	var n: = points.size() - 1
	
	var r: = Vector2.ZERO
	for i in range(n + 1):
		var bern: = bernstein(t, n, i)
		r += bern * points[i]
	
	return r


static func bernstein(t: float, m: int, i: int) -> float:
	var b_i_m: = float(binomial(i, m))
	var t_i: = pow(t, i)
	var t_m_i: = pow(1.0 - t, m - i)
	
	var r: = b_i_m * t_i * t_m_i
	
	return r


static func binomial(k: int, n: int) -> int:	
	var n_f: = factorial(n)
	var k_f: = factorial(k)
	var n_k_f: = factorial(n - k)
	
	var r: = int(float(n_f) / (float(k_f) * float(n_k_f)))
	
	return r


static func factorial(k: int) -> int:
	if k == 0:
		return 1
	
	var r: = 1
	for i in range(1, k + 1):
		r *= i
	
	return r
