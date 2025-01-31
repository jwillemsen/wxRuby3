###
# wxRuby3 wxWidgets interface director
# Copyright (c) M.J.N. Corino, The Netherlands
###

require_relative './window'

module WXRuby3

  class Director

    class StyledTextCtrl < Window

      def setup
        super
        spec.override_inheritance_chain('wxStyledTextCtrl', %w[wxControl wxWindow wxEvtHandler wxObject])
        spec.map 'int *', 'long *', as: 'Integer' do
          map_in ignore: true, temp: '$*1_ltype a', code: '$1 = &a;'
          map_argout code: <<~__CODE
            if (NIL_P($result)) $result = INT2NUM(*$1);
            else 
            {
              if (TYPE($result) != T_ARRAY)
              {
                VALUE rc = rb_ary_new();
                rb_ary_push(rc, $result);
                $result = rc;
              }
              rb_ary_push($result, INT2NUM(*$1));
            }
            __CODE
        end
        spec.map 'long *, long *', 'wxTextCoord *col, wxTextCoord *row', as: 'Array(Integer, Integer)' do
          map_in ignore: true, temp: '$*1_ltype a, $*2_ltype b', code: '$1 = &a; $2 = &b;'
          map_argout code: <<~__CODE
            if (TYPE($result) != T_ARRAY)
            {
              VALUE rc = rb_ary_new();
              if (!NIL_P($result)) rb_ary_push(rc, $result);
              $result = rc;
            }
            rb_ary_push($result, INT2NUM(*$1));
            rb_ary_push($result, INT2NUM(*$2));
          __CODE
        end
        # not useful in wxRuby
        spec.ignore 'wxStyledTextCtrl::HitTest(const wxPoint &, long *) const',
                    'wxStyledTextCtrl::GetDirectFunction',
                    'wxStyledTextCtrl::GetDirectPointer',
                    'wxStyledTextCtrl::CreateLoader',
                    'wxStyledTextCtrl::AddTextRaw',
                    'wxStyledTextCtrl::InsertTextRaw',
                    'wxStyledTextCtrl::GetCurLineRaw',
                    'wxStyledTextCtrl::GetLineRaw',
                    'wxStyledTextCtrl::GetSelectedTextRaw',
                    'wxStyledTextCtrl::GetTargetTextRaw',
                    'wxStyledTextCtrl::GetTextRangeRaw',
                    'wxStyledTextCtrl::SetTextRaw',
                    'wxStyledTextCtrl::GetTextRaw',
                    'wxStyledTextCtrl::AppendTextRaw',
                    'wxStyledTextCtrl::ReplaceSelectionRaw',
                    'wxStyledTextCtrl::ReplaceTargetRaw',
                    'wxStyledTextCtrl::ReplaceTargetRERaw',
                    'wxStyledTextCtrl::SetStyleBytes',
                    'wxStyledTextCtrl::RegisterImage(int, const char *const *)'
        # TODO : these need investigating to see if they might be useful
        spec.ignore 'wxStyledTextCtrl::GetDocPointer',
                    'wxStyledTextCtrl::SetDocPointer',
                    'wxStyledTextCtrl::CreateDocument',
                    'wxStyledTextCtrl::AddRefDocument',
                    'wxStyledTextCtrl::ReleaseDocument',
                    'wxStyledTextCtrl::PrivateLexerCall'
        # TODO : these will need some sort of stream solution to be useful
        spec.ignore 'wxStyledTextCtrl::GetCharacterPointer',
                    'wxStyledTextCtrl::GetRangePointer'
        spec.do_not_generate(:variables, :enums, :defines, :functions)
      end
    end # class StyledTextCtrl

  end # class Director

end # module WXRuby3
