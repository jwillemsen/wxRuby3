#--------------------------------------------------------------------
# @file    sash_layout_event.rb
# @author  Martin Corino
#
# @brief   wxRuby3 wxWidgets interface director
#
# @copyright Copyright (c) M.J.N. Corino, The Netherlands
#--------------------------------------------------------------------

require_relative './event'

module WXRuby3

  class Director

    class SashLayoutEvent < Event

      def setup
        super
        spec.do_not_generate(:variables, :enums, :defines, :functions)
      end
    end # class SashLayoutEvent

  end # class Director

end # module WXRuby3