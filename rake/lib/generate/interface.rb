###
# wxRuby3 SWIG interface definition Generator class
# Copyright (c) M.J.N. Corino, The Netherlands
###

require 'monitor'

require_relative './base'
require_relative './analyzer'

module WXRuby3

  class InterfaceGenerator < Generator

    def initialize(dir)
      super
      # select all typemaps that have an ignored (director)out map
      @typemaps_with_ignored_out = type_maps.select { |tm| tm.has_ignored_out? }
    end

    def gen_swig_header(fout)
      fout << <<~__HEREDOC
        /**
         * This file is automatically generated by the WXRuby3 interface generator.
         * Do not alter this file.
         */

        %include "../common.i"

        %module(directors="1") #{module_name}
        __HEREDOC
    end

    def gen_swig_gc_types(fout)
      def_items.each do |item|
        if Extractor::ClassDef === item
          unless is_folded_base?(item.name)
            fout.puts "#{gc_type(item)}(#{class_name(item)});"
          end
          item.innerclasses.each do |inner|
            fout.puts "#{gc_type(inner)}(#{class_name(inner)});"
          end
        end
      end
    end

    def gen_swig_begin_code(fout)
      unless disowns.empty?
        fout.puts
        disowns.each do |dis|
          if ::Hash === dis
            decl, flag = dis.first
            fout.puts "%apply SWIGTYPE *#{flag ? 'DISOWN' : ''} { #{decl} };"
          else
            fout.puts "%apply SWIGTYPE *DISOWN { #{dis} };"
          end
        end
      end
      unless new_objects.empty?
        fout.puts
        new_objects.each do |decl|
          fout.puts "%newobject { #{decl} };"
        end
      end
      unless includes.empty? && header_code.empty?
        fout.puts
        fout.puts "%header %{"
        includes.each do |inc|
          fout.puts "#include \"#{inc}\"" unless inc.index('wx.h')
        end
        unless header_code.empty?
          fout.puts
          fout.puts header_code
        end
        fout.puts "%}"
      end
      if begin_code && !begin_code.empty?
        fout.puts
        fout.puts "%begin %{"
        fout.puts begin_code
        fout.puts "%}"
      end
    end

    def gen_swig_runtime_code(fout)
      if disabled_proxies
        def_classes.each do |cls|
          if !cls.ignored && !cls.is_template?
            unless is_folded_base?(cls.name)
              fout.puts "%feature(\"nodirector\") #{class_name(cls)};"
            end
          end
        end
      else
        def_classes.each do |cls|
          unless cls.ignored || cls.is_template? || has_virtuals?(cls) || forced_proxy?(cls.name)
            fout.puts "%feature(\"nodirector\") #{class_name(cls)};"
          end
        end
      end
      unless no_proxies.empty?
        fout.puts
        no_proxies.each do |name|
          fout.puts "%feature(\"nodirector\") #{name};"
        end
      end
      unless renames.empty?
        fout.puts
        renames.each_pair do |to, from|
          from.each { |org| fout.puts "%rename(#{to}) #{org};" }
        end
      end
      fout.puts
      fout.puts "%runtime %{"
      if runtime_code && !runtime_code.empty?
        fout.puts runtime_code
      end
      fout.puts "extern VALUE #{package.module_variable}; // The global package module"
      fout.puts 'WXRUBY_EXPORT VALUE wxRuby_Core(); // returns the core package module'
      fout.puts "%}"
    end

    def gen_swig_code(fout)
      fout.puts
      fout.puts type_maps.to_swig
      if swig_code && !swig_code.empty?
        fout.puts
        fout.puts swig_code
      end
    end

    def gen_swig_wrapper_code(fout)
      if wrapper_code && !wrapper_code.empty?
        fout.puts
        fout.puts "%wrapper %{"
        fout.puts wrapper_code
        fout.puts "%}"
      end
    end

    def gen_swig_init_code(fout)
      if init_code && !init_code.empty?
        fout.puts
        fout.puts "%init %{"
        fout.puts init_code
        fout.puts "%}"
      end
    end
    
    def gen_swig_extensions(fout)
      def_items.each do |item|
        if Extractor::ClassDef === item && !item.ignored && !is_folded_base?(item.name)
          extension = extend_code(class_name(item.name))
          unless extension.empty?
            fout.puts "\n%extend #{class_name(item.name)} {"
            fout.puts extension
            fout.puts '};'
          end
        end
      end
    end

    def gen_swig_interface_code(fout)
      unless swig_imports[:prepend].empty?
        fout.puts
        swig_imports[:prepend].each do |inc|
          fout .puts %Q{%import "#{inc}"}
        end
      end

      def_items.each do |item|
        if Extractor::ClassDef === item && !item.ignored && !is_folded_base?(item.name)
          fout.puts
          base_list(item).reverse.each do |base|
            unless def_item(base)
              import_fnm = File.join(WXRuby3::Config.instance.interface_dir, "#{base}.h")
              fout.puts %Q{%import "#{import_fnm}"} unless swig_imports.include?(import_fnm)
            end
          end
        end
      end

      unless swig_imports[:append].empty?
        fout.puts
        swig_imports[:append].each do |inc|
          fout .puts %Q{%import "#{inc}"}
        end
      end

      unless swig_includes.empty?
        fout.puts
        swig_includes.each do |inc|
          fout.puts %Q{%include "#{inc}"}
        end
      end

      fout.puts
      fout.puts interface_code
    end

    def gen_swig_interface_file
      gen_swig_interface_specs(CodeStream.new(interface_file))
    end

    def gen_interface_classes(fout)
      def_items.each do |item|
        if Extractor::ClassDef === item && !item.ignored && (!item.is_template? || template_as_class?(item.name))
          unless is_folded_base?(item.name)
            gen_interface_class(fout, item)
          end
        end
      end
    end

    def gen_interface_class(fout, classdef)
      requires_purevirtual = has_proxy?(classdef)

      intf_class_name = if (classdef.is_template? && template_as_class?(classdef.name))
                          template_class_name(classdef.name)
                        else
                          classdef.name
                        end

      fout.puts ''
      basecls = base_class(classdef)
      if basecls
        fout.puts "class #{basecls};"
        fout.puts ''
      end
      is_struct = classdef.kind == 'struct'
      fout.puts "#{classdef.kind} #{class_name(classdef)}#{basecls ? ' : public '+basecls : ''}"
      fout.puts '{'

      unless is_struct
        fout.puts 'public:'
      end
      if (abstract_class = is_abstract?(classdef))
        fout.puts "  virtual ~#{class_name(classdef)}() =0;"
      end

      InterfaceAnalyzer.class_interface_members_public(intf_class_name).each do |member|
        gen_interface_class_member(fout, intf_class_name, classdef, member, requires_purevirtual)
      end

      need_protected = classdef.regards_protected_members? ||
        !interface_extensions(classdef, 'protected').empty? ||
        folded_bases(classdef.name).any? { |base| def_item(base).regards_protected_members? }
      unless is_struct || !need_protected
        fout.puts
        fout.puts ' protected:'

        InterfaceAnalyzer.class_interface_members_protected(intf_class_name).each do |member|
          gen_interface_class_member(fout, intf_class_name, classdef, member, requires_purevirtual)
        end
      end

      fout.puts '};'
    end

    def gen_interface_class_member(fout, class_name, classdef, member, requires_purevirtual)
      case member
      when Extractor::ClassDef
        fout.indent { gen_inner_class(fout, member) }
      when Extractor::MethodDef
        if member.is_ctor
          gen_only_for(fout, member) do
            fout.puts "  #{class_name(classdef)}#{member.args_string};"
          end
        elsif member.is_dtor
          unless is_abstract?(classdef)
            dtor_sig = "~#{class_name(classdef)}()"
            fout.puts "  #{member.is_virtual ? 'virtual ' : ''}#{dtor_sig};"
          end
        elsif !InterfaceAnalyzer.class_interface_method_ignored?(class_name, member)
          gen_interface_class_method(fout, member, requires_purevirtual)
        end
      when Extractor::EnumDef
        gen_interface_enum(fout, member, classdef)
      when Extractor::MemberVarDef
        gen_only_for(fout, member) do
          fout.puts "  // from #{member.definition}"
          fout.puts "  #{member.is_static ? 'static ' : ''}#{member.type} #{member.name};"
        end
      when ::String
        fout.indent do
          fout.puts '// custom wxRuby extension'
          fout.puts "#{member};"
        end
      end
    end

    def gen_inner_class(fout, classdef)
      fout.puts ''
      basecls = base_class(classdef)
      if basecls
        fout.puts "class #{basecls};"
        fout.puts ''
      end
      is_struct = classdef.kind == 'struct'
      fout.puts "#{classdef.kind} #{classdef.name}#{basecls ? ' : public '+basecls : ''}"
      fout.puts '{'

      unless is_struct
        fout.puts 'public:'
      end

      classdef.items.each do |member|
        case member
        when Extractor::MethodDef
          if member.is_ctor
            if member.protection == 'public'
              if !member.ignored && !member.deprecated
                gen_only_for(fout, member) do
                  fout.puts "  #{classdef.name}#{member.args_string};"
                end
              end
              member.overloads.each do |ovl|
                if ovl.protection == 'public' && !ovl.ignored && !ovl.deprecated
                  gen_only_for(fout, ovl) do
                    fout.puts "  #{classdef.name}#{ovl.args_string};"
                  end
                end
              end
            end
          elsif member.is_dtor
            if member.protection == 'public' && !member.ignored
              ctor_sig = "~#{classdef.name}()"
              fout.puts "  #{member.is_virtual ? 'virtual ' : ''}#{ctor_sig};"
            end
          elsif member.protection == 'public'
            gen_interface_class_method(fout, member) if !member.ignored && !member.deprecated && !member.is_template?
            member.overloads.each do |ovl|
              if ovl.protection == 'public' && !ovl.ignored && !ovl.deprecated && !ovl.is_template?
                gen_interface_class_method(fout, member)
              end
            end
          end
        when Extractor::EnumDef
          if member.protection == 'public' && !member.ignored && !member.deprecated && member.items.any? {|e| !e.ignored }
            gen_interface_enum(fout, member, classdef)
          end
        when Extractor::MemberVarDef
          if member.protection == 'public' && !member.ignored && !member.deprecated
            gen_only_for(fout, member) do
              fout.puts "  // from #{member.definition}"
              fout.puts "  #{member.is_static ? 'static ' : ''}#{member.type} #{member.name};"
            end
          end
        end
      end

      fout.puts '};'
    end

    def gen_interface_class_method(fout, methoddef, requires_purevirtual=false)
      mtd_type = methoddef.type
      # check if this method matches a type map with ignored out defs
      if type_map = @typemaps_with_ignored_out.detect { |tm| tm.matches?(methoddef) }
        mtd_type = Typemap.rb_void_type(mtd_type) if type_map.ignored.include?(mtd_type)
      end
      # generate method declaration
      gen_only_for(fout, methoddef) do
        fout.puts "  // from #{methoddef.definition}"
        mdecl = methoddef.is_static ? 'static ' : ''
        mdecl << 'virtual ' if methoddef.is_virtual
        purespec = (requires_purevirtual && methoddef.is_pure_virtual) ? ' =0' : ''
        fout.puts "  #{mdecl}#{mtd_type} #{methoddef.name}#{methoddef.args_string}#{purespec};"
      end
    end

    def gen_interface_enum(fout, member, classdef)
      gen_only_for(fout, member) do
        fout.puts "  // from #{classdef.name}::#{member.name}"
        fout.puts "  enum #{member.is_anonymous ? '' : member.name} {"
        enum_size = member.items.size
        member.items.each_with_index do |e, i|
          gen_only_for(fout, e) do
            fout.puts "    #{e.name}#{(i+1)<enum_size ? ',' : ''}"
          end
        end
        fout.puts "  };"
      end
    end

    def gen_typedefs(fout)
      typedefs = def_items.select {|item| Extractor::TypedefDef === item && !item.ignored }
      typedefs.each do |item|
        fout.puts
        gen_only_for(fout, item) do
          fout.puts "#{item.definition};"
        end
      end
      fout.puts '' unless typedefs.empty?
    end

    def gen_variables(fout)
      vars = def_items.select {|item| Extractor::GlobalVarDef === item && !item.ignored }
      vars.each do |item|
        fout.puts
        gen_only_for(fout, item) do
          wx_pfx = item.name.start_with?('wx') ? 'wx' : ''
          const_name = underscore!(rb_wx_name(item.name))
          const_type = item.type
          const_type << '*' if const_type.index('char') && item.args_string == '[]'
          fout.puts "%constant #{const_type} #{wx_pfx}#{const_name.upcase} = #{item.name.rstrip};"
        end
      end
      fout.puts '' unless vars.empty?
    end

    def gen_enums(fout)
      def_items.each do |item|
        if Extractor::EnumDef === item && !item.ignored && !item.items.all? {|e| e.ignored }
          fout.puts
          fout.puts "// from enum #{item.is_anonymous ? '' : item.name}"
          fout.puts "enum #{item.name};" unless item.is_anonymous
          item.items.each do |e|
            unless e.ignored
              gen_only_for(fout, e) do
                fout.puts "%constant int #{e.name} = #{e.name};"
              end
            end
          end
        end
      end
    end

    def init_rb_ext_file
      frbext = CodeStream.new(interface_ext_file)
      frbext  << <<~__HEREDOC
        # ----------------------------------------------------------------------------
        # This file is automatically generated by the WXRuby3 code 
        # generator. Do not alter this file.
        # ----------------------------------------------------------------------------

        __HEREDOC
      package.all_modules.each do |mod|
        frbext.puts "module #{mod}"
      end
      frbext.puts
      frbext
    end

    def gen_defines(fout)
      frbext = nil
      defines = def_items.select {|item|
        Extractor::DefineDef === item && !item.ignored && !item.is_macro? && item.value && !item.value.empty?
      }
      defines.each do |item|
        gen_only_for(fout, item) do
          if item.value =~ /\A\d/
            fout.puts
            fout.puts "#define #{item.name} #{item.value}"
          elsif item.value.start_with?('"')
            fout.puts
            fout.puts "%constant char*  #{item.name} = #{item.value};"
          elsif item.value =~ /wxString\((".*")\)/
            fout.puts
            fout.puts "%constant char*  #{item.name} = #{$1};"
          elsif item.value =~ /wx(Size|Point)(\(.*\))/
            frbext = init_rb_ext_file unless frbext
            frbext.indent { frbext.puts "#{rb_wx_name(item.name)} = Wx::#{$1}.new#{$2}" }
            frbext.puts
          elsif item.value =~ /wx(Colour|Font)(\(.*\))/
            frbext = init_rb_ext_file unless frbext
            frbext.indent do
              frbext.puts "Wx.add_delayed_constant(self, :#{rb_wx_name(item.name)}) { Wx::#{$1}.new#{$2} }"
            end
            frbext.puts
          elsif item.value =~ /wxSystemSettings::(\w+)\((.*)\)/
            frbext = init_rb_ext_file unless frbext
            args = $2.split(',').collect {|a| rb_constant_value(a) }.join(', ')
            frbext.indent do
              frbext.puts "Wx.add_delayed_constant(self, :#{rb_wx_name(item.name)}) { Wx::SystemSettings.#{rb_method_name($1)}(#{args}) }"
            end
            frbext.puts
          else
            fout.puts
            fout.puts "%constant int  #{item.name} = #{item.value};"
          end
        end
      end
      if frbext
        package.all_modules.each { |mod| frbext.puts 'end' }
      end
      fout.puts '' unless defines.empty?
    end

    def gen_functions(fout)
      functions = def_items.select {|item| Extractor::FunctionDef === item && !item.is_template? }
      functions.each do |item|
        active_overloads = item.all.select { |ovl| !ovl.ignored && !ovl.deprecated }
        active_overloads.each do |ovl|
          fout.puts
          fn_type = ovl.type
          # check if this method matches a type map with ignored out defs
          if type_map = @typemaps_with_ignored_out.detect { |tm| tm.matches?(ovl) }
            fn_type = Typemap.rb_void_type(fn_type) if type_map.ignored.include?(fn_type)
          end
          gen_only_for(fout, ovl) do
            fout.puts "#{fn_type} #{ovl.name}#{ovl.args_string};"
          end
        end
      end
      fout.puts '' unless functions.empty?
    end

    def gen_only_for(fout, item, &block)
      if item.only_for
        if ::Array === item.only_for
          fout.puts "#if #{item.only_for.collect { |s| "defined(#{s})" }.join(' || ')}"
        else
          fout.puts "#ifdef #{item.only_for}"
        end
      end
      block.call
      fout.puts "#endif" if item.only_for
    end

    def gen_swig_interface_specs(fout)
      gen_swig_header(fout)

      gen_swig_gc_types(fout)

      gen_swig_begin_code(fout)

      gen_swig_runtime_code(fout)

      gen_swig_code(fout)

      gen_swig_init_code(fout)
      
      gen_swig_extensions(fout)

      gen_swig_interface_code(fout)

      gen_swig_wrapper_code(fout)
    end

    def gen_interface_include
      gen_interface_include_code(
        CodeStream.new(interface_include_file))
    end

    def gen_interface_include_header(fout)
      fout << <<~HEREDOC
        /**
         * This file is automatically generated by the WXRuby3 interface generator.
         * Do not alter this file.
         */
                 
        #ifndef __#{module_name.upcase}_H_INCLUDED__
        #define __#{module_name.upcase}_H_INCLUDED__
      HEREDOC
      unless warn_filters.empty?
        fout.puts
        warn_filters.each_pair do |warn, decls|
          decls.each { |decl| fout.puts "%warnfilter(#{warn}) #{decl};" }
        end
      end
    end

    def gen_interface_include_footer(fout)
      fout << "\n#endif /* __#{module_name.upcase}_H_INCLUDED__ */"
    end

    def gen_interface_include_code(fout)
      gen_interface_include_header(fout)

      gen_typedefs(fout) unless no_gen?(:typedefs)

      gen_interface_classes(fout) unless no_gen?(:classes)

      gen_variables(fout) unless no_gen?(:variables)

      gen_enums(fout) unless no_gen?(:enums)

      gen_defines(fout) unless no_gen?(:defines)

      gen_functions(fout) unless no_gen?(:functions)

      gen_interface_include_footer(fout)
    end

    def run
      STDERR.puts "* generating #{interface_file}" if Director.verbose?

      # run an analysis comparing inherited generated methods with this class's own generated methods
      InterfaceAnalyzer.check_interface_methods(@director)

      Stream.transaction do
        gen_interface_include if has_interface_include?

        # make sure to keep this last for the parallel builds synchronize on the *.i files
        gen_swig_interface_file
      end
    end

  end # class ClassGenerator

end # module WXRuby3
