###
# wxRuby3 Common typemap definitions
# Copyright (c) M.J.N. Corino, The Netherlands
###

require_relative '../core/mapping'

module WXRuby3

  module Typemap

    # These typemaps create lists of wxPoints from ruby arrays. They are
    # used by DC in methods like draw_lines, draw_polygon etc
    module PointsList

      include Typemap::Module

      define do

        map 'int n, wxPoint points[]' do

          # Helper function to convert an array of Wx::Points or two-integer
          # ruby arrays (as a terser representation of a Point) into a C++
          # array. The C++ array should be already created with the correct
          # length
          add_header_code <<~__CODE
            static void wxRuby_PointArrayRubyToC(VALUE rb_arr, wxPoint wx_arr[]) 
            {
              wxPoint *wx_point;
              VALUE rb_item;
              for (int i = 0; i < RARRAY_LEN(rb_arr); i++)
              {
                rb_item = rb_ary_entry (rb_arr, i);
                if (TYPE(rb_item) == T_DATA)
                {
                    SWIG_ConvertPtr (rb_item, (void **) &wx_point,
                                     SWIGTYPE_p_wxPoint, 1);
                }
                else if (TYPE(rb_item) == T_ARRAY && RARRAY_LEN(rb_item) == 2)
                {
                  wx_point = new wxPoint (NUM2INT( rb_ary_entry(rb_item, 0)),
                    NUM2INT(rb_ary_entry (rb_item, 1)));
                  // Create a ruby object so the C++ obj is freed when GC runs
                  SWIG_NewPointerObj (wx_point, SWIGTYPE_p_wxPoint, 1);
                }
                else
                {
                  rb_raise(rb_eTypeError, "Wrong type for wxPoint parameter %i", i);
                }
                wx_arr[i] = *wx_point;
              }
            }
            __CODE

          # Set of typemaps for draw_lines, draw_polygon etc
          map_in from: {type: 'Array<Wx::Point>,Array<Array<Integer>>', index: 1},
                 temp: 'wxPoint *arr', code: <<~__CODE
            if ( ($input == Qnil) || (TYPE($input) != T_ARRAY) )
            {
              $1 = 0;
              $2 = NULL;
            }
            else
            {
              $1 = RARRAY_LEN($input);
              arr = new wxPoint[ RARRAY_LEN($input)];
              wxRuby_PointArrayRubyToC($input, arr);
              $2 = arr;
            }
           __CODE

         map_default code: '$1 = 0; $2 = NULL;'

         map_freearg code: 'if ($2 != NULL) delete [] $2;'

         map_typecheck code: '$1 = (TYPE($input) == T_ARRAY);'

        end

        map_apply 'int n, wxPoint points[]' => [ 'int n, wxPoint* points', 'int nItems, wxPoint *points' ]

        # For draw_poly_polygon only
        map 'int n, int count[], wxPoint points[]' do

          map_in from: {type: 'Array<Array<Wx::Point>>,Array<Array<Array<Integer>>>', index: 2},
                 temp: 'wxPoint *point_arr', code: <<~__CODE
            if ( ($input == Qnil) || (TYPE($input) != T_ARRAY) )
            {
              $1 = 0;
              $2 = NULL;
              $3 = NULL;
            }
            else
            {
              // total number of polygons
              $1 = RARRAY_LEN($input);
              $2 = (int*)malloc($1 * sizeof(int));
              // number of points in each polygon
              for ( int i = 0; i < RARRAY_LEN($input); i++ )
                $2[i] = RARRAY_LEN( rb_ary_entry($input, i) );
              // array of all the points
              VALUE all_points = rb_funcall($input, rb_intern("flatten"), 0);
              point_arr = new wxPoint[ RARRAY_LEN(all_points) ];
              wxRuby_PointArrayRubyToC(all_points, point_arr);
              $3 = point_arr;
            }
            __CODE

          map_default code: <<~__CODE
            $1 = 0;
            $2 = NULL;
            $3 = NULL;
            __CODE

          map_freearg code: <<~__CODE
            if ($2 != NULL) delete [] $2;
            if ($3 != NULL) delete [] $3;
            __CODE

          map_typecheck code: '$1 = (TYPE($input) == T_ARRAY);'

        end

      end # define

    end # PointsList

  end # Typemap

end # WXRuby3
