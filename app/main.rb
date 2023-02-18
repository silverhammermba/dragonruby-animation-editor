require 'lib/bezier.rb'
require 'lib/clipboard.rb'
require 'lib/enum_utils.rb'
require 'lib/sec_ord_dyn.rb'

# convert an easing curve coord to a window coord for drawing
def coord_ease2win args, coord
  [coord[0] * args.state.window_size + args.state.lr_margin, (coord[1] + 1) * args.state.window_size + args.state.tb_margin]
end

# convert a window curve coord (e.g., from input) to an easing curve coord to interact with it
def coord_win2ease args, coord
  [(coord[0] - args.state.lr_margin) / args.state.window_size, (coord[1] - args.state.tb_margin) / args.state.window_size - 1]
end

# get the bottom left corner, width, and height of a square, suitable for drawing or doing intersection tests
def square_at center, size
  center.map { |v| v - size / 2.0 } + [size, size]
end

# construct a new bezier curve animation based on the control points in args
def preview_anim args
  Enumerator.new { |yielder|
    ease = Bezier.ease(*(args.state.cps[0][2...4] + args.state.cps[1][0...2]))
    args.state.sprite_pos = args.state.left
    loop do
      yielder.run(
        ecount(0.5.seconds) +
        eease(1.seconds, ease) { |t|
          args.state.sprite_pos = t.lerp(args.state.left, args.state.right)
        } +
        ecount(0.5.seconds) +
        eease(1.seconds, ease) { |t|
          args.state.sprite_pos = t.lerp(args.state.right, args.state.left)
        }
      )
    end
  }
end

def tick_bezier args
  # control points
  args.state.cps ||= [
    # start point, handle
    [0, 0, 0.21, -0.52],
    # handle, end point
    [0.59, 1.48, 1, 1]
  ]

  args.state.lr_margin = 30
  args.state.tb_margin = 30
  args.state.window_size = (args.grid.h - args.state.tb_margin * 2) / 3.0

  args.state.point_size = 8
  args.state.selection_slop = 4

  args.state.preview_sprite_w = 128
  args.state.preview_padding = 10
  args.state.left = args.state.lr_margin * 2 + args.state.window_size + args.state.preview_padding
  args.state.right = args.grid.w - args.state.lr_margin - args.state.preview_sprite_w - args.state.preview_padding

  args.state.preview ||= preview_anim args

  # get selection areas for each handle
  handle_sel_areas = args.state.cps.map.with_index { |c, i| square_at(coord_ease2win(args, c[(2 - i * 2)...(4 - i * 2)]), args.state.point_size + args.state.selection_slop) }
  # which handles are under the mouse?
  mouse_over = handle_sel_areas.map do |r|
    args.inputs.mouse.inside_rect? r
  end

  args.state.params ||= "Bezier.ease(%.2f, %.2f, %.2f, %.2f)" % (args.state.cps[0][2...4] + args.state.cps[1][0...2])

  # did we start/stop selecting a handle?
  if click = args.inputs.mouse.down
    if mouse_over[0]
      args.state.handle_selection = 0
    elsif mouse_over[1]
      args.state.handle_selection = 1
    end
  elsif args.state.handle_selection && !args.inputs.mouse.button_left
    args.state.handle_selection = nil
    args.state.preview = preview_anim args
    args.state.params = "Bezier.ease(%.2f, %.2f, %.2f, %.2f)" % (args.state.cps[0][2...4] + args.state.cps[1][0...2])
  end

  # move selected handle to mouse position
  if args.state.handle_selection
    ex, ey = coord_win2ease(args, [args.inputs.mouse.x, args.inputs.mouse.y])
    args.state.cps[args.state.handle_selection][2 - args.state.handle_selection * 2] = ex.cap_min_max(0, 1)
    args.state.cps[args.state.handle_selection][3 - args.state.handle_selection * 2] = ey
  end

  args.state.copy_opacity ||= 0

  if args.inputs.keyboard.ctrl_c && args.state.clipboard_support
    Clipboard.copy args.state.params
    args.state.copy_anim = eease(1.seconds, Bezier.ease(0.31, 0.52, 0.70, 0.95)) { |t|
      args.state.copy_opacity = 255 * (1 - t)
    }
  end

  # draw easing canvas area
  outside_color = 200
  args.outputs.borders << [args.state.lr_margin, args.state.tb_margin, args.state.window_size, args.state.window_size, outside_color, outside_color, outside_color]
  args.outputs.borders << [args.state.lr_margin, args.state.tb_margin + args.state.window_size * 2, args.state.window_size, args.state.window_size, outside_color, outside_color, outside_color]
  args.outputs.borders << [args.state.lr_margin, args.state.tb_margin + args.state.window_size, args.state.window_size, args.state.window_size]

  # scale/shift control points to match window size and position for drawing purposes
  scps = args.state.cps.map do |pair|
    coord_ease2win(args, pair[0...2]) + coord_ease2win(args, pair[2...4])
  end

  args.outputs.lines << scps[0][0...2] + scps[1][2...4] + [150, 150, 150]

  # iteratively draw approximate bezier curve
  num_samples = 20
  bezier_color = [0, 127, 255]

  prev = scps[0][0...2]
  max_samples = num_samples.to_f
  (1..num_samples).each do |t|
    x = GTK::Geometry.cubic_bezier(t / max_samples, scps[0][0], scps[0][2], scps[1][0], scps[1][2])
    y = GTK::Geometry.cubic_bezier(t / max_samples, scps[0][1], scps[0][3], scps[1][1], scps[1][3])
    nxt = [x, y]
    args.outputs.lines << prev + nxt + bezier_color
    prev = nxt
  end
  args.outputs.lines << prev + scps[1][2...4] + bezier_color

  # draw lines to handles
  args.outputs.lines << scps[0]
  args.outputs.lines << scps[1]

  # draw handles
  args.outputs.solids << square_at(scps[0][2...4], args.state.point_size)
  args.outputs.solids << square_at(scps[1][0...2], args.state.point_size)

  # draw handle selection
  if mouse_over[0]
    args.outputs.borders << handle_sel_areas[0]
  end
  if mouse_over[1]
    args.outputs.borders << handle_sel_areas[1]
  end

  # advance preview animation
  args.state.preview.next

  preview_h = 300

  # draw boundary to show start/stop position
  args.outputs.solids << [
    args.state.left - args.state.preview_padding,
    preview_h - args.state.preview_padding,
    (args.state.right - args.state.left) + args.state.preview_sprite_w + args.state.preview_padding * 2,
    101 + args.state.preview_padding * 2,
    127, 127, 127
  ]

  # draw animated sprite
  args.outputs.sprites << {
    x: args.state.sprite_pos,
    y: preview_h,
    w: args.state.preview_sprite_w,
    h: 101,
    path: 'dragonruby.png',
  }

  label_x = args.state.left - args.state.preview_padding
  label_y = preview_h + 101 + args.state.preview_padding + 40

  if args.state.copy_anim
    begin
      args.state.copy_anim.next
    rescue
      args.state.copy_anim = nil
    end
  end
  copy_color = [0, 0, 0, args.state.copy_opacity]
  args.outputs.labels << [label_x, label_y + 40, "Copied!"] + copy_color

  args.outputs.labels << [label_x, label_y, (args.state.clipboard_support ? "Ctrl-C to copy " : "") + args.state.params]
end

def tick_dynamics args
  args.state.sprite_width = 128
  args.state.sprite_height = 101

  args.state.dyn_graph_in ||= Array.new(1.seconds, 0) + Array.new(2.seconds, 1)

  # wrap in arrays so we can hold references to them
  args.state.f ||= [1]
  args.state.z ||= [0.5]
  args.state.r ||= [2]

  # string versions so we can show consistent UI for input
  args.state.f_str ||= args.state.f[0].to_s
  args.state.z_str ||= args.state.z[0].to_s
  args.state.r_str ||= args.state.r[0].to_s

  # changing which parameter we're editing
  args.state.f_color ||= []
  args.state.z_color ||= []
  args.state.r_color ||= []

  if args.inputs.keyboard.key_down.f
    args.state.param_selection = args.state.f
    args.state.str_selection = args.state.f_str

    args.state.f_color = [255, 0, 0]
    args.state.z_color = []
    args.state.r_color = []
  elsif args.inputs.keyboard.key_down.z
    args.state.param_selection = args.state.z
    args.state.str_selection = args.state.z_str

    args.state.f_color = []
    args.state.z_color = [255, 0, 0]
    args.state.r_color = []
  elsif args.inputs.keyboard.key_down.r
    args.state.param_selection = args.state.r
    args.state.str_selection = args.state.r_str

    args.state.f_color = []
    args.state.z_color = []
    args.state.r_color = [255, 0, 0]
  end

  changed = false

  # backspace does what you expect
  if args.inputs.keyboard.key_down.backspace && args.state.str_selection
    args.state.str_selection.chop!
    changed = true
  end

  # first character can be hyphen
  if args.inputs.keyboard.key_down.hyphen && args.state.str_selection && args.state.str_selection == ""
    args.state.str_selection << "-"
    changed = true
  end

  # can add at most one period
  if args.inputs.keyboard.key_down.period && args.state.str_selection && !args.state.str_selection.include?(?.)
    args.state.str_selection << "."
    changed = true
  end

  # can add numbers
  if args.state.str_selection && args.inputs.text.size > 0
    args.inputs.text.each do |c|
      next unless (48..57).include?(c.ord)
      args.state.str_selection << c
      changed = true
    end
  end

  # if we changed a param or it's the first frame, update dynamics
  if changed || !args.state.dyn_graph_out
    if args.state.str_selection
      begin
        args.state.param_selection[0] = Float(args.state.str_selection)
      rescue
        # invalid float, don't freak out. wait for more input
      end
    end

    # clamp to avoid bad values
    if args.state.f[0] <= 0.01
      args.state.f[0] = 0.01
    end
    if args.state.z[0] < 0
      args.state.z[0] = 0
    end

    f = args.state.f[0]
    z = args.state.z[0]
    r = args.state.r[0]

    args.state.dyn = SecOrdDyn.new(f, z, r, args.inputs.mouse)

    # update static preview
    dyn = SecOrdDyn.new(f, z, r, [0, 0])
    args.state.dyn_graph_out = args.state.dyn_graph_in.map { |i|
      dyn.update(60, [0, i]).y
    }
  end

  params = "SecOrdDyn.new(%.2f, %.2f, %.2f, start)" % [args.state.f[0], args.state.z[0], args.state.r[0]]

  args.state.copy_opacity ||= 0

  if args.inputs.keyboard.ctrl_c && args.state.clipboard_support
    Clipboard.copy params
    args.state.copy_anim = eease(1.seconds, Bezier.ease(0.31, 0.52, 0.70, 0.95)) { |t|
      args.state.copy_opacity = 255 * (1 - t)
    }
  end

  max = [args.state.dyn_graph_out.max, 1.5].max
  min = [args.state.dyn_graph_out.min, -0.5].min
  span = max - min

  prev_in = args.state.dyn_graph_in[0]
  prev_out = args.state.dyn_graph_out[0]
  x_scale = args.grid.w / (args.state.dyn_graph_out.size - 1).to_f
  y_scale = args.grid.h / span

  # batch preview for better performance
  preview_lines = []

  args.state.dyn_graph_out[1..-1].each_with_index do |y_out, i|
    y_in = args.state.dyn_graph_in[i]
    # draw input shifted by 1, since the dynamics are delayed a frame
    preview_lines << {x: i * x_scale, y: (prev_in - min) * y_scale, x2: (i + 1) * x_scale, y2: (y_in - min) * y_scale, r: 150, g: 150, b: 150}
    # draw output
    preview_lines << {x: i * x_scale, y: (prev_out - min) * y_scale, x2: (i + 1) * x_scale, y2: (y_out - min) * y_scale}
    prev_out = y_out
    prev_in = y_in
  end
  args.outputs.lines << preview_lines

  # reference point
  args.outputs.labels << [120 * x_scale, (1 - min) * y_scale, "T+1s"]

  # system input is mouse position
  target = args.state.dyn.update(args.gtk.current_framerate, args.inputs.mouse)

  # sprite position is sytem's output
  args.state.sprite.x = target.x
  args.state.sprite.y = target.y

  args.outputs.sprites << [args.state.sprite.x - args.state.sprite_width / 2.0, args.state.sprite.y - args.state.sprite_height / 2.0, args.state.sprite_width, args.state.sprite_height, 'dragonruby.png']

  # params
  args.outputs.labels << [80, 600, "f = #{args.state.f_str}"] + args.state.f_color
  args.outputs.labels << [80, 500, "z = #{args.state.z_str}"] + args.state.z_color
  args.outputs.labels << [80, 400, "r = #{args.state.r_str}"] + args.state.r_color

  if args.state.copy_anim
    begin
      args.state.copy_anim.next
    rescue
      args.state.copy_anim = nil
    end
  end
  copy_color = [0, 0, 0, args.state.copy_opacity]
  args.outputs.labels << [80, 140, "Copied!"] + copy_color
  args.outputs.labels << [80, 100, (args.state.clipboard_support ? "Ctrl-C to copy " : "") + params]
end

def tick args
  if args.state.clipboard_support.nil?
    begin
      Clipboard.copy ''
      args.state.clipboard_support = true
    rescue
      args.state.clipboard_support = false
    end
  end

  args.state.mode ||= :bezier

  if args.inputs.keyboard.key_down.escape
    args.gtk.request_quit
  end

  args.outputs.labels << {
    x: 640,
    y: 0,
    text: "Available modes: [B]ezier easing, Second-Order [D]ynamics",
    alignment_enum: 1,
    vertical_alignment_enum: 0
  }

  if args.inputs.keyboard.key_down.b
    args.state.mode = :bezier
  elsif args.inputs.keyboard.key_down.d
    args.state.mode = :dynamics
  end

  case args.state.mode
  when :bezier
    tick_bezier args
  when :dynamics
    tick_dynamics args
  end
end
