# Wx::GRID sub package loader for wxRuby3
# Copyright (c) M.J.N. Corino, The Netherlands


require 'wx/core'

require 'wxruby_grid'

require_relative './grid/require'

::Wx.include(WxRubyStyleAccessors)

::Wx.include(::Wx::GRID) if defined?(::WX_GLOBAL_CONSTANTS) && ::WX_GLOBAL_CONSTANTS
::Wx::GRID.include((defined?(::WX_GLOBAL_CONSTANTS) && ::WX_GLOBAL_CONSTANTS) ? WxGlobalConstants : WxEnumConstants)
