#--------------------------------------------------------------------
# @file    task_bar_icon.rb
# @author  Martin Corino
#
# @brief   wxRuby3 wxWidgets interface director
#
# @copyright Copyright (c) M.J.N. Corino, The Netherlands
#--------------------------------------------------------------------

module WXRuby3

  class Director

    class TaskBarIcon < Director

      def setup
        super
        spec.gc_never
        # This is used for CreatePopupMenu, a virtual method which is
        # overridden in user subclasses of TaskBarIcon to create the menu over
        # the icon.
        #
        # The Wx::Menu needs to be protected from GC so the typemap stores the
        # object returned by the ruby method in an instance variable so it's
        # marked. It also handles the special case where +nil+ is returned, to
        # signal to Wx that no menu is to be shown.
        spec.add_swig_code <<~__HEREDOC
          %typemap(directorout) wxMenu * {
            rb_iv_set(swig_get_self(), "@__popmenu__", $1);
            if (NIL_P($1))
            {
              $result = NULL;
            }
            else
            {
              void * ptr;
              bool swig_res = SWIG_ConvertPtr(result, &ptr,$1 _descriptor,0 | SWIG_POINTER_DISOWN);
              if (!SWIG_IsOK(swig_res))
              {
                rb_raise(rb_eTypeError,
                         "create_popup_menu must return a Wx::Menu, or nil");
              }
              $result = reinterpret_cast < wxMenu * > (ptr);
            }
          }
          __HEREDOC
        spec.add_extend_code 'wxTaskBarIcon', <<~__HEREDOC
          // Explicitly dispose of a TaskBarIcon; needed for clean exits on
          // Windows.
          VALUE destroy()
          {
            delete $self;
            return Qnil;
          }
          __HEREDOC
        # already generated with TaskBarIconEvent
        spec.do_not_generate :variables, :enums, :defines, :functions
      end
    end # class TaskBarIcon

  end # class Director

end # module WXRuby3