require 'lib/sec_ord_dyn.rb'

# ./dragonruby mygame --test test/sec_ord_dyn.rb

class GTK::Assert
  def approx! actual, expected
    epsilon = 0.000000000000001
    diff = (actual - expected).abs
    true!(diff <= epsilon, "|#{actual} - #{expected}| = #{diff} > epsilon")
  end
end

def test_default args, assert
  s = SecOrdDyn.new(1, 0.5, 2, [0, 0])
  y = nil
  tick = proc { y = s.update(60.0, [0, 1]).y }

  tick[]
  assert.approx! y, 0

  6.times { tick[] }
  assert.approx! y, 0.6401603039924396

  5.times { tick[] }
  assert.approx! y, 1.02003477059124

  9.times { tick[] }
  assert.approx! y, 1.30132293853358

  24.times { tick[] }
  assert.approx! y, 1.006521033762751

  12.times { tick[] }
  assert.approx! y, 0.9530871720424233
end

def test_oscillate args, assert
  s = SecOrdDyn.new(4, 0.2, 1, [0, 0])
  y = nil
  tick = proc { y = s.update(60.0, [0, 1]).y }

  tick[]
  assert.approx! y, 0

  6.times { tick[] }
  assert.approx! y, 1.561293143381125

  8.times { tick[] }
  assert.approx! y, 0.7157876101982704

  7.times { tick[] }
  assert.approx! y, 1.148456270963284

  8.times { tick[] }
  assert.approx! y, 0.9294946620975569

  6.times { tick[] }
  assert.approx! y, 1.038843138482776

  8.times { tick[] }
  assert.approx! y, 0.9801166970563973

  7.times { tick[] }
  assert.approx! y, 1.010345822887281
end
