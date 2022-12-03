###
# wxRuby3 interface Director class
# Copyright (c) M.J.N. Corino, The Netherlands
###

require 'ostruct'
require 'set'
require 'pathname'
require 'tempfile'
require 'json'
require 'monitor'

require_relative './config'
require_relative './extractor'
require_relative './streams'
require_relative './swig_runner'
require_relative './util/string'
require_relative './core/spec'
require_relative './core/package'

module WXRuby3

  class Director

    include MonitorMixin
    include Util::StringUtil

    class << self
      def Package(pkgid, *required_features, &block)
        block.call(self[pkgid].requires(*required_features))
      end

      def Spec(pkg, modname, name: nil, director:  nil, processors: nil, requirements: [])
        pkg.add_director(WXRuby3::Director::Spec.new(pkg,
                                                     modname,
                                                     name: name,
                                                     director: director,
                                                     processors: processors,
                                                     requirements: requirements))
      end

      def verbose?
        ::Rake.verbose
      end

      def trace?
        ::Rake.application.options.trace
      end

      private

      def package(pkgname)
        packages[pkgname] ||= Package.new(pkgname)
      end

      def scan_for_includes(file)
        incs = []
        File.read(file).scan(/^%include\s+["'](.*?)["']\s*$/) do |_inc|
          # exclude SWIG standard typemaps include
          incs << File.join(File.dirname(file), $1) unless $1 == 'typemaps.i'
        end
        incs
      end

      def get_common_dependencies
        mods = ['swig/wx.i']
                 .concat(WXRuby3::Config.instance.helper_modules.collect { |m| "swig/#{m}.i" })
                 .concat(WXRuby3::Config.instance.include_modules)
        common_deps = mods.inject({}) do |hash, mod|
          hash[mod] = scan_for_includes(mod); hash
        end
        common_deps.keys.each do |incmod|
          common_deps[incmod].concat(common_deps[incmod].collect { |dep| common_deps[dep] || [] }.flatten)
        end
        common_deps
      end

      public

      def packages
        @packages ||= {}
      end

      def each_package(&block)
        packages.each_value do |pkg|
          pkg.each_package(&block) if Config::WxRubyFeatureInfo.features_set?(*pkg.required_features)
        end
      end

      def all_packages
        ::Enumerator::Chain.new(*packages.collect { |_, pkg| pkg.all_packages })
      end

      def common_dependencies
        @common_deps ||= get_common_dependencies
      end

      def [](pkg)
        pkg.split('::').inject(self) { |p, pkgnm| p.__send__(:package, pkgnm) }
      end

      def cpp_flags(cpp_src)
        each_package do |pkg|
          return pkg.cpp_flags if pkg.all_cpp_files.include?(cpp_src)
        end
        ''
      end

      def source_file
        @source_file ||= __FILE__
      end

      def source_file=(v)
        @source_file = v
      end

      def handle_subclassing(sub)
        sub.class_eval do
          def self.inherited(subsub)
            subsub.source_file = Pathname(caller_locations.first.absolute_path).relative_path_from(Pathname(Config.wxruby_root)).to_s
            Director.handle_subclassing(subsub)
          end
        end
      end
    end

    def self.inherited(sub)
      sub.source_file = Pathname(caller_locations.first.absolute_path).relative_path_from(Pathname(Config.wxruby_root)).to_s
      Director.handle_subclassing(sub)
    end

    def initialize(spec)
      super()
      @spec = spec
      @defmod = nil
      setup
    end

    attr_reader :spec, :defmod

    def has_events?
      @defmod.items.any? {|item| Extractor::ClassDef === item && item.event && !item.event_types.empty? }
    end

    def extract_interface(genint = true, gendoc: false)
      self.synchronize do
        unless @defmod
          STDERR.puts "* extracting #{spec.module_name}" if Director.trace?

          @defmod = process(gendoc: gendoc)

          register
        end
      end

      if genint
        generator.run
      end
    end

    def rake_file
      File.join(Config.instance.rake_deps_path, ".#{spec.name}.rake")
    end

    def source_files
      list = [Pathname(Director.source_file).relative_path_from(Pathname(WXRuby3::Config.wxruby_root)).to_s]
      kls = self.class
      while kls != Director
        list << kls.source_file
        kls = kls.superclass
      end
      list
    end

    def create_rakefile
      # make sure XML specs have been extracted
      extract_interface(false) # no need to generate anything yet
      # create dependencies
      rake_generator.run
    end

    def generate_code
      extract_interface(false) # make sure interface specs have been extracted
      SwigRunner.process(self)
    end

    def generate_doc
      extract_interface(false, gendoc: true) # make sure interface specs have been extracted
      doc_generator.run
    end

    protected

    def setup
      # noop
    end

    def handle_item_ignore(defmod, fullname, ignore, ignoredoc)
      action = ignore ? 'ignore' : 'regard'
      # find the item
      item = defmod.find_item(fullname)
      if item
        # set the item's ignore flags
        item.ignore(ignore, ignore_doc: ignoredoc)
        # in case we looked up a function without arg mask also set the ignore flags of any overloads
        if Extractor::FunctionDef === item && !fullname.index('(')
          item.overloads.each {|ovl| ovl.ignore(ignore, ignore_doc: ignoredoc) }
        end
      else
        STDERR.puts "INFO: Cannot find '#{fullname}' (module '#{spec.module_name}') to #{action}."
      end
    end

    def handle_item_only_for(defmod, fullname, platform_id)
      # find the item
      item = defmod.find_item(fullname)
      if item
        # set the item's only_for specs
        item.only_for = platform_id
        # in case we looked up a function without arg mask also set the only_for specs of any overloads
        if Extractor::FunctionDef === item && !fullname.index('(')
          item.overloads.each {|ovl| ovl.only_for = platform_id }
        end
      else
        raise "Cannot find '#{fullname}' for module '#{spec.module_name}' to set only_for [#{platform_id}]"
      end
    end

    def process(gendoc: false)
      # extract the module definitions
      defmod = Extractor.extract_module(spec.package, spec.module_name, spec.name, spec.items, gendoc: gendoc)
      # handle ignores
      spec.ignores.each_pair do |fullname, ignoredoc|
        handle_item_ignore(defmod, fullname, true, ignoredoc)
      end
      # handle regards
      spec.regards.each_pair do |fullname, regarddoc|
        handle_item_ignore(defmod, fullname, false, !regarddoc)
      end
      # handle only_for settings
      spec.only_for.each_pair do |platform_id, names|
        names.each do |fullname|
          handle_item_only_for(defmod, fullname, platform_id)
        end
      end
      # handle class specific parameter mappings
      spec.param_mappings.each_pair do |clsnm, maps|
        item = defmod.find_item(clsnm)
        if item && Extractor::ClassDef === item
          maps.each { |map| item.add_param_mapping(*map) }
        else
          raise "Cannot find class '#{clsnm}' for parameter mapping #{map} in module '#{spec.module_name}'"
        end
      end
      # handle class specified includes
      defmod.classes.each do |cls|
        unless cls.ignored
          spec.includes.merge(cls.includes) unless cls.includes.empty?
        end
      end
      # TODO - should we just ignore all deprecations?
      # create deprecated function proxies unless deprecates suppressed
      unless Config.instance.no_deprecate
        defmod.items.select {|i| !i.ignored }.each do |item|
          case item
          when Extractor::ClassDef
            clsnm = spec.class_name(item.name)
            item.items.each do |member|
              if Extractor::MethodDef === member
                member.all.each do |ovl|
                  if !ovl.ignored && ovl.deprecated
                    is_void = (ovl.type && !ovl.type=='void')
                    if ovl.only_for
                      spec.add_extend_code clsnm, if ::Array === ovl.only_for
                                                    "#if #{ovl.only_for.collect { |s| "defined(__#{s.upcase}__)" }.join(' || ')}"
                                                  else
                                                    "#ifdef #{ovl.only_for}"
                                                  end
                    end
                    spec.add_extend_code clsnm, <<~__HEREDOC
                      #{ovl.is_static ? 'static ' : ''}#{ovl.type} #{ovl.name}#{ovl.args_string} {
                        std::wcerr << "DEPRECATION WARNING: #{ovl.is_static ? 'static ' : ''}#{ovl.type} #{clsnm}::#{ovl.name}#{ovl.args_string}" << std::endl;
                        #{is_void ? '' : 'return '}$self->#{ovl.name}(#{ovl.parameters.collect {|p| p.name}.join(',')});
                      }
                      __HEREDOC
                    spec.add_extend_code(clsnm, '#endif') if ovl.only_for
                  end
                end
              end
            end
          when Extractor::FunctionDef
            if item.deprecated
              is_void = (item.type && !item.type=='void')
              spec.add_swig_code <<~__HEREDOC
                // auto-generated deprecation function wrapper
                #{item.type} #{item.name}#{item.args_string} {
                  std::wcerr << "DEPRECATION WARNING: #{item.type} #{item.name}#{item.args_string}" << std::endl;
                  #{is_void ? '' : 'return '}#{item.name}(#{item.parameters.collect {|p| p.name}.join(',')});
                }
                __HEREDOC
            end
          end
        end
      end

      defmod
    end

    def register
      helper = DirectorSpecsHelper::Simple.new(self)
      mreg = {}
      helper.def_items.each do |item|
        if Extractor::ClassDef === item && !item.ignored
          mreg[item.name] = helper.base_class(item)
          Spec.class_index[item.name] = helper
        end
        Spec.module_registry[helper.module_name] = mreg
      end
    end
    private :register

    def generator
      WXRuby3::InterfaceGenerator.new(self)
    end

    def doc_generator
      WXRuby3::DocGenerator.new(self)
    end

    def rake_generator
      RakeDependencyGenerator.new(self)
    end

    class FixedInterface < Director

      def extract_interface(genint = nil)
        # noop
      end
    end

  end # class Director

end # module WXRuby3

Dir.glob(File.join(File.dirname(__FILE__), 'generate', '*.rb')).each do |fn|
  require fn
end
Dir.glob(File.join(File.dirname(__FILE__), 'director', '*.rb')).each do |fn|
  require fn
end

require_relative './specs/interfaces'
