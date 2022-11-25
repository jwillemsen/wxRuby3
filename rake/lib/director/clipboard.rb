#--------------------------------------------------------------------
# @file    clipboard.rb
# @author  Martin Corino
#
# @brief   wxRuby3 wxWidgets interface director
#
# @copyright Copyright (c) M.J.N. Corino, The Netherlands
#--------------------------------------------------------------------

module WXRuby3

  class Director

    class Clipboard < Director

      def setup
        super
        spec.gc_never
        # there is no need or support for clipboard derivatives
        # not least because wxRuby only ever allows a single global clipboard
        spec.disable_proxies
        spec.swig_include '../shared/data_format.i'
        spec.swig_include '../shared/data_object_common.i'
        spec.make_abstract 'wxClipboard'
        # After a data object has been set to the clipboard using set_data, it
        # becomes owned by the clipboard and shouldn't be freed
        spec.disown 'wxDataObject* data'
        spec.add_extend_code 'wxClipboard', <<~__HEREDOC
          // Provide access to the global clipboard; same clipboard must be used
          // between calls to do data transfer properly.
          static VALUE get_global_clipboard() 
          {
            return SWIG_NewPointerObj(wxTheClipboard, SWIGTYPE_p_wxClipboard, 0);
          }
          __HEREDOC
      end
    end # class Clipboard

  end # class Director

end # module WXRuby3