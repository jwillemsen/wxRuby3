#--------------------------------------------------------------------
# @file    doc.rb
# @author  Martin Corino
#
# @brief   wxRuby3 wxWidgets interface generation templates
#
# @copyright Copyright (c) M.J.N. Corino, The Netherlands
#--------------------------------------------------------------------

require_relative './base'

module WXRuby3

  class DocGenerator < Generator

    class << self

      private

      def get_constants_db
        script = <<~__SCRIPT
          require 'json'
          require 'wx'
          def handle_module(mod, table)
            mod.constants.each do |c|
              a_const = mod.const_get(c)
              if a_const.class == ::Module || a_const.class == ::Class  # Enum or Package submodule or Class
                handle_module(mod.const_get(c), table[c.to_s] = {}) 
              elsif !(::Hash === a_const || ::Array === a_const) 
                table[c.to_s] = { type: a_const.class.name.split('::').last, value: a_const } unless c == :THE_APP
              end
            end
          end
          Wx::App.run do 
            table = { 'Wx' => {}}
            handle_module(Wx, table['Wx'])
            STDOUT.puts JSON.dump(table)
          end
        __SCRIPT
        STDERR.puts "* executing constants collection script:\n#{script}" if Rake.application.options.trace
        begin
          tmpfile = Tempfile.new('script')
          ftmp_name = tmpfile.path.dup
          tmpfile << script
          tmpfile.close(false)
          result = if Rake.application.options.trace
                     Config.instance.run(ftmp_name, capture: :out)
                   else
                     Config.instance.run(ftmp_name, capture: :no_err)
                   end
          STDERR.puts "* got constants collection output:\n#{result}" if Rake.application.options.trace
          db = JSON.load(result)
          File.open('constants.json', "w") { |f| f << JSON.pretty_generate(db) } if Rake.application.options.trace
          return db
        ensure
          File.unlink(ftmp_name)
        end
      end

      def get_constants_xref_db(const_tbl = nil, mods = [])
        xref_tbl = {}
        (const_tbl || constants_db).each_pair do |constnm, constspec|
          unless constspec.has_key?('type')
            xref_tbl[constnm] = { 'mod' => mods.join('::'), 'table' => constspec }
            xref_tbl.merge!(get_constants_xref_db(constspec, mods + [constnm]))
          else
            xref_tbl[constnm] = constspec.merge({'mod' => mods.join('::') })
          end
        end
        xref_tbl
      end

      public

      def xml_doc_to_rb(xml)
        # transform all <itemizedlist>
        doc.gsub!(/\<itemizedlist>(.*)(\<\/itemizedlist>){1,1}/) do |s|
          STDERR.puts s
          STDERR.puts list = $1.dup
          list.gsub(/\<listitem>(.*)(\<\/listitem>){,1}/) { |s1| p s1; '- '+$1 }
        end

        # remove all left-over xml tags
        doc.gsub!(/<[^>]+>/, '')
        doc
      end

      def constants_db
        @constants_db ||= get_constants_db
      end

      def constants_xref_db
        @constants_xref_db ||= get_constants_xref_db
      end

    end

    class XMLTransformer

      include Util::StringUtil

      private

      def event_list(f = true)
        @event_list = !!f
      end

      def event_list?
        !!@event_list
      end

      def no_ref(&block)
        @no_ref = true
        begin
          return block.call
        ensure
          @no_ref = false
        end
      end

      def no_ref?
        !!@no_ref
      end

      def text_to_doc(node)
        text = node.text
        unless no_ref?
          # autocreate references for any ids explicitly declared such
          text.gsub!(/\W?(wx\w+(::\w+)?(\(.*\))?)/) do |s|
            if $1 == 'wxWidgets'
              s
            else
              if s==$1
                _ident_str_to_doc($1)
              else
                "#{s[0]}#{_ident_str_to_doc($1)}"
              end
            end
          end
        end
        if event_list?
          case text
          when /Event macros for events emitted by this class:/
            'Event handler methods for events emitted by this class:'
          when /Event macros:/
            'Event handler methods:'
          when /(EVT_[_A-Z]+)\((.*,)\s+\w+\):(.*)/
            "#{$1.downcase}(#{$2} meth = nil, &block):#{$3}"
          else
            text
          end
        else
          text
        end
      end

      def bold_to_doc(node)
        "<b>#{node_to_doc(node)}</b>"
      end

      def sp_to_doc(node)
        " #{node_to_doc(node)}"
      end

      def nonbreakablespace_to_doc(node)
        sp_to_doc(node)
      end

      def linebreak_to_doc(node)
        "#{node_to_doc(node)}\n"
      end

      def programlisting_to_doc(node)
        no_ref do
          "\n\n  #{node_to_doc(node).split("\n").join("\n  ")}\n"
        end
      end

      def simplesect_to_doc(node)
        case node['kind']
        when 'since' # get rid of 'Since' notes
          ''
        when 'see'
          "<b>See also:</b>\n#{node_to_doc(node)}"
        else
          node_to_doc(node)
        end
      end

      def _arglist_to_doc(args)
        args.split(',').collect do |a|
          a = a.gsub(/const\s+/, '')
          a.tr!('*&[]', '')
          a.split(' ').last
        end.join(',')
      end

      def _ident_str_to_doc(s, ref_scope = nil)
        nmlist = s.split('::')
        nm_str = nmlist.shift.to_s
        constnm = rb_wx_name(nm_str)
        if nmlist.empty?
          if /(\w+)\s*\(([^\)]*)\)/ =~ nm_str
            fn = $1
            args = _arglist_to_doc($2)
            mtdsig = "#{rb_method_name(fn)}(#{args})"
            if ref_scope
              constnm = rb_wx_name(ref_scope)
              if DocGenerator.constants_xref_db.has_key?(constnm)
                "{#{DocGenerator.constants_xref_db[constnm]['mod']}#{constnm}\##{mtdsig}}"
              else
                "{Wx::#{constnm}\##{mtdsig}}"
              end
            else
              "{#{mtdsig}}"
            end
          else
            if DocGenerator.constants_xref_db.has_key?(constnm)
              "{#{DocGenerator.constants_xref_db[constnm]['mod']}::#{constnm}}"
            elsif nm_str.start_with?('wx')
              "{Wx::#{constnm}}"
            else
              mtdnm = rb_method_name(nm_str)
              if ref_scope
                constnm = rb_wx_name(ref_scope)
                if DocGenerator.constants_xref_db.has_key?(constnm)
                  "{#{DocGenerator.constants_xref_db[constnm]['mod']}::#{constnm}\##{mtdnm}}"
                else
                  "{Wx::#{constnm}\##{mtdnm}}"
                end
              else
                "{#{mtdnm}}"
              end
            end
          end
        else
          mtd = nmlist.shift.to_s
          args =  nil
          if /(\w+)\s*\(([^\)]*)\)/ =~ mtd
            mtd = $1
            args = _arglist_to_doc($2)
          end
          if DocGenerator.constants_xref_db.has_key?(constnm)
            constnm = "#{DocGenerator.constants_xref_db[constnm]['mod']}::#{constnm}"
          elsif nm_str.start_with?('wx')
            constnm = "Wx::#{constnm}"
          end
          if nm_str == mtd # ctor?
            "{#{constnm}\#initialize(#{args})}"
          else
            "{#{constnm}\##{rb_method_name(mtd)}#{args}}"
          end
        end
      end

      # transform all cross references
      def ref_to_doc(node)
        if no_ref?
          node.text
        else
          ref_id = Extractor.crossref_table[node['refid']] || {}
          _ident_str_to_doc(node.text, ref_id[:scope])
        end
      end

      # transform all titles
      def title_to_doc(node)
        "== #{node.text}\n"
      end

      def heading_to_doc(node)
        lvl = 1+(node['level'] || '1').to_i
        txt = node_to_doc(node)
        event_list(/Events emitted by this class|Events using this class/i =~ txt)
        "#{'=' * lvl} #{txt}"
      end

      # transform all itemizedlist
      def itemizedlist_to_doc(node)
        node_to_doc(node)
      end

      # transform all listitem
      def listitem_to_doc(node)
        itm_text = node_to_doc(node)
        # fix possible unwanted leading spaces resulting in verbatim blocks
        itm_text = itm_text.split("\n").collect {|s|s.lstrip}.join("\n") if itm_text.index("\n")
        "- #{itm_text}"
      end

      def node_to_doc(xmlnode)
        xmlnode.children.inject('') do |docstr, node|
          docstr << self.__send__("#{node.name}_to_doc", node)
        end
      end

      def para_to_doc(node)
        para = node_to_doc(node)
        # loose specific notes paragraphs
        case para
        when /\A\s*wxPerl Note:/,   # wxPerl note
          /\A\s*Library:/        # Library note
          ''
        else
          if event_list?
            case para
            when /The following event handler macros redirect.*(\{.*})/
              event_ref = $1
              "The following event-handler methods redirect the events to member method or handler blocks for #{event_ref} events."
            when /Event handler methods for events emitted by this class:/
              event_list(false) # event emitter block ended
              para
            else
              para
            end
          else
            para
          end
        end
      end

      def method_missing(mtd, *args, &block)
        if /\A\w+_to_doc\Z/ =~ mtd.to_s && args.size==1
          node_to_doc(*args)
        else
          super
        end
      end

      public

      def initialize(genspec)
        @genspec = genspec
      end

      def to_doc(xmlnode_or_set)
        return '' unless xmlnode_or_set
        doc = if Nokogiri::XML::NodeSet === xmlnode_or_set
                xmlnode_or_set.inject('') { |s, n| s << node_to_doc(n) }
              else
                node_to_doc(xmlnode_or_set)
              end
        event_list(false)
        doc.lstrip!
        # reduce triple(or more) newlines to max 2
        doc.gsub!(/\n\n\n+/, "\n\n")
        doc
      end

    end

    def run(genspec)
      @xml_trans = DocGenerator::XMLTransformer.new(genspec)
      Stream.transaction do
        fdoc = CodeStream.new(File.join(genspec.package.ruby_doc_path, underscore(genspec.name)+'.rb'))
        fdoc << <<~__HEREDOC
          # ----------------------------------------------------------------------------
          # This file is automatically generated by the WXRuby3 documentation 
          # generator. Do not alter this file.
          # ----------------------------------------------------------------------------
        __HEREDOC
        # at least 2 newlines to make Yard skip/forget the header comment
        fdoc.puts
        fdoc.puts
        fdoc.puts "module #{genspec.package.fullname}"
        fdoc.puts
        fdoc.indent do
          gen_constants_doc(fdoc, genspec)
          gen_class_doc(fdoc, genspec) unless genspec.no_gen?(:classes)
        end
        fdoc.puts
        fdoc.puts 'end'
      end
    end

    def gen_constant_value(val)
      if ::String === val && /\A#<(.*)>\Z/ =~ val
        valstr = $1
        if /\Awx/ =~ valstr
          valstr.sub(/\Awx/, '')
        else
          'nil'
        end
      else
        val.inspect
      end
    end

    def gen_constant_doc(fdoc, name, spec, doc)
      fdoc.doc.puts doc
      fdoc.puts "#{name} = #{gen_constant_value(spec['value'])}"
      fdoc.puts
    end

    def gen_enum_doc(fdoc, enumname, enumdef, enum_table)
      fdoc.doc.puts @xml_trans.to_doc(enumdef.brief_doc)
      fdoc.doc.puts
      fdoc.doc.puts @xml_trans.to_doc(enumdef.detailed_doc) if enumdef.detailed_doc
      fdoc.puts "module #{enumname}"
      fdoc.puts
      fdoc.indent do
        enumdef.items.each do |e|
          const_name = rb_wx_name(e.name)
          if enum_table.has_key?(const_name)
            gen_constant_doc(fdoc, const_name, enum_table[const_name], @xml_trans.to_doc(e.brief_doc))
          end
        end
      end
      fdoc.puts "end # #{enumname}"
      fdoc.puts
    end

    def gen_constants_doc(fdoc, genspec)
      const_table = DocGenerator.constants_db
      xref_table = DocGenerator.constants_xref_db
      genspec.def_items.select {|itm| !itm.docs_ignored }.each do |item|
        case item
        when Extractor::GlobalVarDef
          unless genspec.no_gen?(:variables)
            const_name = underscore!(rb_wx_name(item.name)).upcase
            if xref_table.has_key?(const_name)
              gen_constant_doc(fdoc, const_name, xref_table[const_name], @xml_trans.to_doc(item.brief_doc))
            end
          end
        when Extractor::EnumDef
          unless genspec.no_gen?(:enums)
            enum_name = rb_wx_name(item.name)
            if xref_table.has_key?(enum_name)
              gen_enum_doc(fdoc, enum_name, item, xref_table[enum_name]['table'] || {})
            end
          end
        when Extractor::DefineDef
          unless genspec.no_gen?(:defines)
            if !item.is_macro? && item.value && !item.value.empty?
              const_name = underscore!(rb_wx_name(item.name)).upcase
              if xref_table.has_key?(const_name)
                gen_constant_doc(fdoc, const_name, xref_table[const_name], @xml_trans.to_doc(item.brief_doc))
              end
            end
          end
        end
      end
    end

    def gen_class_doc(fdoc, genspec)
      genspec.def_items.select {|itm| !itm.docs_ignored && Extractor::ClassDef === itm && !genspec.is_folded_base?(itm.name) }.each do |item|
        if !item.is_template? || genspec.template_as_class?(item.name)
          clsnm = rb_wx_name(item.name)
          basecls = genspec.base_class(item)
          fdoc.doc.puts(@xml_trans.to_doc(item.brief_doc))
          fdoc.doc.puts
          fdoc.doc.puts(@xml_trans.to_doc(item.detailed_doc))
          fdoc.puts "class #{clsnm} < #{basecls ? basecls.sub(/\Awx/, '') : '::Object'}"
          fdoc.puts
          fdoc.indent do
            item.rb_doc(fdoc, @xml_trans)
          end
          fdoc.puts "end # #{clsnm}"
          fdoc.puts
        end
      end
    end

  end

end
