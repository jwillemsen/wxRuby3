#--------------------------------------------------------------------
# @file    variable.rb
# @author  Martin Corino
#
# @brief   wxRuby3 wxWidgets interface extractor
#
# @copyright Copyright (c) M.J.N. Corino, The Netherlands
#--------------------------------------------------------------------

module WXRuby3

  module Extractor

    # Represents a basic variable declaration.
    class VariableDef < BaseDef
      def initialize(element = nil, **kwargs)
        super()
        @type = nil
        @definition = ''
        @args_string = ''
        @rb_int = false
        @no_setter = false
        @value = nil;
        update_attributes(**kwargs)
        extract(element) if element
      end

      attr_accessor :type, :definition, :args_string, :rb_int, :no_setter, :value

      def extract(element)
        super
        @type = BaseDef.flatten_node(element.at_xpath('type'))
        @definition = element.at_xpath('definition').text
        @args_string = element.at_xpath('argsstring').text
        @value = BaseDef.flatten_node(element.at_xpath('initializer'))
      end
    end # class VariableDef

    #---------------------------------------------------------------------------
    # These need the same attributes as VariableDef, but we use separate classes
    # so we can identify what kind of element it came from originally.

    class GlobalVarDef < VariableDef; end

    class TypedefDef < VariableDef
      def initialize(element = nil, **kwargs)
        super()
        @no_type_name = false
        @doc_as_class = false
        @bases = []
        @protection = 'public'
        update_attributes(**kwargs)
        extract(element) if element
      end

      attr_accessor :no_type_name, :doc_as_class, :bases, :protection
    end # class TypedefDef

    #---------------------------------------------------------------------------

    class MemberVarDef < VariableDef
      # Represents a variable declaration in a class.
      def initialize(element = nil, **kwargs)
        super()
        @is_static = false
        @protection = 'public'
        @get_code = ''
        @set_code = ''
        update_attributes(**kwargs)
        extract(element) if element
      end

      attr_accessor :is_static, :protection, :get_code, :set_code

      def extract(element)
        super
        @is_static = (element['static'] == 'yes')
        @protection = element['prot']
        unless %w[public protected].include?(@protection)
          raise ExtractorError.new("Invalid protection [#{@protection}")
        end
        # TODO: Should protected items be ignored by default or should we
        #       leave that up to the tweaker code or the generators?
        ignore if @protection == 'protected'
      end
    end # class MemberVarDef

    #---------------------------------------------------------------------------

    # Represents a #define with a name and a value.
    class DefineDef < BaseDef
      def initialize(element = nil, **kwargs)
        super()
        if element
          @name = element.at_xpath('name').text
          @value = BaseDef.flatten_node(element.at_xpath('initializer'))
          @macro = !element.xpath('param').empty?
        end
        update_attributes(**kwargs)
      end

      attr_reader :value

      def is_macro?
        @macro
      end
    end # class DefineDef

  end # module Extractor

end # module WXRuby3
