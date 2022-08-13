
$:.insert(0, File.join(File.dirname(__FILE__), 'lib'))
require './lib/wx'

# This is the minimum code to start a WxRuby app - create a Frame, and
# show it.
Wx::App.run do
  frame = Wx::Frame.new(nil, :title => "Minimal wxRuby App")
  frame.background_colour = Wx::BLUE
  icon_file = File.join( File.dirname(__FILE__)+"/../wxruby/art", "wxruby.png")
  frame.icon = Wx::Icon.new(icon_file)
  frame.show
end
