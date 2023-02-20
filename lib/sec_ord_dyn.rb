require 'lib/vectormath_2d.rb'

# allows iterative solving of second-order dynamics to allow for direct control
# of some property but with some physicality added to it
class SecOrdDyn
  # f = natural frequency in Hz (how quickly it responds to change)
  # zeta = damping coefficient
  #  * =0 → infinite vibration
  #  * <1 → some vibration
  #  * ≥1 → no vibration, slowly approaching final state
  # r = responsiveness
  #  * <0 → wind-up/anticipation
  #  * =0 → slow response
  #  * >0 → immediate response
  #  * >1 → overshoot target
  # i0 = first input position
  # wrap = maximum x,y if the parameter space wraps around (0 means no wrap)
  def initialize f, zeta, r, i0, wrap = RVec2::ZERO
    params! f, zeta, r

    @wrap = wrap
    # input position
    @i = RVec2.new.set_from! i0
    # previous input position (used to estimate output velocity if update calls do not supply it)
    @i_prev = @i.dup
    # input velocity in pixels per second
    @i_vel = RVec2.new
    # output position
    @o = @i_prev.dup
    # output position wrapped
    @o_mod = @o.dup
    # output velocity
    @o_vel = RVec2.new
  end

  # change parameters of the system
  def params! f, zeta, r
    @f = f
    @zeta = zeta
    @r = r

    # second-order-system o + k1 o' + k2 o'' = i + k3 i'
    # where i input, o is output
    @k1 = zeta / (Math::PI * f)
    @k2 = 1 / (4 * Math::PI * Math::PI * f * f)
    @k3 = r * zeta / (2 * Math::PI * f)
  end

  # frame_rate should be args.gtk.current_framerate unless you're not doing this real-time
  # i is current input position
  # i_vel is input velocity (in pixels per second). if nil, this is estimated from previously supplied input position
  def update frame_rate, i, i_vel = nil
    @i.set_from! i
    # if wrapping, update @i to be as close as possible to @i_prev
    # TODO: this is very inefficient, probably can be made linear?
    if @wrap.x != 0
      while @i.x < @i_prev.x - @wrap.x / 2.0
        @i.x += @wrap.x
      end
      while @i.x > @i_prev.x + @wrap.x / 2.0
        @i.x -= @wrap.x
      end
    end
    if @wrap.y != 0
      while @i.y < @i_prev.y - @wrap.y / 2.0
        @i.y += @wrap.y
      end
      while @i.y > @i_prev.y + @wrap.y / 2.0
        @i.y -= @wrap.y
      end
    end

    if i_vel
      @i_vel.set_from! i_vel
    else # if no input velocity supplied, estimate it from last update
      @i_vel.sub_from!(@i, @i_prev).mul_scalar!(frame_rate)
    end
    @i_prev.set_from! @i

    # easy part: get new output position using previously calculated output velocity
    @o.add! @o_vel.div_scalar(frame_rate.to_f)

    # restrict k2 to avoid jitter and accumulating errors
    k2_stable = [@k2, (1 + frame_rate * @k1) / (2 * frame_rate * frame_rate), @k1 / frame_rate].max
    # hard part: get new output velocity by solving the system's equation for acceleration
    # first compute change in velocity (overwriting @i_vel to avoid allocations)
    @i_vel.mul_scalar!(@k3).add!(@i).sub!(@o).sub_mul_scalar!(@o_vel, @k1).div_scalar!(frame_rate * k2_stable)
    # add to output velocity
    @o_vel.add!(@i_vel)

    # new output position
    @o_mod.set_from! @o
    @o_mod.mod! @wrap
  end
end
