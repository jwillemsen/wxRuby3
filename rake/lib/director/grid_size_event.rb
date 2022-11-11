#--------------------------------------------------------------------
# @file    grid_size_event.rb
# @author  Martin Corino
#
# @brief   wxRuby3 wxWidgets interface director
#
# @copyright Copyright (c) M.J.N. Corino, The Netherlands
#--------------------------------------------------------------------

require_relative './event'

module WXRuby3

  class Director

    class GridSizeEvent < Event

      def setup
        super
        spec.ignore_bases('wxGridSizeEvent' => %w[wxNotifyEvent]) # needed to suppress imports
        spec.swig_import('swig/classes/include/wxObject.h', 'swig/classes/include/wxEvent.h') # provide base definitions
        spec.override_base('wxGridSizeEvent', 'wxNotifyEvent') # re-establish correct base
      end
    end # class GridSizeEvent

  end # class Director

end # module WXRuby3