# Adapted from:
# https://github.com/gre/bezier-easing
# BezierEasing - use bezier curve for transition easing function
# by Gaëtan Renaudeau 2014 - 2015 – MIT License

module Bezier
  # These values are established by empiricism with tests (tradeoff: performance VS precision)
  NEWTON_ITERATIONS = 4
  NEWTON_MIN_SLOPE = 0.001
  SUBDIVISION_PRECISION = 0.0000001
  SUBDIVISION_MAX_ITERATIONS = 10
  K_SPLINE_TABLE_SIZE = 11
  K_SAMPLE_STEP_SIZE = 1.0 / (K_SPLINE_TABLE_SIZE - 1.0)

  def self.ease (mX1, mY1, mX2, mY2)
    mX1 = mX1.cap_min_max(0, 1)
    mX2 = mX2.cap_min_max(0, 1)

    if mX1 == mY1 && mX2 == mY2
      return proc { |t| t }
    end

    # precompute samples table
    sample_values = Array.new(K_SPLINE_TABLE_SIZE) do |i|
      calc_bezier(i * K_SAMPLE_STEP_SIZE, mX1, mX2)
    end

    get_t_for_x = lambda do |aX|
      interval_start = 0.0
      current_sample = 1
      last_sample = K_SPLINE_TABLE_SIZE - 1

      while current_sample != last_sample && sample_values[current_sample] <= aX
        interval_start += K_SAMPLE_STEP_SIZE
        current_sample += 1
      end
      current_sample -= 1

      # Interpolate to provide an initial guess for t
      dist = (aX - sample_values[current_sample]) / (sample_values[current_sample + 1] - sample_values[current_sample]).to_f
      guess_for_t = interval_start + dist * K_SAMPLE_STEP_SIZE

      initial_slope = get_slope(guess_for_t, mX1, mX2)
      if initial_slope >= NEWTON_MIN_SLOPE
        newton_raphson_iterate(aX, guess_for_t, mX1, mX2)
      elsif initial_slope == 0.0
        guess_for_t
      else
        binary_subdivide(aX, interval_start, interval_start + K_SAMPLE_STEP_SIZE, mX1, mX2)
      end
    end

    proc do |x|
      # because floats are imprecise, we should guarantee the extremes are right.
      if x == 0 || x == 1
        x
      else
        calc_bezier(get_t_for_x[x], mY1, mY2)
      end
    end
  end

  private

  def self.a aA1, aA2
    1.0 - 3.0 * aA2 + 3.0 * aA1
  end

  def self.b aA1, aA2
    3.0 * aA2 - 6.0 * aA1
  end

  def self.c aA1
    3.0 * aA1
  end

  # returns x(t) given t, x1, and x2, or y(t) given t, y1, and y2.
  def self.calc_bezier aT, aA1, aA2
    ((a(aA1, aA2) * aT + b(aA1, aA2)) * aT + c(aA1)) * aT
  end

  # returns dx/dt given t, x1, and x2, or dy/dt given t, y1, and y2.
  def self.get_slope aT, aA1, aA2
    3.0 * a(aA1, aA2) * aT * aT + 2.0 * b(aA1, aA2) * aT + c(aA1)
  end

  def self.binary_subdivide aX, aA, aB, mX1, mX2
    current_x = 0
    current_t = 0
    i = 0
    loop do
      current_t = aA + (aB - aA) / 2.0
      current_x = calc_bezier(current_t, mX1, mX2) - aX
      if current_x > 0.0
        aB = current_t
      else
        aA = current_t
      end
      break if current_x.abs <= SUBDIVISION_PRECISION
      i += 1
      break if i >= SUBDIVISION_MAX_ITERATIONS
    end
    current_t
  end

  def self.newton_raphson_iterate aX, a_guess_t, mX1, mX2
    (0...NEWTON_ITERATIONS).each do |i|
      current_slope = get_slope(a_guess_t, mX1, mX2)
      if current_slope == 0.0
        return a_guess_t
      end
      current_x = calc_bezier(a_guess_t, mX1, mX2) - aX
      a_guess_t -= current_x / current_slope
    end
    a_guess_t
  end
end
