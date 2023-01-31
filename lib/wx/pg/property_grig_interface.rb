
module Wx::PG

  module PropertyGridInterface

    wx_each_property = instance_method :each_property
    define_method :each_property do |flags = Wx::PG::PG_ITERATE_DEFAULT, start = nil, recurse: true|
      if block_given?
        wx_each_property.bind(self).call(flags.to_int, start, recurse)
      else
        ::Enumerator.new { |y| wx_each_property.bind(self).call(flags.to_int, start, recurse) { |prop| y << prop } }
      end
    end
    alias :properties :each_property

    wx_each_property_attribute = instance_method :each_property_attribute
    define_method :each_property_attribute do |id|
      if block_given?
        wx_each_property_attribute.bind(self).call(id)
      else
        ::Enumerator.new { |y| wx_each_property_attribute.bind(self).call(id) { |variant| y << variant } }
      end
    end
    alias :property_attributes :each_property_attribute

  end

end
