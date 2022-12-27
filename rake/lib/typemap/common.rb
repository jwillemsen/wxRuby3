###
# wxRuby3 Common typemap definitions
# Copyright (c) M.J.N. Corino, The Netherlands
###

require_relative '../core/mapping'

module WXRuby3

  module Typemap

    module Common

      include Typemap::Module

      define do

        map 'int * OUTPUT' => 'Integer' do
          map_directorargout code: <<~__CODE
            if(output != Qnil)
            {
              *$1 = (int)NUM2INT(output);
            }
            else
            {
              *$1 = 0;
            }
            __CODE
        end

        map 'long * OUTPUT' => 'Integer' do
          map_directorargout code: <<~__CODE
            if(output != Qnil)
            {
              *$1 = (int)NUM2INT(output);
            }
            else
            {
              *$1 = 0;
            }
          __CODE
        end

        # String <> wxString type mappings

        map 'wxString&' => 'String' do
          map_in temp: 'wxString tmp', code: 'tmp = RSTR_TO_WXSTR($input); $1 = &tmp;'
          map_out code: '$result = WXSTR_PTR_TO_RSTR($1);'
          map_directorout code: '$result = RSTR_TO_WXSTR($input);'
          map_directorin code: '$input = WXSTR_TO_RSTR($1);'
          map_typecheck precedence: 'STRING', code: '$1 = (TYPE($input) == T_STRING);'
        end

        map 'wxString*' => 'String' do
          map_in temp: 'wxString tmp', code: 'tmp = RSTR_TO_WXSTR($input); $1 = &tmp;'
          map_out code: '$result = WXSTR_PTR_TO_RSTR($1);'
          map_directorin code: '$input = WXSTR_PTR_TO_RSTR($1);'
          map_typecheck precedence: 'STRING', code: '$1 = (TYPE($input) == T_STRING);'
        end

        map 'wxString' => 'String' do
          map_out code: '$result = WXSTR_TO_RSTR($1);'
          map_directorout code: '$result = RSTR_TO_WXSTR($input);'
          map_typecheck precedence: 'STRING', code: '$1 = (TYPE($input) == T_STRING);'
          map_varout code: '$result = WXSTR_TO_RSTR($1);'
        end

        # String <> wxChar* type mappings

        # %typemap(in) const wxChar const * (wxString temp) {
        #   temp = ($input == Qnil ? wxString() : wxString(StringValuePtr($input), wxConvUTF8));
        #   $1 = const_cast<wxChar*> (static_cast<wxChar const *> (temp.c_str()));
        # }

        map 'const wxChar *' => 'String' do
          map_in temp: 'wxString temp', code: <<~__CODE
            temp = ($input == Qnil ? wxString() : wxString(StringValuePtr($input), wxConvUTF8));
            $1 = const_cast<wxChar*> (static_cast<wxChar const *> (temp.c_str()));
            __CODE
          map_out code: '$result = rb_str_new2((const char *)wxString($1).utf8_str());'
          map_directorin code: "$input = rb_str_new2((const char *)wxString($1).utf8_str());"
          map_typecheck precedence: 'string', code: '$1 = (TYPE($input) == T_STRING);'
          map_varout code: '$result = rb_str_new2((const char *)wxString($1).utf8_str());'
        end

        # Object <> void* type mappings

        map 'void*' => 'Object' do
          map_in code: '$1 = (void*)($input);'
          map_out code: '$result = (VALUE)($1);'
          map_typecheck precedence: 'POINTER', code: '$1 = TRUE;'
        end

        # Typemaps for wxSize and wxPoint as input parameters; for brevity,
        # wxRuby permits these common input parameters to be represented as
        # two-element arrays [x, y] or [width, height].

        map 'wxSize&' => 'Array<Integer>, Wx::Size',
            'wxPoint&' => 'Array<Integer>, Wx::Point' do
          map_in code: <<~__CODE
            if ( TYPE($input) == T_DATA )
            {
              void* argp$argnum;
              SWIG_ConvertPtr($input, &argp$argnum, $1_descriptor, 1 );
              $1 = reinterpret_cast< $1_basetype * >(argp$argnum);
            }
            else if ( TYPE($input) == T_ARRAY )
            {
              $1 = new $1_basetype( NUM2INT( rb_ary_entry($input, 0) ),
                                   NUM2INT( rb_ary_entry($input, 1) ) );
              // Create a ruby object so the C++ obj is freed when GC runs
              SWIG_NewPointerObj($1, $1_descriptor, 1);
            }
            else
            {
              rb_raise(rb_eTypeError, "Wrong type for $1_basetype parameter");
            }
            __CODE
          map_typecheck precedence: 'POINTER', code: <<~__CODE
            void *vptr = 0;
            $1 = 0;
            if (TYPE($input) == T_ARRAY && RARRAY_LEN($input) == 2)
              $1 = 1;
            else if (TYPE($input) == T_DATA && SWIG_CheckState (SWIG_ConvertPtr ($input, &vptr, $1_descriptor, 0)))
              $1 = 1;
            __CODE
        end

        # Integer <> wxItemKind type mappings

        map 'wxItemKind' => 'Integer' do
          map_in code: '$1 = (wxItemKind)NUM2INT($input);'
          map_out code: '$result = INT2NUM((int)$1);'
          # fixes mixup between
          # wxMenuItem* wxMenu::Append(int itemid, const wxString& text, const wxString& help = wxEmptyString, wxItemKind kind = wxITEM_NORMAL)
          # and
          # void wxMenu::Append(int itemid, const wxString& text, const wxString& help, bool isCheckable);
          map_typecheck precedence: 'INTEGER',
                        code: '$1 = (TYPE($input) == T_FIXNUM && TYPE($input) != T_TRUE && TYPE($input) != T_FALSE);'
        end

        # Array<String> <> wxString[]/wxString* type mappings

        map 'int n, const wxString choices []',
            'int n, const wxString* choices',
            'int nItems, const wxString *items' do
          map_in from: { type: 'Array<String>', index: 1 }, temp: 'wxString *arr', code: <<~__CODE
            if (($input == Qnil) || (TYPE($input) != T_ARRAY))
            {
              $1 = 0;
              $2 = NULL;
            }
            else
            {
              arr = new wxString[ RARRAY_LEN($input) ];
              for (int i = 0; i < RARRAY_LEN($input); i++)
              {
                VALUE str = rb_ary_entry($input,i);
                arr[i] = wxString(StringValuePtr(str), wxConvUTF8);
              }
              $1 = RARRAY_LEN($input);
              $2 = arr;
            }
            __CODE
          map_default code: <<~__CODE
            {
              $1 = 0;
              $2 = NULL;
            }
            __CODE
          map_freearg code: 'if ($2 != NULL) delete [] $2;'
          map_typecheck precedence: 'STRING_ARRAY', code: '$1 = (TYPE($input) == T_ARRAY);'
        end

        # Array<String> <> wxArrayString type mappings

        map 'wxArrayString &' => 'Array<String>' do
          map_in temp: 'wxArrayString tmp', code: <<~__CODE
            if (($input == Qnil) || (TYPE($input) != T_ARRAY))
            {
              $1 = &tmp;
            }
            else
            {
              for (int i = 0; i < RARRAY_LEN($input); i++)
              {
                VALUE str = rb_ary_entry($input, i);
                wxString item(StringValuePtr(str), wxConvUTF8);
                tmp.Add(item);
              }
              $1 = &tmp;
            }
            __CODE
          map_out code: <<~__CODE
            $result = rb_ary_new();
            for (size_t i = 0; i < $1->GetCount(); i++)
            {
              rb_ary_push($result, WXSTR_TO_RSTR($1->Item(i)));
            }
            __CODE
          map_typecheck precedence: 'STRING_ARRAY', code: '$1 = (TYPE($input) == T_ARRAY);'
        end

        # wxArrayString return by value
        map 'wxArrayString' => 'Array<String>' do
          map_out code: <<~__CODE
              $result = rb_ary_new();
              for (size_t i = 0; i < $1.GetCount(); i++)
              {
                rb_ary_push($result, WXSTR_TO_RSTR($1.Item(i)));
              }
          __CODE
        end

        # Array<Integer> <> wxArrayInt/wxArrayInt& type mappings

        map 'wxArrayInt' => 'Array<Integer>' do
          map_in temp: 'wxArrayInt tmp', code: <<~__CODE
            if (($input == Qnil) || (TYPE($input) != T_ARRAY))
            {
              $1 = &tmp;
            }
            else
            {
              for (int i = 0; i < RARRAY_LEN($input); i++)
              {
                int item = NUM2INT(rb_ary_entry($input,i));
                tmp.Add(item);
              }
              $1 = &tmp;
            }
            __CODE
          map_out code: <<~__CODE
            $result = rb_ary_new();
            for (size_t i = 0; i < $1.GetCount(); i++)
            {
              rb_ary_push($result,INT2NUM( $1.Item(i) ) );
            }
            __CODE
          map_typecheck precedence: 'INT32_ARRAY', code: '$1 = (TYPE($input) == T_ARRAY);'
        end

        map 'wxArrayInt&' => 'Array<Integer>' do
          map_in temp: 'wxArrayInt tmp', code: <<~__CODE
            if (($input == Qnil) || (TYPE($input) != T_ARRAY))
            {
              $1 = &tmp;
            }
            else
            {
              for (int i = 0; i < RARRAY_LEN($input); i++)
              {
                int item = NUM2INT(rb_ary_entry($input,i));
                tmp.Add(item);
              }
              $1 = &tmp;
            }
            __CODE
          map_out code: <<~__CODE
            $result = rb_ary_new();
            for (size_t i = 0; i < $1->GetCount(); i++)
            {
              rb_ary_push($result,INT2NUM( $1->Item(i) ) );
            }
            __CODE
          map_typecheck precedence: 'INT32_ARRAY', code: '$1 = (TYPE($input) == T_ARRAY);'
        end

        # various enumerator type mappings

        map *%w[wxEdge wxRelationship wxKeyCode], as: 'Integer' do
          map_in code: '$1 = ($1_type)NUM2INT($input);'
          map_out code: '$result = INT2NUM((int)$1);'
          map_typecheck precedence: 'INT32', code: '$1 = TYPE($input) == T_FIXNUM;'
        end

        # integer OUTPUT mappings

        map_apply 'int *OUTPUT' => ['int * x', 'int * y', 'int * w', 'int * h', 'int * descent', 'int * externalLeading']
        map_apply 'int *OUTPUT' => ['wxCoord * width', 'wxCoord * height', 'wxCoord * heightLine',
                                    'wxCoord * w', 'wxCoord * h', 'wxCoord * descent', 'wxCoord * externalLeading']

        # DEPRECATED
        # # special integer combination OUTPUT mappings
        #
        # map 'int * x , int * y , int * descent, int * externalLeading' do
        #   map_directorargout code: <<~__CODE
        #     if((TYPE(result) == T_ARRAY) && ( RARRAY_LEN(result) >= 2 ) )
        #     {
        #       *$1 = ($*1_ltype)NUM2INT(rb_ary_entry(result,0));
        #       *$2 = ($*2_ltype)NUM2INT(rb_ary_entry(result,1));
        #       if(($3 != NULL) && RARRAY_LEN(result) >= 3)
        #         *$3 = ($*3_ltype)NUM2INT(rb_ary_entry(result,2));
        #       if(($4 != NULL) && RARRAY_LEN(result) >= 4)
        #         *$4 = ($*4_ltype)NUM2INT(rb_ary_entry(result,3));
        #     }
        #     __CODE
        # end
        # map 'wxCoord * width , wxCoord * height , wxCoord * heightLine' do
        #   map_directorargout code: <<~__CODE
        #     if((TYPE(result) == T_ARRAY) && ( RARRAY_LEN(result) >= 2) )
        #     {
        #       *$1 = ($*1_ltype)NUM2INT(rb_ary_entry(result,0));
        #       *$2 = ($*2_ltype)NUM2INT(rb_ary_entry(result,1));
        #       if(($3 != NULL) && RARRAY_LEN(result) >= 3)
        #         *$3 = ($*3_ltype)NUM2INT(rb_ary_entry(result,2));
        #     }
        #     __CODE
        # end
        # map 'wxCoord * w , wxCoord * h , wxCoord * descent, wxCoord * externalLeading' do
        #   map_directorargout code: <<~__CODE
        #     if((TYPE(result) == T_ARRAY) && ( RARRAY_LEN(result) >= 2 ) )
        #     {
        #       *$1 = ($*1_ltype)NUM2INT(rb_ary_entry(result,0));
        #       *$2 = ($*2_ltype)NUM2INT(rb_ary_entry(result,1));
        #       if(($3 != NULL) && RARRAY_LEN(result) >= 3)
        #         *$3 = ($*3_ltype)NUM2INT(rb_ary_entry(result,2));
        #       if(($4 != NULL) && RARRAY_LEN(result) >= 4)
        #         *$4 = ($*4_ltype)NUM2INT(rb_ary_entry(result,3));
        #     }
        #     __CODE
        # end

        # Window check type mapping

        map 'wxWindow* parent' => 'Wx::Window' do
          # This typemap catches the first argument of all constructors and
          # Create() methods for Wx::Window classes. These should not be called
          # before App::main_loop is started, and, except for TopLevelWindows,
          # the parent argument must not be NULL.
          map_check code: <<~__CODE
            if ( ! rb_const_defined(wxRuby_Core(), rb_intern("THE_APP") ) )
            { 
              rb_raise(rb_eRuntimeError,
                       "Cannot create a Window before App.main_loop has been called");
            }
            if ( ! $1 && ! rb_obj_is_kind_of(self, wxRuby_GetTopLevelWindowClass()) )
            { 
              rb_raise(rb_eArgError,
                       "Window parent argument must not be nil");
            }
            __CODE
        end

        # window/sizer object wrapping

        map 'wxWindow*' => 'Wx::Window', 'wxSizer*' => 'Wx::Sizer' do
          map_out code: '$result = wxRuby_WrapWxObjectInRuby($1);'
        end


        # Validators must be cast to correct subclass, but internal validator
        # is a clone, and should not be freed, so disown after wrapping.
        map 'wxValidator*' => 'Wx::Validator' do
          map_out code: <<~__CODE
            $result = wxRuby_WrapWxObjectInRuby($1);
            RDATA($result)->dfree = SWIG_RubyRemoveTracking;
            __CODE
        end

        # For ProcessEvent and AddPendingEvent and wxApp::FilterEvent

        map 'wxEvent &event' => 'Wx::Event' do
          map_directorin code: <<~__CODE
            #ifdef __WXRB_TRACE__
            $input = wxRuby_WrapWxEventInRuby(this, const_cast<wxEvent*> (&$1));
            #else
            $input = wxRuby_WrapWxEventInRuby(const_cast<wxEvent*> (&$1));
            #endif
            __CODE

          # Thin and trusting wrapping to bypass SWIG's normal mechanisms; we
          # don't want SWIG changing ownership or typechecking these.
          map_in code: '$1 = (wxEvent*)DATA_PTR($input);'
        end

        # For wxWindow::DoUpdateUIEvent

        map 'wxUpdateUIEvent &' => 'Wx::UpdateUIEvent' do
          map_directorin code: <<~__CODE
            #ifdef __WXRB_TRACE__
            $input = wxRuby_WrapWxEventInRuby(this, static_cast<wxEvent*> (&$1));
            #else
            $input = wxRuby_WrapWxEventInRuby(static_cast<wxEvent*> (&$1));
            #endif
            __CODE
        end

        # For wxControl::Command

        map 'wxCommandEvent &' => 'Wx::CommandEvent' do
          map_directorin code: <<~__CODE
            #ifdef __WXRB_TRACE__
            $input = wxRuby_WrapWxEventInRuby(this, static_cast<wxEvent*> (&$1));
            #else
            $input = wxRuby_WrapWxEventInRuby(static_cast<wxEvent*> (&$1));
            #endif
            __CODE
        end

      end # define

    end # Common

  end # Typemap

end # WXRuby3