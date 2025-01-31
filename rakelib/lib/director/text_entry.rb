###
# wxRuby3 wxWidgets interface director
# Copyright (c) M.J.N. Corino, The Netherlands
###

module WXRuby3

  class Director

    class TextEntry < Director

      def setup
        super
        spec.items << 'wxTextCompleter' << 'wxTextCompleterSimple'
        spec.gc_as_temporary 'wxTextCompleter', 'wxTextCompleterSimple'
        spec.gc_as_temporary 'wxTextEntry' # actually no GC control necessary as this is a mixin only
        # turn wxTextEntry into a mixin module
        spec.make_mixin 'wxTextEntry'
        spec.disown 'wxTextCompleter *completer' # managed by wxWidgets after passing in
        spec.map_apply 'long * OUTPUT' => 'long *' # for GetSelection
      end
    end # class TextEntry

  end # class Director

end # module WXRuby3
