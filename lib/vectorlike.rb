module VectorLike
  # add two vector-likes
  def vadd vec
    [x + vec.x, y + vec.y]
  end

  # subtract a vector-like from self
  def vsub vec
    [x - vec.x, y - vec.y]
  end

  # scale by dividing s
  def vdiv s
    [x / s, y / s]
  end

  # scale by multiplying s
  def vmul s
    [x * s, y * s]
  end

  # copy as vector only
  def vcp
    [x, y]
  end
end

class Array
  include VectorLike
end

class GTK::Mouse
  include VectorLike
end
