#--------------------------------------------------------------------
# @file    defs.rb
# @author  Martin Corino
#
# @brief   wxRuby3 wxWidgets interface director
#
# @copyright Copyright (c) M.J.N. Corino, The Netherlands
#--------------------------------------------------------------------

module WXRuby3

  class Director

    class Defs < Director

      def initialize
        super
      end

      def setup(spec)
        spec.ignore %w{
          wxINT8_MIN
          wxINT8_MAX
          wxUINT8_MAX
          wxINT16_MIN
          wxINT16_MAX
          wxUINT16_MAX
          wxINT32_MIN
          wxINT32_MAX
          wxUINT32_MAX
          wxINT64_MIN
          wxINT64_MAX
          wxUINT64_MAX
        }
        super
      end

      def generator
        WXRuby3::DefsGenerator.new
      end
    end # class Constants

  end # class Director

end # module WXRuby3
