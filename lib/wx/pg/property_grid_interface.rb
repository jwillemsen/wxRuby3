
module Wx::PG

  module PropertyGridInterface

    wx_each_property = instance_method :each_property
    define_method :each_property do |flags = Wx::PG::PG_ITERATE_DEFAULT, start = nil, reverse: false, &block|
      if block
        wx_each_property.bind(self).call(flags.to_int, start, reverse, &block)
      else
        ::Enumerator.new { |y| wx_each_property.bind(self).call(flags.to_int, start, reverse) { |prop| y << prop } }
      end
    end
    alias :properties :each_property

    def reverse_each_property(flags = Wx::PG::PG_ITERATE_DEFAULT, start = nil, &block)
      each_property(flags, start, reverse: true, &block)
    end
    alias :properties_reversed :reverse_each_property

    wx_each_property_attribute = instance_method :each_property_attribute
    define_method :each_property_attribute do |id, &block|
      if block
        wx_each_property_attribute.bind(self).call(id, &block)
      else
        ::Enumerator.new { |y| wx_each_property_attribute.bind(self).call(id) { |variant| y << variant } }
      end
    end
    alias :property_attributes :each_property_attribute

  end

end
