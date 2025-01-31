###
# wxRuby3 geometry classes
# Copyright (c) M.J.N. Corino, The Netherlands
###


module Wx

  class Size

    # Returns size array (`[width, height]`)
    # @return [Array(Integer,Integer)] size as array
    def to_ary; end

    # Compare size values (Wx::Size or size array). Throws exception if incompatible.
    # @param [Wx::Size,Array(Integer,Integer)] other
    # @return [Boolean]
    def ==(other)end

    # Compare sizes.
    # @param [Wx::Size] other
    # @return [Boolean]
    def eql?(other)end

    # Return a new Wx::Size with the width and height values both divided
    # by parameter +num+, which should be a Numeric
    # @param [Numeric] num
    # @return [Wx::Size]
    def /(num) end

    # Return a new Wx::Size with the width and height values both multiplied
    # by parameter +num+, which should be a Numeric
    # @param [Numeric] num
    # @return [Wx::Size]
    def *(num) end

    # Return a new Wx::Size with the width and height parameters both
    # reduced by parameter +arg+. If +arg+ is another Wx::Size (or 2-element array), reduce
    # width by the other's width and height by the other's height; if
    # +arg+ is a numeric value, reduce both width and height by that
    # value.
    # @param [Wx::Size,Array(Integer,Integer),Numeric] arg
    # @return [Wx::Size]
    def -(arg) end

    # Return a new Wx::Size with the width and height parameters both
    # increased by parameter +arg+. If +arg+ is another Wx::Size (or 2-element array), increase
    # width by the other's width and height by the other's height; if
    # +arg+ is a numeric value, increase both width and height by that
    # value.
    # @param [Wx::Size,Array(Integer,Integer),Numeric] arg
    # @return [Wx::Size]
    def +(arg) end

  end

  class Point

    # Returns point array (`[x, y]`)
    # @return [Array(Integer,Integer)] point as array
    def to_ary; end

    # Compare point values (Wx::Point or point array). Throws exception if incompatible.
    # @param [Wx::Point,Array(Integer,Integer)] other
    # @return [Boolean]
    def ==(other)end

    # Compare points.
    # @param [Wx::Point] other
    # @return [Boolean]
    def eql?(other)end

    # Return a new Wx::Point with the x and y parameters both divided by
    # parameter +num+, which should be a Numeric
    # @param [Numeric] num
    # @return [Wx::Point]
    def /(num) end

    # Return a new Wx::Point with the x and y values both multiplied by
    # parameter +num+, which should be a Numeric
    # @param [Numeric] num
    # @return [Wx::Point]
    def *(num) end

    # Return a new Wx::Point with the x and y values both reduced by
    # parameter +arg+. If +arg+ is another Wx::Point (or Wx::Size or 2-element array), reduce x by the
    # other's x (or width) and y by the other's y (or height); if +arg+ is a numeric value,
    # reduce x and y both by that value.
    # @param [Wx::Point,Wx::Size,Array(Integer,Integer),Numeric] arg
    # @return [Wx::Point]
    def -(arg) end

    # Return a new Wx::Point with the x and y values both increased by
    # parameter +arg+. If +arg+ is another Wx::Point (or Wx::Size or 2-element array), increase x by the
    # other's x (or width) and y by the other's y (or height); if +arg+ is a numeric value,
    # increase both x and y by that value.
    # @param [Wx::Point,Wx::Size,Array(Integer,Integer),Numeric] arg
    # @return [Wx::Point]
    def +(arg) end
    
  end

  class RealPoint

    # Returns point array (`[x, y]`)
    # @return [Array(Float,Float)] point as array
    def to_ary; end

    # Compare point values (Wx::RealPoint or point array). Throws exception if incompatible.
    # @param [Wx::RealPoint,Array(Float,Float)] other
    # @return [Boolean]
    def ==(other)end

    # Compare points.
    # @param [Wx::RealPoint] other
    # @return [Boolean]
    def eql?(other)end

    # Return a new Wx::RealPoint with the x and y parameters both divided by
    # parameter +num+, which should be a Numeric
    # @param [Numeric] num
    # @return [Wx::RealPoint]
    def /(num) end

    # Return a new Wx::RealPoint with the x and y values both multiplied by
    # parameter +num+, which should be a Numeric
    # @param [Numeric] num
    # @return [Wx::RealPoint]
    def *(num) end

    # Return a new Wx::RealPoint with the x and y values both reduced by
    # parameter +arg+. If +arg+ is another Wx::(Real)Point (or Wx::Size or 2-element array), reduce x by the
    # other's x (or width) and y by the other's y (or height); if +arg+ is a numeric value,
    # reduce x and y both by that value.
    # @param [Wx::RealPoint,Wx::Point,Wx::Size,Array(Float,Float),Numeric] arg
    # @return [Wx::RealPoint]
    def -(arg) end

    # Return a new Wx::RealPoint with the x and y values both increased by
    # parameter +arg+. If +arg+ is another Wx::(Real)Point (or Wx::Size or 2-element array), increase x by the
    # other's x (or width) and y by the other's y (or height); if +arg+ is a numeric value,
    # increase both x and y by that value.
    # @param [Wx::RealPoint,Wx::Point,Wx::Size,Array(Float,Float),Numeric] arg
    # @return [Wx::RealPoint]
    def +(arg) end

  end

  class Rect

    # Returns rect array (`[left, top, width, height]`)
    # @return [Array(Integer,Integer,Integer,Integer)] rect as array
    def to_ary; end

    # Compare area values (Wx::Rect or 4-element array). Throws exception if incompatible.
    # @param [Wx::Rect,Array(Integer,Integer,Integer,Integer)] other
    # @return [Boolean]
    def ==(other)end

    # Compare areas.
    # @param [Wx::Rect] other
    # @return [Boolean]
    def eql?(other)end

    alias :& :intersect

    alias :| :union

    # Returns the overlap of the rectangle areas.
    # Does not check negative or zero overlap like #intersect.
    # @param [Wx::Rect] rect
    def *(rect) end

    # Modifies the rectangle to contain the bounding box of this rectangle and the one passed in as parameter.
    # Does not ignore empty rectangles like #union
    # @param [Wx::Rect] rect
    def +(rect) end

  end

end
