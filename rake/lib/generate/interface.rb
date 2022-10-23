#--------------------------------------------------------------------
# @file    standard.rb
# @author  Martin Corino
#
# @brief   wxRuby3 wxWidgets standard interface generator
#
# @copyright Copyright (c) M.J.N. Corino, The Netherlands
#--------------------------------------------------------------------

require_relative './base'

module WXRuby3

  class InterfaceGenerator < Generator

    def gen_swig_header(fout, spec)
      fout << <<~__HEREDOC
        /**
         * This file is automatically generated by the WXRuby3 interface generator.
         * Do not alter this file.
         */

        %include "../common.i"

        %module(directors="1") #{spec.module_name}
        __HEREDOC
    end

    def gen_swig_gc_types(fout, spec)
      spec.def_items.each do |item|
        if Extractor::ClassDef === item
          unless spec.is_folded_base?(item.name)
            fout.puts "#{spec.gc_type(item)}(#{spec.class_name(item)});"
          end
          item.innerclasses.each do |inner|
            fout.puts "#{spec.gc_type(inner)}(#{spec.class_name(inner)});"
          end
        end
      end
    end

    def gen_swig_begin_code(fout, spec)
      unless spec.disowns.empty?
        fout.puts
        spec.disowns.each do |dis|
          fout.puts "%apply SWIGTYPE *DISOWN { #{dis} };"
        end
      end
      unless spec.includes.empty? && spec.header_code.empty?
        fout.puts "%header %{"
        spec.includes.each do |inc|
          fout.puts "#include \"#{inc}\"" unless inc.index('wx.h')
        end
        unless spec.header_code.empty?
          fout.puts
          fout.puts spec.header_code
        end
        fout.puts "%}"
      end
      if spec.begin_code && !spec.begin_code.empty?
        fout.puts
        fout.puts "%begin %{"
        fout.puts "spec.begin_code"
        fout.puts "%}"
      end
    end

    def gen_swig_runtime_code(fout, spec)
      if spec.disabled_proxies
        spec.def_classes.each do |cls|
          if !cls.ignored && !cls.is_template?
            unless spec.is_folded_base?(cls.name)
              fout.puts "%feature(\"nodirector\") #{spec.class_name(cls)};"
            end
          end
        end
      else
        spec.def_classes.each do |cls|
          unless cls.ignored && cls.is_template? || (spec.has_virtuals?(cls) || spec.forced_proxy?(cls.name))
            fout.puts "%feature(\"nodirector\") #{spec.class_name(cls)};"
          end
        end
      end
      unless spec.no_proxies.empty?
        fout.puts
        spec.no_proxies.each do |name|
          fout.puts "%feature(\"nodirector\") #{name};"
        end
      end
      unless spec.renames.empty?
        fout.puts
        spec.renames.each_pair do |to, from|
          from.each { |org| fout.puts "%rename(#{to}) #{org};" }
        end
      end
      fout.puts
      fout.puts "%runtime %{"
      if spec.runtime_code && !spec.runtime_code.empty?
        fout.puts spec.runtime_code
      end
      fout.puts "extern VALUE #{spec.package.module_variable}; // The global package module"
      fout.puts 'WXRUBY_EXPORT VALUE wxRuby_Core(); // returns the core package module'
      fout.puts "%}"
    end

    def gen_swig_code(fout, spec)
      if spec.swig_code && !spec.swig_code.empty?
        fout.puts
        fout.puts spec.swig_code
      end
    end

    def gen_swig_wrapper_code(fout, spec)
      if spec.wrapper_code && !spec.wrapper_code.empty?
        fout.puts
        fout.puts "%wrapper %{"
        fout.puts spec.wrapper_code
        fout.puts "%}"
      end
    end

    def gen_swig_init_code(fout, spec)
      if spec.init_code && !spec.init_code.empty?
        fout.puts
        fout.puts "%init %{"
        fout.puts spec.init_code
        fout.puts "%}"
      end
    end

    def gen_swig_extensions(fout, spec)
      spec.def_items.each do |item|
        if Extractor::ClassDef === item && !item.ignored && !spec.is_folded_base?(item.name)
          extension = spec.extend_code(spec.class_name(item.name))
          unless extension.empty?
            fout.puts "\n%extend #{spec.class_name(item.name)} {"
            fout.puts extension
            fout.puts '};'
          end
        end
      end
    end

    def gen_swig_interface_code(fout, spec)
      spec.def_items.each do |item|
        if Extractor::ClassDef === item && !item.ignored && !spec.is_folded_base?(item.name)
          fout.puts ''
          spec.base_list(item).reverse.each do |base|
            unless spec.def_item(base)
              fout.puts %Q{%import "#{WXRuby3::Config.instance.interface_dir}/#{base}.h"}
            end
          end
        end
      end

      unless spec.swig_imports.empty?
        fout.puts ''
        spec.swig_imports.each do |inc|
          fout .puts %Q{%import "#{inc}"}
        end
      end

      unless spec.swig_includes.empty?
        fout.puts ''
        spec.swig_includes.each do |inc|
          fout.puts %Q{%include "#{inc}"}
        end
      end

      if spec.interface_code && !spec.interface_code.empty?
        fout.puts
        fout.puts spec.interface_code
      end
    end

    def gen_swig_interface_file(spec)
      gen_swig_interface_specs(CodeStream.new(spec.interface_file), spec)
    end

    def gen_interface_classes(fout, spec)
      spec.def_items.each do |item|
        if Extractor::ClassDef === item && !item.ignored && (!item.is_template? || spec.template_as_class?(item.name))
          unless spec.is_folded_base?(item.name)
            gen_interface_class(fout, spec, item)
          end
        end
      end
    end

    def gen_interface_class(fout, spec, classdef)
      fout.puts ''
      basecls = spec.base_class(classdef)
      if basecls
        fout.puts "class #{basecls};"
        fout.puts ''
      end
      is_struct = classdef.kind == 'struct'
      fout.puts "#{classdef.kind} #{spec.class_name(classdef)}#{basecls ? ' : public '+basecls : ''}"
      fout.puts '{'

      unless is_struct
        fout.puts 'public:'
        if (abstract_class = spec.is_abstract?(classdef))
          fout.puts "  virtual ~#{spec.class_name(classdef)}() =0;"
        end
      end

      methods = []
      gen_interface_class_members(fout, spec, classdef.name, classdef, 'public', methods, abstract_class)

      spec.folded_bases(classdef.name).each do |basename|
        gen_interface_class_members(fout, spec, classdef.name, spec.def_item(basename), 'public', methods)
      end

      spec.member_extensions(classdef.name).each do |extdecl|
        fout.puts '  // custom wxRuby3 extension'
        fout.puts "  #{extdecl};"
      end

      need_protected = classdef.regards_protected_members? ||
                          spec.folded_bases(classdef.name).any? { |base| spec.def_item(base).regards_protected_members? }
      unless is_struct || !need_protected
        fout.puts
        fout.puts ' protected:'
        gen_interface_class_members(fout, spec, classdef.name, classdef, 'protected', methods, abstract_class)

        spec.folded_bases(classdef.name).each do |basename|
          gen_interface_class_members(fout, spec, classdef.name, spec.def_item(basename), 'protected', methods)
        end
      end

      fout.puts '};'
    end

    def gen_interface_class_members(fout, spec, class_name, classdef, visibility, methods, abstract=false)
      # generate any inner classes
      classdef.innerclasses.each do |inner|
        if inner.protection == visibility && !inner.ignored && !inner.deprecated
          gen_interface_class(fout, spec, inner)
        end
      end
      # generate other members
      classdef.items.each do |member|
        case member
        when Extractor::MethodDef
          if member.is_ctor
            if member.protection == visibility && member.name == class_name
              if !member.ignored && !member.deprecated
                gen_only_for(fout, member) do
                  fout.puts "  #{spec.class_name(classdef)}#{member.args_string};" if !member.ignored && !member.deprecated
                end
              end
              member.overloads.each do |ovl|
                if ovl.protection == visibility && !ovl.ignored && !ovl.deprecated
                  gen_only_for(fout, ovl) do
                    fout.puts "  #{spec.class_name(classdef)}#{ovl.args_string};"
                  end
                end
              end
            end
          elsif member.is_dtor && member.protection == visibility
            if member.name == "~#{class_name}" && !abstract
              ctor_sig = "~#{spec.class_name(classdef)}()"
              fout.puts "  #{member.is_virtual ? 'virtual ' : ''}#{ctor_sig};"
            end
          elsif member.protection == visibility
            gen_interface_class_method(fout, member, methods) if !member.ignored && !member.deprecated && !member.is_template?
            member.overloads.each do |ovl|
              if ovl.protection == visibility && !ovl.ignored && !ovl.deprecated && !member.is_template?
                gen_interface_class_method(fout, ovl, methods)
              end
            end
          end
        when Extractor::EnumDef
          if member.protection == visibility && !member.ignored && !member.deprecated
            gen_only_for(fout, member) do
              fout.puts "  // from #{classdef.name}::#{member.name}"
              fout.puts "  enum #{member.name.start_with?('@') ? '' : member.name} {"
              enum_size = member.items.size
              member.items.each_with_index do |e, i|
                gen_only_for(fout, e) do
                  fout.puts "    #{e.name}#{(i+1)<enum_size ? ',' : ''}"
                end
              end
              fout.puts "  };"
            end
          end
        when Extractor::MemberVarDef
          if member.protection == visibility && !member.ignored && !member.deprecated
            gen_only_for(fout, member) do
              fout.puts "  // from #{member.definition}"
              fout.puts "  #{member.is_static ? 'static ' : ''}#{member.type} #{member.name};"
            end
          end
        end
      end
    end

    def gen_interface_class_method(fout, methoddef, methods)
      # skip virtuals that have been overridden
      unless (methoddef.is_virtual && methods.any? { |m| m.signature == methoddef.signature }) ||
        # skip virtual that have non-virtual shadowing overloads
        (!methoddef.is_virtual && methods.any? { |m| m.name == methoddef.name && m.class_name != methoddef.class_name })
        gen_only_for(fout, methoddef) do
          fout.puts "  // from #{methoddef.definition}"
          mdecl = methoddef.is_static ? 'static ' : ''
          mdecl << 'virtual ' if methoddef.is_virtual
          fout.puts "  #{mdecl}#{methoddef.type} #{methoddef.name}#{methoddef.args_string};"
        end
        methods << methoddef
      end
    end

    def gen_typedefs(fout, spec)
      typedefs = spec.def_items.select {|item| Extractor::TypedefDef === item && !item.ignored }
      typedefs.each do |item|
        fout.puts
        gen_only_for(fout, item) do
          fout.puts "#{item.definition};"
        end
      end
      fout.puts '' unless typedefs.empty?
    end

    def gen_variables(fout, spec)
      vars = spec.def_items.select {|item| Extractor::GlobalVarDef === item && !item.ignored }
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

    def gen_enums(fout, spec)
      fout << spec.def_items.inject('') do |code, item|
        if Extractor::EnumDef === item && !item.ignored
          fout.puts
          fout.puts "// from enum #{item.name.start_with?('@') ? '' : item.name}"
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

    def init_rb_ext_file(spec)
      frbext = CodeStream.new(spec.interface_ext_file)
      frbext  << <<~__HEREDOC
        # ----------------------------------------------------------------------------
        # This file is automatically generated by the WXRuby3 code 
        # generator. Do not alter this file.
        # ----------------------------------------------------------------------------

        __HEREDOC
      spec.package.all_modules.each do |mod|
        frbext.puts "module #{mod}"
      end
      frbext.puts
      frbext
    end

    def gen_defines(fout, spec)
      frbext = nil
      defines = spec.def_items.select {|item|
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
            frbext = init_rb_ext_file(spec) unless frbext
            frbext.indent { frbext.puts "#{rb_wx_name(item.name)} = Wx::#{$1}.new#{$2}" }
            frbext.puts
          elsif item.value =~ /wx(Colour|Font)(\(.*\))/
            frbext = init_rb_ext_file(spec) unless frbext
            frbext.indent do
              frbext.puts "Wx.add_delayed_constant(self, :#{rb_wx_name(item.name)}) { Wx::#{$1}.new#{$2} }"
            end
            frbext.puts
          elsif item.value =~ /wxSystemSettings::(\w+)\((.*)\)/
            frbext = init_rb_ext_file(spec) unless frbext
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
        spec.package.all_modules.each { |mod| frbext.puts 'end' }
      end
      fout.puts '' unless defines.empty?
    end

    def gen_functions(fout, spec)
      functions = spec.def_items.select {|item| Extractor::FunctionDef === item && !item.is_template? }
      functions.each do |item|
        active_overloads = item.all.select { |ovl| !ovl.ignored && !ovl.deprecated }
        active_overloads.each do |ovl|
          fout.puts
          gen_only_for(fout, ovl) do
            fout.puts "#{ovl.type} #{ovl.name}#{ovl.args_string};"
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

    def gen_swig_interface_specs(fout, spec)
      gen_swig_header(fout, spec)

      gen_swig_gc_types(fout, spec)

      gen_swig_begin_code(fout, spec)

      gen_swig_runtime_code(fout, spec)

      gen_swig_code(fout, spec)

      gen_swig_init_code(fout, spec)

      gen_swig_extensions(fout, spec)

      gen_swig_interface_code(fout, spec)

      gen_swig_wrapper_code(fout, spec)
    end

    def gen_interface_include(spec)
      gen_interface_include_code(
        CodeStream.new(spec.interface_include_file),
        spec)
    end

    def gen_interface_include_header(fout, spec)
      fout << <<~HEREDOC
        /**
         * This file is automatically generated by the WXRuby3 interface generator.
         * Do not alter this file.
         */
                 
        #ifndef __#{spec.module_name.upcase}_H_INCLUDED__
        #define __#{spec.module_name.upcase}_H_INCLUDED__
      HEREDOC
    end

    def gen_interface_include_footer(fout, spec)
      fout << "\n#endif /* __#{spec.module_name.upcase}_H_INCLUDED__ */"
    end

    def gen_interface_include_code(fout, spec)
      gen_interface_include_header(fout, spec)

      gen_typedefs(fout, spec) unless spec.no_gen?(:typedefs)

      gen_interface_classes(fout, spec) unless spec.no_gen?(:classes)

      gen_variables(fout, spec) unless spec.no_gen?(:variables)

      gen_enums(fout, spec) unless spec.no_gen?(:enums)

      gen_defines(fout, spec) unless spec.no_gen?(:defines)

      gen_functions(fout, spec) unless spec.no_gen?(:functions)

      gen_interface_include_footer(fout, spec)
    end

    def run(spec)
      Stream.transaction do

        gen_swig_interface_file(spec)

        gen_interface_include(spec)

      end
    end

  end # class ClassGenerator

end # module WXRuby3