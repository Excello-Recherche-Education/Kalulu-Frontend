extends GutTest
class_name TestBezier

const EPS: float = 0.00001


func before_each() -> void:
	Bezier.factorial_cache = {}


# -----------------------------
# Factorial
# -----------------------------

func test_factorial_basic_values() -> void:
	assert_eq(Bezier.factorial(0), 1)
	assert_eq(Bezier.factorial(1), 1)
	assert_eq(Bezier.factorial(5), 120)


func test_factorial_cache_is_filled_and_reused() -> void:
	assert_false(0 in Bezier.factorial_cache, "Cache should be empty after before_each")
	assert_false(5 in Bezier.factorial_cache, "Cache should be empty after before_each")

	var a: int = Bezier.factorial(5)
	assert_eq(a, 120)
	assert_true(5 in Bezier.factorial_cache, "factorial(5) should populate cache")
	assert_eq(Bezier.factorial_cache[5], 120)

	var b: int = Bezier.factorial(5)
	assert_eq(b, 120, "Second call should return same result (cache hit expected)")


# -----------------------------
# Binomial
# -----------------------------

func test_binomial_invalid_inputs_return_zero() -> void:
	assert_eq(Bezier.binomial(-1, 3), 0)
	assert_eq(Bezier.binomial(2, -1), 0)
	assert_eq(Bezier.binomial(5, 2), 0) # index > degree


func test_binomial_known_values() -> void:
	assert_eq(Bezier.binomial(0, 0), 1)
	assert_eq(Bezier.binomial(0, 5), 1)
	assert_eq(Bezier.binomial(5, 5), 1)

	assert_eq(Bezier.binomial(1, 3), 3)
	assert_eq(Bezier.binomial(2, 4), 6)
	assert_eq(Bezier.binomial(3, 6), 20)


func test_binomial_symmetry_identity() -> void:
	var n: int = 7
	for k: int in range(n + 1):
		assert_eq(Bezier.binomial(k, n), Bezier.binomial(n - k, n), "C(k,n) should equal C(n-k,n)")


# -----------------------------
# Bernstein polynomials
# -----------------------------

func test_bernstein_weights_sum_to_one_multiple_t() -> void:
	var degree: int = 5
	var ts: Array[float] = [0.0, 0.25, 0.5, 0.77, 1.0]
	for t: float in ts:
		var total: float = 0.0
		for i: int in range(degree + 1):
			total += Bezier.bernstein(t, degree, i)
		assert_almost_eq(total, 1.0, 0.0001, "Sum of Bernstein weights should be 1 for t=" + str(t))


func test_bernstein_endpoints_are_kronecker_delta() -> void:
	var degree: int = 6

	# t = 0 => B(degree,0)=1, others 0
	for i: int in range(degree + 1):
		var w0: float = Bezier.bernstein(0.0, degree, i)
		if i == 0:
			assert_almost_eq(w0, 1.0, EPS, "At t=0, first weight should be 1")
		else:
			assert_almost_eq(w0, 0.0, EPS, "At t=0, non-first weights should be 0")

	# t = 1 => B(degree,degree)=1, others 0
	for i: int in range(degree + 1):
		var w1: float = Bezier.bernstein(1.0, degree, i)
		if i == degree:
			assert_almost_eq(w1, 1.0, EPS, "At t=1, last weight should be 1")
		else:
			assert_almost_eq(w1, 0.0, EPS, "At t=1, non-last weights should be 0")


func test_bernstein_non_negative_on_unit_interval() -> void:
	var degree: int = 6
	var ts: Array[float] = [0.0, 0.1, 0.33, 0.5, 0.9, 1.0]
	for t: float in ts:
		for i: int in range(degree + 1):
			var w: float = Bezier.bernstein(t, degree, i)
			assert_gte(w, 0.0, "Bernstein weights should be >= 0 on [0,1]")
			assert_lte(w, 1.0, "Bernstein weights should be <= 1 on [0,1]")


# -----------------------------
# Bezier curve evaluation
# -----------------------------

func test_bezier_degree_zero_returns_single_point() -> void:
	var control_points: Array = [Vector2(2.0, -3.0)]
	var ts: Array[float] = [0.0, 0.25, 0.5, 1.0]
	for t: float in ts:
		assert_eq(Bezier.bezier(t, control_points), Vector2(2.0, -3.0))


func test_bezier_endpoints_match_first_and_last_control_points() -> void:
	var control_points: Array[Vector2] = [
		Vector2(0.0, 0.0),
		Vector2(4.0, 10.0),
		Vector2(9.0, -2.0),
		Vector2(10.0, 0.0)
	]
	assert_eq(Bezier.bezier(0.0, control_points), control_points[0], "t=0 must return first point")
	assert_eq(Bezier.bezier(1.0, control_points), control_points[control_points.size() - 1], "t=1 must return last point")


func test_bezier_linear_segment_midpoint() -> void:
	var control_points: Array = [Vector2(0.0, 0.0), Vector2(10.0, 0.0)]
	var midpoint: Vector2 = Bezier.bezier(0.5, control_points)
	assert_eq(midpoint, Vector2(5.0, 0.0))


func test_bezier_quadratic_known_point_at_half() -> void:
	# Quadratic: P(t) = (1-t)^2 P0 + 2(1-t)t P1 + t^2 P2
	# Choose easy points so t=0.5 is predictable.
	var p0: Vector2 = Vector2(0.0, 0.0)
	var p1: Vector2 = Vector2(0.0, 10.0)
	var p2: Vector2 = Vector2(10.0, 10.0)
	var control_points: Array = [p0, p1, p2]

	var p_half: Vector2 = Bezier.bezier(0.5, control_points)
	# At t=0.5 => 0.25*p0 + 0.5*p1 + 0.25*p2 = (2.5, 7.5)
	assert_almost_eq(p_half, Vector2(2.5, 7.5), Vector2(EPS, EPS), "Quadratic at t=0.5 should match expected value")


func test_bezier_points_stay_within_control_bounds_for_axis_aligned_segment() -> void:
	# For a 1D monotonic case (all y=0, x increasing), x(t) must stay within [min,max] for t in [0,1].
	var control_points: Array = [
		Vector2(0.0, 0.0),
		Vector2(2.0, 0.0),
		Vector2(7.0, 0.0),
		Vector2(10.0, 0.0)
	]
	var ts: Array[float] = [0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0]
	for t: float in ts:
		var p: Vector2 = Bezier.bezier(t, control_points)
		assert_between(p.x, 0.0, 10.0, "x should remain within [0,10] for t in [0,1]")
		assert_almost_eq(p.y, 0.0, EPS, "y should remain 0 in this configuration")


func test_bezier_translation_invariance() -> void:
	var control_points: Array = [
		Vector2(1.0, 2.0),
		Vector2(3.0, 5.0),
		Vector2(8.0, -1.0)
	]
	var offset: Vector2 = Vector2(100.0, -50.0)
	var translated: Array = []
	for p: Vector2 in control_points:
		translated.append(p + offset)

	var t: float = 0.37
	var a: Vector2 = Bezier.bezier(t, control_points)
	var b: Vector2 = Bezier.bezier(t, translated)
	assert_almost_eq(b, a + offset, Vector2(EPS, EPS), "Bezier should be translation invariant")


func test_bezier_scaling_invariance() -> void:
	var control_points: Array = [
		Vector2(1.0, 2.0),
		Vector2(3.0, 5.0),
		Vector2(8.0, -1.0)
	]
	var scale: float = 3.0
	var scaled: Array = []
	for p: Vector2 in control_points:
		scaled.append(p * scale)

	var t: float = 0.61
	var a: Vector2 = Bezier.bezier(t, control_points)
	var b: Vector2 = Bezier.bezier(t, scaled)
	assert_almost_eq(b, a * scale, Vector2(EPS, EPS), "Bezier should scale linearly with control points")


# -----------------------------
# Sampling
# -----------------------------

func test_bezier_sampling_handles_sample_counts() -> void:
	var control_points: Array = [Vector2(0.0, 0.0), Vector2(10.0, 0.0)]
	assert_eq(Bezier.bezier_sampling(control_points, 0).size(), 0)
	assert_eq(Bezier.bezier_sampling(control_points, -3).size(), 0)

	var samples: Array[Vector2] = Bezier.bezier_sampling(control_points, 2)
	assert_eq(samples.size(), 3)
	assert_eq(samples[0], Vector2(0.0, 0.0))
	assert_eq(samples[2], Vector2(10.0, 0.0))


func test_bezier_sampling_sample_count_one_returns_two_points() -> void:
	var control_points: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(10.0, 0.0)]
	var samples: Array[Vector2] = Bezier.bezier_sampling(control_points, 1)
	assert_eq(samples.size(), 2)
	assert_eq(samples[0], control_points[0])
	assert_eq(samples[1], control_points[1])


func test_bezier_sampling_matches_direct_evaluation_for_known_t_values() -> void:
	var control_points: Array = [
		Vector2(0.0, 0.0),
		Vector2(0.0, 10.0),
		Vector2(10.0, 10.0)
	]
	var n: int = 4
	var samples: Array[Vector2] = Bezier.bezier_sampling(control_points, n)
	assert_eq(samples.size(), n + 1)

	for i: int in range(n + 1):
		var t: float = float(i) / float(n)
		var direct: Vector2 = Bezier.bezier(t, control_points)
		assert_almost_eq(samples[i], direct, Vector2(EPS, EPS), "Sample should equal direct evaluation at t=" + str(t))


# -----------------------------
# Square error
# -----------------------------

func test_bezier_square_error_zero_when_ref_points_on_same_line() -> void:
	# Current points: straight line from (0,0) to (10,0)
	var current_points: Array = [Vector2(0.0, 0.0), Vector2(10.0, 0.0)]
	# Reference points on that same segment
	var ref_points: Array = [Vector2(0.0, 0.0), Vector2(2.0, 0.0), Vector2(5.0, 0.0), Vector2(10.0, 0.0)]

	var err: float = Bezier.bezier_square_error(current_points, ref_points)
	assert_almost_eq(err, 0.0, 0.0001, "Error should be ~0 when ref points lie on the curve")


func test_bezier_square_error_increases_with_distance() -> void:
	var current_points: Array = [Vector2(0.0, 0.0), Vector2(10.0, 0.0)]
	var ref_points_near: Array = [Vector2(2.0, 0.5), Vector2(5.0, -0.5), Vector2(8.0, 0.5)]
	var ref_points_far: Array = [Vector2(2.0, 5.0), Vector2(5.0, -5.0), Vector2(8.0, 5.0)]

	var err_near: float = Bezier.bezier_square_error(current_points, ref_points_near)
	var err_far: float = Bezier.bezier_square_error(current_points, ref_points_far)

	assert_gt(err_near, 0.0, "Near points off the curve should yield positive error")
	assert_gt(err_far, err_near, "Farther points should produce larger squared error than nearer points")


# -----------------------------
# Optional: behavior outside [0,1]
# -----------------------------

func test_bezier_extrapolates_outside_unit_interval() -> void:
	# Current implementation does not clamp t; it extrapolates.
	# For a line segment, extrapolation is linear and predictable.
	var control_points: Array = [Vector2(0.0, 0.0), Vector2(10.0, 0.0)]
	var p_neg: Vector2 = Bezier.bezier(-0.5, control_points) # expected -5 on x
	var p_pos: Vector2 = Bezier.bezier(1.5, control_points)  # expected 15 on x

	assert_almost_eq(p_neg, Vector2(-5.0, 0.0), Vector2(EPS, EPS), "t<0 should extrapolate linearly for a segment")
	assert_almost_eq(p_pos, Vector2(15.0, 0.0), Vector2(EPS, EPS), "t>1 should extrapolate linearly for a segment")
