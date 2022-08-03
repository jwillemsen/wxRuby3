#--------------------------------------------------------------------
# @file    base.rb
# @author  Martin Corino
#
# @brief   wxRuby3 wxWidgets interface generation templates
#
# @copyright Copyright (c) M.J.N. Corino, The Netherlands
#--------------------------------------------------------------------

require 'erb'
require 'pathname'
require 'set'

module WXRuby3

  class Generator

    class Spec

      def initialize(ifspec, defmod)
        @ifspec = ifspec
        @defmod = defmod
      end

      def interface_file
        @ifspec.interface_file
      end

      def interface_include
        "#{WXRuby3::Config.instance.interface_dir}/#{@ifspec.module_name}.h"
      end

      def interface_include_file
        "#{WXRuby3::Config.instance.interface_path}/#{@ifspec.module_name}.h"
      end

      def module_name
        @ifspec.module_name
      end

      def get_base_class(hierarchy, foldedbases, ignoredbases)
        hierarchy = hierarchy.select { |basenm, _| !ignoredbases.include?(basenm) }
        raise "Cannot determin base class from multiple inheritance hierarchy : #{hierarchy}" if hierarchy.size>1
        return nil if hierarchy.empty?
        basenm, bases = hierarchy.first
        return basenm unless foldedbases.include?(basenm)
        get_base_class(bases, folded_bases(basenm), ignored_bases(basenm))
      end
      private :get_base_class

      def base_class(classdef_or_name)
        class_def = (Extractor::ClassDef === classdef_or_name ?
                          classdef_or_name : @defmod.find(classdef_or_name))
        get_base_class(class_def.hierarchy, folded_bases(class_def.name), ignored_bases(class_def.name))
      end

      def get_base_list(hierarchy, foldedbases, ignoredbases, list = ::Set.new)
        hierarchy = hierarchy.select { |basenm, _| !ignoredbases.include?(basenm) }
        hierarchy.each do |basenm, bases|
          list << basenm unless foldedbases.include?(basenm)
          get_base_list(bases, folded_bases(basenm), ignored_bases(basenm), list)
        end
        list
      end

      def base_list(classdef_or_name)
        class_def = (Extractor::ClassDef === classdef_or_name ?
                          classdef_or_name : @defmod.find(classdef_or_name))
        get_base_list(class_def.hierarchy, folded_bases(class_def.name), ignored_bases(class_def.name)).to_a
      end

      def is_folded_base?(cnm)
        @ifspec.folded_bases.values.any? { |nms| nms.include?(cnm) }
      end

      def folded_bases(cnm)
        @ifspec.folded_bases[cnm] || []
      end

      def ignored_bases(cnm)
        (@ifspec.ignored_bases[cnm] || []) + Director::Spec::IGNORED_BASES
      end

      def abstract(classdef_or_name)
        class_def = (Extractor::ClassDef === classdef_or_name ?
                          classdef_or_name : @defmod.find(classdef_or_name))
        @ifspec.abstract || class_def.abstract
      end

      def gc_type(classdef)
        unless @ifspec.gc_type
          if classdef
            return :GC_MANAGE_AS_EVENT if classdef.is_derived_from?('wxEvent')
            return :GC_MANAGE_AS_FRAME if classdef.is_derived_from?('wxFrame')
            return :GC_MANAGE_AS_DIALOG if classdef.is_derived_from?('wxDialog')
            return :GC_MANAGE_AS_WINDOW if classdef.is_derived_from?('wxWindow')
            return :GC_MANAGE_AS_SIZER if classdef.is_derived_from?('wxSizer')
            return :GC_MANAGE_AS_OBJECT if classdef.is_derived_from?('wxObject') || classdef.name == 'wxObject'
            return :GC_MANAGE_AS_TEMP
          end
        end
        @ifspec.gc_type || :GC_NEVER
      end

      def includes
        @ifspec.includes
      end

      def no_proxies
        @ifspec.no_proxies
      end

      def swig_begin_code
        @ifspec.swig_begin_code.join("\n")
      end

      def begin_code
        @ifspec.begin_code.join("\n")
      end

      def swig_runtime_code
        @ifspec.swig_runtime_code.join("\n")
      end

      def runtime_code
        @ifspec.runtime_code.join("\n")
      end

      def swig_header_code
        @ifspec.swig_header_code.join("\n")
      end

      def header_code
        @ifspec.header_code.join("\n")
      end

      def swig_wrapper_code
        @ifspec.swig_wrapper_code.join("\n")
      end

      def wrapper_code
        @ifspec.wrapper_code.join("\n")
      end

      def swig_init_code
        @ifspec.swig_init_code.join("\n")
      end

      def init_code
        @ifspec.init_code.join("\n")
      end

      def swig_interface_code
        @ifspec.swig_interface_code.join("\n")
      end

      def interface_code
        if @ifspec.interface_code && !@ifspec.interface_code.empty?
          @ifspec.interface_code.join("\n")
        else
          %Q{%include "#{interface_include}"\n}
        end
      end

      def extend_code(cnm)
        p @ifspec.extend_code
        (@ifspec.extend_code[cnm] || []).join("\n")
      end

      def swig_imports
        @ifspec.swig_imports
      end

      def swig_includes
        @ifspec.swig_includes
      end

      def renames
        @ifspec.renames
      end

      def def_items
        @defmod.items
      end

      def def_item(name)
        @defmod.find(name)
      end

    end

    def run(spec)
    end

    def gen_interface_classes(fout, spec)
      spec.def_items.each do |item|
        if Extractor::ClassDef === item && !item.ignored && !item.is_template?
          unless spec.is_folded_base?(item.name)
            gen_interface_class(fout, spec, item)
          end
        end
      end
    end

    def gen_interface_class(fout, spec, classdef)
      fout.puts ''
      basecls = spec.base_class(classdef)
      fout.puts "class #{classdef.name}#{basecls ? ' : '+basecls : ''}"
      fout.puts '{'

      abstract_class = spec.abstract(classdef)
      if abstract_class
        fout.puts 'private:'
        fout.puts "  #{classdef.name}();"
      end

      fout.puts 'public:'

      overrides = ::Set.new
      gen_interface_class_members(fout, classdef.name, classdef, overrides, abstract_class)

      spec.folded_bases(classdef.name).each do |basename|
        gen_interface_class_members(fout, classdef.name, spec.def_item(basename), overrides)
      end

      fout.puts '};'
    end

    def gen_interface_class_members(fout, class_name, classdef, overrides, abstract=false)
      classdef.items.each do |member|
        case member
        when Extractor::MethodDef
          if member.is_ctor
            if !abstract && member.protection == 'public' && member.name == class_name
              fout.puts "  #{class_name}#{member.args_string};" if !member.ignored
              member.overloads.each do |ovl|
                if ovl.protection == 'public' && !ovl.ignored
                  fout.puts "  #{class_name}#{ovl.args_string};"
                end
              end
            end
          elsif member.is_dtor
            fout.puts "  #{member.is_virtual ? 'virtual ' : ''}~#{class_name}#{member.args_string};" if member.name == "~#{class_name}"
          elsif member.protection == 'public' && !member.is_operator && !member.ignored
            gen_interface_class_method(fout, member, overrides)
            member.overloads.each do |ovl|
              if ovl.protection == 'public' && !ovl.ignored
                gen_interface_class_method(fout, ovl, overrides)
              end
            end
          end
        end
      end
    end

    def gen_interface_class_method(fout, methoddef, overrides)
        unless methoddef.is_pure_virtual || (methoddef.is_virtual && overrides.include?(methoddef.signature))
          fout.puts "#ifdef __#{methoddef.only_for.upcase}__" if methoddef.only_for
          fout.puts "  // from #{methoddef.definition}"
          fout.puts "  #{methoddef.is_virtual ? 'virtual ' : ''}#{methoddef.type} #{methoddef.name}#{methoddef.args_string};"
          fout.puts "#endif" if methoddef.only_for
          overrides << methoddef.signature if methoddef.is_override
        end
    end

    def gen_typedefs(fout, spec)
      typedefs = spec.def_items.select {|item| Extractor::TypedefDef === item && !item.ignored }
      fout << typedefs.collect {|item| "\n#{item.definition};" }.join
      fout.puts '' unless typedefs.empty?
    end

    def gen_variables(fout, spec)
      vars = spec.def_items.select {|item| Extractor::GlobalVarDef === item && !item.ignored }
      fout << vars.collect {|item| "\n%constant #{item.definition}#{" #{item.value}".rstrip};" }.join
      fout.puts '' unless vars.empty?
    end

    def gen_enums(fout, spec)
      fout << spec.def_items.inject('') do |code, item|
        if Extractor::EnumDef === item && !item.ignored
          code << "\n// from enum #{item.name || ''}\n"
          item.items.each { |e| code << "%constant int #{e.name} = #{e.name};\n" }
        end
        code
      end
    end

    def gen_defines(fout, spec)
      defines = spec.def_items.select {|item|
        Extractor::DefineDef === item && !item.ignored && !item.is_macro? && item.value && !item.value.empty?
      }
      fout << defines.collect {|item| "\n#define #{item.name} #{item.value}" }.join
      fout.puts '' unless defines.empty?
    end

    def gen_functions(fout, spec)
      functions = spec.def_items.select {|item| Extractor::FunctionDef === item && !item.ignored && !item.is_template? }
      fout << functions.collect do |item|
        active_overloads = item.overloads.select { |ovl| !ovl.ignored }
        [
          "\n#{item.type} #{item.name}#{item.args_string};"
        ].concat active_overloads.collect { |ovl| "\n#{ovl.type} #{ovl.name}#{ovl.args_string};" }
      end.flatten.join
      fout.puts '' unless functions.empty?
    end

  end # class Generator

end # module WXRuby3