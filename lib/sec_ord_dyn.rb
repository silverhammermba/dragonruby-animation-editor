require 'lib/vectorlike.rb'

# allows iterative solving of second-order dynamics to allow for direct control
# of some property but with some physicality added to it
class SecOrdDyn
  # f = natural frequency in Hz (how quickly it responds to change)
  # zeta = damping coefficient (0 = infinite vibration, <1 = some vibration, >=1 = no vibration, slowly approaching final state)
  # r = responsiveness (<0 = wind-up/anticipation, 0 = slow response, >0 = immediate response, >1 = overshoot target)
  # i0 = first input position
  def initialize f, zeta, r, i0
    # second-order-system o + k1 o' + k2 o'' = i + k3 i'
    # where i input, o is output
    @k1 = zeta / (Math::PI * f)
    @k2 = 1 / (4 * Math::PI * Math::PI * f * f)
    @k3 = r * zeta / (2 * Math::PI * f)
    # previous input position (used to estimate output velocity if update calls do not supply it)
    @in_prev = i0.vcp
    # output position
    @out = i0.vcp
    # output velocity
    @out_vel = [0, 0]
  end

  # frame_rate should be args.gtk.current_framerate unless you're not doing this real-time
  # i is current input position
  # id is input velocity (in pixels per second). if nil, this is estimated from previously supplied input position
  def update frame_rate, i, id = nil
    # if no input velocity supplied, estimate it from last update
    id ||= i.vsub(@in_prev).vmul(frame_rate)
    @in_prev = i.vcp

    # easy part: get new output position using previously calculated output velocity
    @out = @out.vadd(@out_vel.vdiv(frame_rate.to_f))

    # restrict k2 to avoid jitter and accumulating errors
    k2_stable = [@k2, (1 + frame_rate * @k1) / (2 * frame_rate * frame_rate), @k1 / frame_rate].max
    # hard part: get new output velocity by solving the system's equation for acceleration
    @out_vel = @out_vel.vadd(i.vadd(id.vmul(@k3)).vsub(@out).vsub(@out_vel.vmul(@k1)).vdiv(frame_rate * k2_stable))

    # new output position
    @out.vcp
  end
end
