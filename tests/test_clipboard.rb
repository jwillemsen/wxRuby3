require 'test/unit'
require 'test/unit/ui/console/testrunner'
require 'wx'

class TestTextData < Test::Unit::TestCase
  # Using an in-built class
  def test_text_data
    td = Wx::TextDataObject.new('WXRUBY')
    assert_equal("WXRUBY", td.text)

    Wx::Clipboard.open do | clip |
      assert clip.opened?
      clip.clear
      assert !clip.supported?(Wx::DF_BITMAP)
      clip.place td
      assert clip.supported?(Wx::DF_TEXT)
      assert !clip.supported?(Wx::DF_BITMAP)
    end

    td_2 = Wx::TextDataObject.new
    Wx::Clipboard.open do | clip |
      clip.fetch td_2
    end
    assert_equal("WXRUBY", td_2.text)

    Wx::Clipboard.open do | clip |
      clip.clear
    end

    td_3 = Wx::TextDataObject.new
    Wx::Clipboard.open do | clip |
      clip.fetch td_3
    end
    assert_equal("", td_3.text)
  end
end


class TestBitmapData < Test::Unit::TestCase
  def test_bitmap_data
    # FIXME - this doesn't appear to load correctly on MingW-Ruby 1.9
    bmp = Wx::Bitmap.new('samples/minimal/mondrian.png')
    height = bmp.height
    width  = bmp.width
    assert bmp.ok?, "Bitmap is OK"

    d_obj = Wx::BitmapDataObject.new(bmp)
    d_obj.bitmap = bmp

    assert d_obj.bitmap.ok?, "DataObject's bitmap is OK"
    Wx::Clipboard.open do | clip |
      clip.clear
      clip.place d_obj
      assert clip.supported? Wx::DF_BITMAP
    end

    d_obj_2 = Wx::BitmapDataObject.new
    Wx::Clipboard.open do | clip |
      assert clip.supported? Wx::DF_BITMAP
      clip.fetch d_obj_2
    end

    out_bmp = d_obj_2.bitmap
    assert out_bmp.ok?, "Fetched out bitmap"
    assert_equal height, out_bmp.height
    assert_equal width, out_bmp.width
  end
end

class TestDataObjectComposite < Test::Unit::TestCase
  def test_data_object_composite
    d_obj = Wx::DataObjectComposite.new
    d_txt = Wx::TextDataObject.new
    d_obj.add( d_txt )
    # FIXME - this doesn't appear to load correctly on MingW-Ruby 1.9
    bmp = Wx::Bitmap.new('samples/minimal/mondrian.png')

    d_obj.add( Wx::BitmapDataObject.new )
    assert_equal( 2, d_txt.format_count(0) )
    assert_equal( 3, d_obj.format_count(0) )

    d_bmp = Wx::BitmapDataObject.new(bmp)
    Wx::Clipboard.open do | clip |
      clip.clear
      clip.place d_bmp
    end

    Wx::Clipboard.open do | clip |
      assert !clip.supported?( Wx::DF_TEXT )
      assert clip.supported?( Wx::DF_BITMAP )

      clip.fetch d_obj
    end

    assert_equal d_obj.received_format, Wx::DF_BITMAP
    d_bmp = d_obj.object(Wx::DF_BITMAP)
    bmp_out = d_bmp.bitmap
    assert bmp_out.ok?, "Read out bitmap OK"
    assert_equal bmp.width, bmp_out.width
    assert_equal bmp.height, bmp_out.height

    d_txt = Wx::TextDataObject.new('THE TEXT')
    Wx::Clipboard.open do | clip |
      clip.clear
      clip.place d_txt
    end

    d_obj_2 = Wx::DataObjectComposite.new
    d_txt = Wx::TextDataObject.new
    d_obj_2.add d_txt
    d_obj_2.add Wx::BitmapDataObject.new

    Wx::Clipboard.open do | clip |
      assert clip.supported?( Wx::DF_TEXT )
      assert clip.supported?( Wx::DF_UNICODETEXT )
      assert !clip.supported?( Wx::DF_BITMAP )

      clip.fetch d_obj_2
    end

    assert_equal d_obj_2.received_format, d_txt.preferred_format(Wx::DataObject::Set)
    d_txt = d_obj_2.object(Wx::DF_TEXT)
    assert_equal d_txt.text, 'THE TEXT'
  end
end

class TestDataObject < Test::Unit::TestCase
  MY_CUSTOM_FORMAT = Wx::DataFormat.new('custom.text.format')

  class MyBasicDataObject < Wx::DataObject
    attr_reader :my_data

    def initialize(the_data = '')
      super()
      # store in the preferred format
      @my_data = "<b>#{the_data}</b>"
      @format = MY_CUSTOM_FORMAT
    end

    def get_as_text
      if @my_data.nil? || @my_data.empty? || @format == Wx::DF_TEXT
        @my_data
      else
        @my_data.gsub(/<[^>]+>/, '') # not f(ul|oo)lproof, I know
      end
    end

    def get_formatted
      if @my_data.nil? || @my_data.empty? || @format == MY_CUSTOM_FORMAT
        @my_data
      else
        "<b>#{@my_data}</b>"
      end
    end
    private :get_formatted

    # List all the formats that we support. By default, the first is
    # treated as the 'preferred' format; this can be overridden by
    # providing a get_preferred format.
    def get_all_formats(direction)
      [ MY_CUSTOM_FORMAT, Wx::DF_TEXT  ]
    end

    # Do setting the data
    def set_data(format, the_data)
      case format
      when MY_CUSTOM_FORMAT, Wx::DF_TEXT
        @my_data = the_data
        @format = format
        true
      else
        false
      end
    end

    def get_data_size(format)
      case format
      when Wx::DF_TEXT
        get_as_text.to_s.size
      when MY_CUSTOM_FORMAT
        get_formatted.to_s.size
      else
        0
      end
    end

    # Do getting the data
    def get_data_here(format)
      case format
      when Wx::DF_TEXT
        get_as_text
      when MY_CUSTOM_FORMAT
        get_formatted
      else
        nil
      end
    end
  end

  def test_data_obj
    d_obj = MyBasicDataObject.new('HELLO')
    assert_equal( 2, d_obj.format_count(0) )
    assert_equal('HELLO', d_obj.get_data_here(Wx::DF_TEXT) )
    assert_equal('<b>HELLO</b>', d_obj.get_data_here(MY_CUSTOM_FORMAT) )

    Wx::Clipboard.open do | clip |
      clip.place d_obj
    end
    
    d_obj_2 = MyBasicDataObject.new
    Wx::Clipboard.open do | clip |
      assert clip.supported?( Wx::DF_TEXT )
      assert clip.supported?( MY_CUSTOM_FORMAT )
      clip.fetch d_obj_2
    end
    assert_equal('<b>HELLO</b>', d_obj_2.get_data_here(MY_CUSTOM_FORMAT) )

    # FIXME - the non-preferred data object isn't set
    assert_equal('HELLO', d_obj_2.get_data_here(Wx::DF_TEXT) )
  end
end


# FIXME - test is run twice
Wx::App.run do
  # Must run whilst App is alive
  Test::Unit::UI::Console::TestRunner.run(TestTextData)
  Test::Unit::UI::Console::TestRunner.run(TestBitmapData)
  Test::Unit::UI::Console::TestRunner.run(TestDataObjectComposite)
  Test::Unit::UI::Console::TestRunner.run(TestDataObject)
  false
end