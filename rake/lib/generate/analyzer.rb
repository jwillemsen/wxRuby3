#--------------------------------------------------------------------
# @file    analyzer.rb
# @author  Martin Corino
#
# @brief   wxRuby3 wxWidgets interface
#
# @copyright Copyright (c) M.J.N. Corino, The Netherlands
#--------------------------------------------------------------------

require 'monitor'

module WXRuby3

  class InterfaceAnalyzer

    class InterfaceRegistry
      include MonitorMixin

      def initialize
        super
        @registry = {}
      end

      def has_class?(clsnm)
        self.synchronize do
          @registry.has_key?(clsnm)
        end
      end

      def class_registry(clsnm)
        self.synchronize do
          @registry[clsnm]
        end
      end

      def add_class_registry(clsnm, reg)
        self.synchronize do
          raise "!!ERROR: duplicate interface registry for class #{clsnm}" if @registry.has_key?(clsnm)
          @registry[clsnm] = reg
        end
      end
    end

    class ClassRegistry
      def initialize
        @registry = {members: {public: [], protected: []}, methods: {}}
      end

      def public_members
        @registry[:members][:public]
      end

      def protected_members
        @registry[:members][:protected]
      end

      def methods
        @registry[:methods]
      end
    end

    class ClassProcessor

      def initialize(spec, classdef)
        @spec = spec
        @classdef = classdef
        @class_name = if classdef.is_template? && spec.template_as_class?(classdef.name)
                        spec.template_class_name(classdef.name)
                      else
                        classdef.name
                      end
        @class_registry = ClassRegistry.new
      end

      attr_reader :spec, :classdef, :class_name, :class_registry

      def register_interface_member(member, req_pure_virt=false)
        if member.protection == 'public'
          class_registry.public_members << member
        else
          class_registry.protected_members << member
        end
        if Extractor::MethodDef === member && !member.is_ctor && !member.is_dtor && !member.is_static
          class_registry.methods[member.signature] = {
            method: member,
            virtual: member.is_virtual,
            purevirt: req_pure_virt && member.is_pure_virtual,
            proxy: spec.has_method_proxy?(class_name, member)
          }
        end
      end

      def parse_method_decl(decl)
        if /\A\s*(virtual\s|static\s)?\s*(.*\W)?(\w+)\s*\(([^\)]*)\)(\s+const)?(\soverride)?/ =~ decl
          type = $2.to_s.strip
          arglist = $4.strip
          kwargs = {
            is_virtual: $1 && $1.strip == 'virtual',
            is_static: $1 && $1.strip == 'static',
            name: $3.strip,
            is_const: $5 && $5.strip == 'const',
            is_override: $6 && $6.strip == 'override',
            args_string: "(#{arglist})"
          }
          swig_clsnm = spec.class_name(class_name)
          if type == '~' && swig_clsnm == kwargs[:name]
            kwargs[:is_dtor] = true
          elsif type.empty? && swig_clsnm == kwargs[:name]
            kwargs[:is_ctor] =true
          else
            kwargs[:type] = type
          end
          mtdef = Extractor::MethodDef.new(nil, class_name, **kwargs)
          arglist.split(',').each do |arg|
            if /\A(const\s+)?(\w+)\s*(const\s+)?(\s*[\*\&])?\s*(\w+)\s*(\[\s*\])?(\s*=\s*(\S+))?\Z/ =~ arg.strip
              mtdef.items << Extractor::ParamDef.new(nil,
                                                     name: $4.to_s,
                                                     type: "#{$1}#{$2}#{$3}",
                                                     array: !$5.to_s.empty?,
                                                     default: $7)
            else
              raise "Unable to parse argument #{arg} of custom declaration [#{decl}] for class #{class_name}"
            end
          end
          return mtdef
        else
          raise "Unable to parse custom declaration [#{decl}] for class #{class_name}"
        end
        nil
      end

      def register_custom_interface_member(visibility, member, req_pure_virt)
        if visibility == 'public'
          class_registry.public_members << member
        else
          class_registry.protected_members << member
        end
        member = member.tr("\n", '')
        if /[^\(\)]+\([^\)]*\)[^\(\)]*/ =~ member
          mtdef = parse_method_decl(member)
          class_registry.methods[mtdef.signature] = {
            method: mtdef,
            virtual: mtdef.is_virtual,
            purevirt: req_pure_virt && mtdef.is_pure_virtual,
            proxy: spec.has_method_proxy?(class_name, mtdef),
            extension: true
          }
        end
      end

      def preprocess_class_method(methoddef, methods, requires_purevirt)
        # skip virtuals that have been overridden
        return if (methoddef.is_virtual && methods.any? { |m| m.signature == methoddef.signature })
        # or that have non-virtual shadowing overloads
        return if (!methoddef.is_virtual && methods.any? { |m| m.name == methoddef.name && m.class_name != methoddef.class_name })

        # register interface member for later problem analysis
        register_interface_member(methoddef,
                                  requires_purevirt)
        methods << methoddef
      end

      def preprocess_class_members(classdef, visibility, methods, requires_purevirt)
        classdef.items.each do |member|
          case member
          when Extractor::MethodDef
            if member.is_ctor
              if member.protection == visibility && member.name == class_name
                if !member.ignored && !member.deprecated
                  register_interface_member(member)
                end
                member.overloads.each do |ovl|
                  if ovl.protection == visibility && !ovl.ignored && !ovl.deprecated
                    register_interface_member(ovl)
                  end
                end
              end
            elsif member.is_dtor && member.protection == visibility
              if member.name == "~#{class_name}"
                register_interface_member(member)
              end
            elsif member.protection == visibility
              if !member.ignored && !member.deprecated && !member.is_template?
                preprocess_class_method(member, methods, requires_purevirt)
              end
              member.overloads.each do |ovl|
                if ovl.protection == visibility && !ovl.ignored && !ovl.deprecated && !ovl.is_template?
                  preprocess_class_method(ovl, methods, requires_purevirt)
                end
              end
            end
          when Extractor::EnumDef
            if member.protection == visibility && !member.ignored && !member.deprecated && member.items.any? {|e| !e.ignored }
              register_interface_member(member)
            end
          when Extractor::MemberVarDef
            if member.protection == visibility && !member.ignored && !member.deprecated
              register_interface_member(member)
            end
          end
        end
      end

      def preprocess
        STDERR.puts "** Preprocessing #{spec.module_name} class #{class_name}" if Director.trace?
        # preprocess any public inner classes
        classdef.innerclasses.each do |inner|
          if inner.protection == 'public' && !inner.ignored && !inner.deprecated
            register_interface_member(inner)
          end
        end
        # preprocess members (if any)
        requires_purevirtual = spec.has_proxy?(classdef)
        methods = []
        preprocess_class_members(classdef, 'public', methods, requires_purevirtual)

        spec.folded_bases(classdef.name).each do |basename|
          preprocess_class_members(spec.def_item(basename), 'public', methods, requires_purevirtual)
        end

        spec.interface_extensions(classdef).each do |extdecl|
          register_custom_interface_member('public', extdecl, requires_purevirtual)
        end

        need_protected = classdef.regards_protected_members? ||
          !spec.interface_extensions(classdef, 'protected').empty? ||
          spec.folded_bases(classdef.name).any? { |base| spec.def_item(base).regards_protected_members? }
        unless classdef.kind == 'struct' || !need_protected
          preprocess_class_members(classdef, 'protected', methods, requires_purevirtual)

          spec.folded_bases(classdef.name).each do |basename|
            preprocess_class_members(spec.def_item(basename), 'protected', methods, requires_purevirtual)
          end

          spec.interface_extensions(classdef, 'protected').each do |extdecl|
            register_custom_interface_member('protected', extdecl, requires_purevirtual)
          end
        end
      end

    end # ClassProcessor

    class << self

      private

      def interface_method_registry
        @registry ||= InterfaceRegistry.new
      end

      def class_interface_registry(class_name)
        interface_method_registry.class_registry(class_name)
      end

      def class_interface_methods(class_name)
        class_interface_registry(class_name).methods
      end

      def has_class_interface(class_name)
        interface_method_registry.has_class?(class_name)
      end

      def get_class_interface(package, class_name)
        dir = package.director_for_class(class_name)
        raise "Cannot determine director for class #{class_name}" unless dir
        dir.synchronize do
          dir.extract_interface(false) # make sure the Director has extracted data from XML
          # preprocess the items for this director
          preprocess(Generator::Spec.new(dir.spec, dir.defmod))
        end
      end

      def preprocess(spec)
        STDERR.puts "** Preprocessing #{spec.module_name}" if Director.trace?
        spec.def_items.each do |item|
          if Extractor::ClassDef === item && !item.ignored &&
            (!item.is_template? || spec.template_as_class?(item.name)) &&
            !spec.is_folded_base?(item.name)
            clsproc = ClassProcessor.new(spec, item)
            unless has_class_interface(clsproc.class_name)
              clsproc.preprocess
              interface_method_registry.add_class_registry(clsproc.class_name, clsproc.class_registry)
            end
          end
        end
      end

      public

      def class_interface_members_public(class_name)
        class_interface_registry(class_name).public_members
      end

      def class_interface_members_protected(class_name)
        class_interface_registry(class_name).protected_members
      end

      def class_interface_method_ignored?(class_name, mtdef)
        !!(class_interface_methods(class_name)[mtdef.signature] || {})[:ignore]
      end

      def check_interface_methods(spec)
        # preprocess definitions if not yet done
        preprocess(spec)
        # check the preprocessed definitions
        errors = []
        warnings = []
        spec.def_items.each do |item|
          if Extractor::ClassDef === item && !item.ignored &&
            (!item.is_template? || spec.template_as_class?(item.name)) &&
            !spec.is_folded_base?(item.name)
            intf_class_name = if item.is_template? || spec.template_as_class?(item.name)
                                spec.template_class_name(item.name)
                              else
                                item.name
                              end
            # this should not happen
            raise "Missing preprocessed data for class #{intf_class_name}\n#{interface_method_registry.keys}" unless has_class_interface(intf_class_name)
            # get the class's method registry
            cls_mtdreg = class_interface_methods(intf_class_name)
            # check all directly inherited generated methods
            mtdlist = ::Set.new # remember handled signatures
            spec.base_list(item).each do |base_name|
              # make sure the base class has been preprocessed
              get_class_interface(spec.package, base_name) unless has_class_interface(base_name)
              # iterate the base class's method registrations
              class_interface_methods(base_name).each_pair do |mtdsig, mtdreg|
                # only check on methods we have not handled yet
                if !mtdlist.include?(mtdsig)
                  # did we inherit a virtual method that was not proxied in the base
                  if mtdreg[:virtual] && !mtdreg[:proxy]
                    # if we did NOT generate a wrapper override and we do not have the proxy suppressed we're in trouble
                    if !cls_mtdreg.has_key?(mtdsig) && spec.has_method_proxy?(item.name, mtdreg[:method])
                      errors << "* ERROR: method #{mtdreg[:method].signature} is proxied without wrapper implementation in class #{item.name} but not proxied in base class #{base_name}!"
                    elsif cls_mtdreg.has_key?(mtdsig) && !cls_mtdreg[mtdsig][:extension] && !spec.has_method_proxy?(item.name, cls_mtdreg[mtdsig][:method])
                      # if this is not a custom extension and we do have an override wrapper and no proxy this is unnecessary code bloat
                      warnings << " * WARNING: Unnecessary override #{mtdreg[:method].signature} in class #{item.name} for non-proxied base in #{base_name}. Ignoring."
                      cls_mtdreg[mtdsig][:ignore] = true
                    end
                    # or did we inherit a virtual method that was proxied in the base
                    # for which we DO generate a wrapper override
                  elsif mtdreg[:virtual] && mtdreg[:proxy] && cls_mtdreg.has_key?(mtdsig)
                    # if we do not have a proxy as well we're in trouble
                    if !spec.has_method_proxy?(item, mtdreg[:method])
                      errors << "* ERROR: method #{mtdreg[:method].signature} is NOT proxied with an overriden wrapper implementation in class #{item.name} but is also implemented and proxied in base class #{base_name}!"
                    end
                  end
                  mtdlist << mtdsig
                end
              end
            end
          end
        end
        unless warnings.empty?
          warnings.each { |warn| STDERR.puts warn }
        end
        unless errors.empty?
          errors.each {|err| STDERR.puts err }
          raise "Errors found generating for module #{spec.module_name} from package #{spec.package.name}"
        end
      end

    end

  end # InterfaceAnalyzer

end