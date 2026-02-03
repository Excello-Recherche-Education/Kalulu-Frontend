extends GutTest

const EPSILON: float = 0.00001


func before_each() -> void:
	Bezier.factorial_cache = {}


# -----------------------------
# Factorial
# -----------------------------
func test_factorial_basic_values() -> void:
	assert_eq(Bezier.factorial(0), 1, "factorial(number=0) should return 1")
	assert_eq(Bezier.factorial(1), 1, "factorial(number=1) should return 1")
	assert_eq(Bezier.factorial(5), 120, "factorial(number=5) should return 120")


func test_factorial_cache_is_filled_and_reused() -> void:
	assert_false(0 in Bezier.factorial_cache, "factorial_cache should be empty after before_each")
	assert_false(5 in Bezier.factorial_cache, "factorial_cache should be empty after before_each")

	var result: int = Bezier.factorial(5)
	assert_eq(result, 120, "factorial(number=5) should return 120")
	assert_true(5 in Bezier.factorial_cache, "factorial(number=5) should populate factorial_cache")
	assert_eq(Bezier.factorial_cache[5], 120, "factorial_cache[5] should equal factorial(number=5)")

	var cached_result: int = Bezier.factorial(5)
	assert_eq(cached_result, 120, "Second call to factorial(number=5) should return same value (cache hit expected)")


# -----------------------------
# Binomial
# -----------------------------
func test_binomial_invalid_inputs_return_zero() -> void:
	assert_eq(Bezier.binomial(-1, 3), 0, "binomial(index<0, degree) should return 0")
	assert_eq(Bezier.binomial(2, -1), 0, "binomial(index, degree<0) should return 0")
	assert_eq(Bezier.binomial(5, 2), 0, "binomial(index>degree, degree) should return 0")


func test_binomial_known_values() -> void:
	assert_eq(Bezier.binomial(0, 0), 1, "binomial(index=0, degree=0) should return 1")
	assert_eq(Bezier.binomial(0, 5), 1, "binomial(index=0, degree=5) should return 1")
	assert_eq(Bezier.binomial(5, 5), 1, "binomial(index=5, degree=5) should return 1")

	assert_eq(Bezier.binomial(1, 3), 3, "binomial(index=1, degree=3) should return 3")
	assert_eq(Bezier.binomial(2, 4), 6, "binomial(index=2, degree=4) should return 6")
	assert_eq(Bezier.binomial(3, 6), 20, "binomial(index=3, degree=6) should return 20")


func test_binomial_symmetry_identity() -> void:
	var degree: int = 7
	for index: int in range(degree + 1):
		assert_eq(
			Bezier.binomial(index, degree),
			Bezier.binomial(degree - index, degree),
			"binomial(index, degree) should be symmetric: binomial(index, degree) == binomial(degree - index, degree) for index=" + str(index) + ", degree=" + str(degree)
		)


# -----------------------------
# Bernstein polynomials
# -----------------------------
func test_bernstein_weights_sum_to_one_multiple_t() -> void:
	var degree: int = 5
	var time_ratios: Array[float] = [0.0, 0.25, 0.5, 0.77, 1.0]

	for time_ratio: float in time_ratios:
		var result: float = 0.0
		for index: int in range(degree + 1):
			result += Bezier.bernstein(time_ratio, degree, index)

		assert_almost_eq(
			result,
			1.0,
			0.0001,
			"Sum of bernstein(time_ratio, degree, index) over index=0..degree should be 1 for time_ratio=" + str(time_ratio) + ", degree=" + str(degree)
		)


func test_bernstein_endpoints_are_kronecker_delta() -> void:
	var degree: int = 6

	# time_ratio = 0.0
	for index: int in range(degree + 1):
		var result: float = Bezier.bernstein(0.0, degree, index)
		if index == 0:
			assert_almost_eq(result, 1.0, EPSILON, "bernstein(time_ratio=0, degree, index=0) should equal 1 for degree=" + str(degree))
		else:
			assert_almost_eq(result, 0.0, EPSILON, "bernstein(time_ratio=0, degree, index) should equal 0 for index=" + str(index) + ", degree=" + str(degree))

	# time_ratio = 1.0
	for index: int in range(degree + 1):
		var result: float = Bezier.bernstein(1.0, degree, index)
		if index == degree:
			assert_almost_eq(result, 1.0, EPSILON, "bernstein(time_ratio=1, degree, index=degree) should equal 1 for degree=" + str(degree))
		else:
			assert_almost_eq(result, 0.0, EPSILON, "bernstein(time_ratio=1, degree, index) should equal 0 for index=" + str(index) + ", degree=" + str(degree))


func test_bernstein_non_negative_on_unit_interval() -> void:
	var degree: int = 6
	var time_ratios: Array[float] = [0.0, 0.1, 0.33, 0.5, 0.9, 1.0]

	for time_ratio: float in time_ratios:
		for index: int in range(degree + 1):
			var result: float = Bezier.bernstein(time_ratio, degree, index)
			assert_gte(result, 0.0, "bernstein(time_ratio, degree, index) should be >= 0 on [0,1] for time_ratio=" + str(time_ratio) + ", index=" + str(index) + ", degree=" + str(degree))
			assert_lte(result, 1.0, "bernstein(time_ratio, degree, index) should be <= 1 on [0,1] for time_ratio=" + str(time_ratio) + ", index=" + str(index) + ", degree=" + str(degree))


# -----------------------------
# Bezier curve evaluation
# -----------------------------
func test_bezier_degree_zero_returns_single_point() -> void:
	var control_points: Array = [Vector2(2.0, -3.0)]
	var time_ratios: Array[float] = [0.0, 0.25, 0.5, 1.0]

	for time_ratio: float in time_ratios:
		assert_eq(
			Bezier.bezier(time_ratio, control_points),
			Vector2(2.0, -3.0),
			"bezier(time_ratio, control_points) with degree=0 should always return the single control point for time_ratio=" + str(time_ratio)
		)


func test_bezier_endpoints_match_first_and_last_control_points() -> void:
	var control_points: Array[Vector2] = [
		Vector2(0.0, 0.0),
		Vector2(4.0, 10.0),
		Vector2(9.0, -2.0),
		Vector2(10.0, 0.0)
	]

	assert_eq(
		Bezier.bezier(0.0, control_points),
		control_points[0],
		"bezier(time_ratio=0, control_points) should return control_points[0]"
	)

	assert_eq(
		Bezier.bezier(1.0, control_points),
		control_points[control_points.size() - 1],
		"bezier(time_ratio=1, control_points) should return the last control point"
	)


func test_bezier_linear_segment_midpoint() -> void:
	var control_points: Array = [Vector2(0.0, 0.0), Vector2(10.0, 0.0)]
	var result: Vector2 = Bezier.bezier(0.5, control_points)
	assert_eq(result, Vector2(5.0, 0.0), "bezier(time_ratio=0.5, control_points) for a segment should return the midpoint")


func test_bezier_quadratic_known_point_at_half() -> void:
	# Quadratic chosen so the point at time_ratio=0.5 is predictable.
	var control_points: Array = [
		Vector2(0.0, 0.0),
		Vector2(0.0, 10.0),
		Vector2(10.0, 10.0)
	]

	var result: Vector2 = Bezier.bezier(0.5, control_points)
	assert_almost_eq(
		result,
		Vector2(2.5, 7.5),
		Vector2(EPSILON, EPSILON),
		"bezier(time_ratio=0.5, control_points) for this quadratic should match the expected point"
	)


func test_bezier_points_stay_within_control_bounds_for_axis_aligned_segment() -> void:
	# For monotonic x and constant y, bezier(time_ratio, control_points) should remain within x bounds and keep y constant.
	var control_points: Array = [
		Vector2(0.0, 0.0),
		Vector2(2.0, 0.0),
		Vector2(7.0, 0.0),
		Vector2(10.0, 0.0)
	]

	var time_ratios: Array[float] = [0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0]

	for time_ratio: float in time_ratios:
		var result: Vector2 = Bezier.bezier(time_ratio, control_points)
		assert_between(result.x, 0.0, 10.0, "bezier(time_ratio, control_points).x should remain within [0,10] for time_ratio=" + str(time_ratio))
		assert_almost_eq(result.y, 0.0, EPSILON, "bezier(time_ratio, control_points).y should remain 0 for time_ratio=" + str(time_ratio))


func test_bezier_translation_invariance() -> void:
	var control_points: Array = [
		Vector2(1.0, 2.0),
		Vector2(3.0, 5.0),
		Vector2(8.0, -1.0)
	]

	var offset: Vector2 = Vector2(100.0, -50.0)
	var translated_control_points: Array = []

	for point: Vector2 in control_points:
		translated_control_points.append(point + offset)

	var time_ratio: float = 0.37
	var result: Vector2 = Bezier.bezier(time_ratio, control_points)
	var translated_result: Vector2 = Bezier.bezier(time_ratio, translated_control_points)

	assert_almost_eq(
		translated_result,
		result + offset,
		Vector2(EPSILON, EPSILON),
		"bezier(time_ratio, control_points) should be translation-invariant for time_ratio=" + str(time_ratio)
	)


func test_bezier_scaling_invariance() -> void:
	var control_points: Array = [
		Vector2(1.0, 2.0),
		Vector2(3.0, 5.0),
		Vector2(8.0, -1.0)
	]

	var scale: float = 3.0
	var scaled_control_points: Array = []

	for point: Vector2 in control_points:
		scaled_control_points.append(point * scale)

	var time_ratio: float = 0.61
	var result: Vector2 = Bezier.bezier(time_ratio, control_points)
	var scaled_result: Vector2 = Bezier.bezier(time_ratio, scaled_control_points)

	assert_almost_eq(
		scaled_result,
		result * scale,
		Vector2(EPSILON, EPSILON),
		"bezier(time_ratio, control_points) should scale linearly with control points for time_ratio=" + str(time_ratio)
	)


# -----------------------------
# Sampling
# -----------------------------
func test_bezier_sampling_handles_sample_counts() -> void:
	var control_points: Array = [Vector2(0.0, 0.0), Vector2(10.0, 0.0)]

	assert_eq(Bezier.bezier_sampling(control_points, 0).size(), 0, "bezier_sampling(control_points, number_of_samples<=0) should return an empty array")
	assert_eq(Bezier.bezier_sampling(control_points, -3).size(), 0, "bezier_sampling(control_points, number_of_samples<=0) should return an empty array")

	var sample_points: Array[Vector2] = Bezier.bezier_sampling(control_points, 2)
	assert_eq(sample_points.size(), 3, "bezier_sampling(control_points, number_of_samples=2) should return number_of_samples + 1 points")
	assert_eq(sample_points[0], Vector2(0.0, 0.0), "bezier_sampling(control_points, number_of_samples=2)[0] should equal bezier(time_ratio=0, control_points)")
	assert_eq(sample_points[2], Vector2(10.0, 0.0), "bezier_sampling(control_points, number_of_samples=2)[2] should equal bezier(time_ratio=1, control_points)")


func test_bezier_sampling_sample_count_one_returns_two_points() -> void:
	var control_points: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(10.0, 0.0)]
	var sample_points: Array[Vector2] = Bezier.bezier_sampling(control_points, 1)

	assert_eq(sample_points.size(), 2, "bezier_sampling(control_points, number_of_samples=1) should return 2 points")
	assert_eq(sample_points[0], control_points[0], "bezier_sampling(control_points, number_of_samples=1)[0] should equal control_points[0]")
	assert_eq(sample_points[1], control_points[1], "bezier_sampling(control_points, number_of_samples=1)[1] should equal control_points[1]")


func test_bezier_sampling_matches_direct_evaluation_for_known_t_values() -> void:
	var control_points: Array = [
		Vector2(0.0, 0.0),
		Vector2(0.0, 10.0),
		Vector2(10.0, 10.0)
	]

	var number_of_samples: int = 4
	var sample_points: Array[Vector2] = Bezier.bezier_sampling(control_points, number_of_samples)
	assert_eq(sample_points.size(), number_of_samples + 1, "bezier_sampling(control_points, number_of_samples) should return number_of_samples + 1 points")

	for index: int in range(number_of_samples + 1):
		var time_ratio: float = float(index) / float(number_of_samples)
		var result: Vector2 = Bezier.bezier(time_ratio, control_points)
		assert_almost_eq(
			sample_points[index],
			result,
			Vector2(EPSILON, EPSILON),
			"bezier_sampling(control_points, number_of_samples) point at index=" + str(index) + " should equal bezier(time_ratio, control_points) for time_ratio=" + str(time_ratio)
		)


# -----------------------------
# Square error
# -----------------------------
func test_bezier_square_error_zero_when_ref_points_on_same_line() -> void:
	# current_points is a segment; ref_points are on the same segment
	var current_points: Array = [Vector2(0.0, 0.0), Vector2(10.0, 0.0)]
	var ref_points: Array = [
		Vector2(0.0, 0.0),
		Vector2(2.0, 0.0),
		Vector2(5.0, 0.0),
		Vector2(10.0, 0.0)
	]

	var error: float = Bezier.bezier_square_error(current_points, ref_points)
	assert_almost_eq(error, 0.0, 0.0001, "bezier_square_error(current_points, ref_points) should be ~0 when ref_points lie on the curve defined by current_points")


func test_bezier_square_error_increases_with_distance() -> void:
	var current_points: Array = [Vector2(0.0, 0.0), Vector2(10.0, 0.0)]

	var ref_points_near: Array = [
		Vector2(2.0, 0.5),
		Vector2(5.0, -0.5),
		Vector2(8.0, 0.5)
	]

	var ref_points_far: Array = [
		Vector2(2.0, 5.0),
		Vector2(5.0, -5.0),
		Vector2(8.0, 5.0)
	]

	var error_near: float = Bezier.bezier_square_error(current_points, ref_points_near)
	var error_far: float = Bezier.bezier_square_error(current_points, ref_points_far)

	assert_gt(error_near, 0.0, "bezier_square_error(current_points, ref_points) should be > 0 when ref_points are off the curve")
	assert_gt(error_far, error_near, "bezier_square_error should increase when ref_points are farther from the curve")


# -----------------------------
# Optional: behavior outside [0,1]
# -----------------------------
func test_bezier_extrapolates_outside_unit_interval() -> void:
	# Implementation does not clamp time_ratio; it extrapolates.
	var control_points: Array = [Vector2(0.0, 0.0), Vector2(10.0, 0.0)]

	var result_neg: Vector2 = Bezier.bezier(-0.5, control_points)
	var result_pos: Vector2 = Bezier.bezier(1.5, control_points)

	assert_almost_eq(
		result_neg,
		Vector2(-5.0, 0.0),
		Vector2(EPSILON, EPSILON),
		"bezier(time_ratio<0, control_points) should extrapolate linearly for a segment"
	)

	assert_almost_eq(
		result_pos,
		Vector2(15.0, 0.0),
		Vector2(EPSILON, EPSILON),
		"bezier(time_ratio>1, control_points) should extrapolate linearly for a segment"
	)
