require 'lib/bezier.rb'

# ./dragonruby mygame --test test/bezier.rb

class GTK::Assert
  def approx! actual, expected
    epsilon = 0.000000000000001
    diff = (actual - expected).abs
    true!(diff <= epsilon, "|#{actual} - #{expected}| = #{diff} > epsilon")
  end
end

def test_linear args, assert
  b = Bezier.ease 0.2, 0.2, 0.8, 0.8

  (-10..20).each do |i|
    t = i / 10.0
    assert.equal! b[t], t
  end
end

def test_default args, assert
  b = Bezier.ease(0.21, -0.52, 0.59, 1.48)

  assert.equal!  b[0.0], 0.0
  assert.approx! b[0.1], -0.08314868804664724
  assert.approx! b[0.2], 0.02419790486274163
  assert.approx! b[0.3], 0.2132240884412278
  assert.approx! b[0.4], 0.4303693036672633
  assert.approx! b[0.5], 0.643370084600597
  assert.approx! b[0.6], 0.8299040156717838
  assert.approx! b[0.7], 0.9727626602432669
  assert.approx! b[0.8], 1.057440645523788
  assert.approx! b[0.9], 1.070763157004148
  assert.equal!  b[1.0], 1.0
end
