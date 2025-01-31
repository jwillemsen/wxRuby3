require 'test/unit'
require 'wx'

class AppReturnsFalseFromInit < Wx::App
    attr_reader :did_call_on_init, :the_app_name
    
    def on_init
        @did_call_on_init = true
        @the_app_name = self.get_app_name
        return false
    end
    
end

class TestApp < Test::Unit::TestCase
  def test_return_false_from_init
    o = AppReturnsFalseFromInit.new
    o.run
    assert(o.did_call_on_init, "didn't call on_init?")
    assert_equal("wxruby", o.the_app_name)
  end
  
end

if $0 == __FILE__
  require 'test/unit/ui/console/testrunner'
  Test::Unit::UI::Console::TestRunner.run(TestApp)
end
