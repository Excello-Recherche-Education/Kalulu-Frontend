extends GutTest


func before_each() -> void:
	Bezier.factorial_cache = {}


func test_factorial_basic_values() -> void:
	assert_eq(Bezier.factorial(0), 1)
	assert_eq(Bezier.factorial(1), 1)
	assert_eq(Bezier.factorial(5), 120)


func test_binomial_invalid_inputs_return_zero() -> void:
	assert_eq(Bezier.binomial(-1, 3), 0)
	assert_eq(Bezier.binomial(2, -1), 0)
	assert_eq(Bezier.binomial(5, 2), 0)


func test_bernstein_weights_sum_to_one() -> void:
	var degree: int = 3
	var time_ratio: float = 0.42
	var total: float = 0.0
	for index: int in range(degree + 1):
		total += Bezier.bernstein(time_ratio, degree, index)
	assert_almost_eq(total, 1.0, 0.0001)


func test_bezier_linear_segment_midpoint() -> void:
	var control_points: Array = [Vector2(0.0, 0.0), Vector2(10.0, 0.0)]
	var midpoint: Vector2 = Bezier.bezier(0.5, control_points)
	assert_eq(midpoint, Vector2(5.0, 0.0))


func test_bezier_sampling_handles_sample_counts() -> void:
	var control_points: Array = [Vector2(0.0, 0.0), Vector2(10.0, 0.0)]
	assert_eq(Bezier.bezier_sampling(control_points, 0).size(), 0)
	var samples: Array = Bezier.bezier_sampling(control_points, 2)
	assert_eq(samples.size(), 3)
	assert_eq(samples[0], Vector2(0.0, 0.0))
	assert_eq(samples[2], Vector2(10.0, 0.0))
