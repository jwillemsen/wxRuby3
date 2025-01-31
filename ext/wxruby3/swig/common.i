/* wxRuby3
 * Copyright (c) Martin J.N. Corino
 */
// Copyright 2004-2007, wxRuby development team
// released under the MIT-like wxRuby2 license

%feature("director");
%feature("compactdefaultargs");
%feature("flatnested");

%begin %{
/*
 * Since SWIG does not provide readily usable export macros
 * and we need them here already before we can rely on the ones from
 * wxWidgets we define our own.
 */

#ifndef WXRB_EXPORT_FLAG
# if defined(_WIN32) || defined(__WIN32__) || defined(__CYGWIN__)
#   if defined(WXRUBY_STATIC_BUILD)
#     define WXRB_EXPORT_FLAG
#   else
#     define WXRB_EXPORT_FLAG __declspec(dllexport)
#   endif
# else
#   if defined(__GNUC__) && defined(GCC_HASCLASSVISIBILITY)
#     define WXRB_EXPORT_FLAG __attribute__ ((visibility("default")))
#   else
#     define WXRB_EXPORT_FLAG
#   endif
# endif
#endif

#ifndef WXRB_IMPORT_FLAG
# if defined(_WIN32) || defined(__WIN32__) || defined(__CYGWIN__)
#   if defined(WXRUBY_STATIC_BUILD)
#     define WXRB_IMPORT_FLAG
#   else
#     define WXRB_IMPORT_FLAG __declspec(dllimport)
#   endif
# else
#   if defined(__GNUC__) && defined(GCC_HASCLASSVISIBILITY)
#     define WXRB_IMPORT_FLAG __attribute__ ((visibility("default")))
#   else
#     define WXRB_IMPORT_FLAG
#   endif
# endif
#endif

#ifdef BUILD_WXRUBY_CORE
 	#define WXRUBY_EXPORT WXRB_EXPORT_FLAG
#else
 	#define WXRUBY_EXPORT WXRB_IMPORT_FLAG
#endif

%}

%runtime %{
// # SWIG 1.3.29 added this new feature which we can't use (yet)
#define SWIG_DIRECTOR_NOUEH TRUE

// Customize SWIG contract assertion
#if defined(SWIG_contract_assert)
#undef SWIG_contract_assert
#endif
#define SWIG_contract_assert(expr, msg) if (!(expr)) { SWIG_Error(SWIG_RuntimeError, msg); SWIG_fail; }

#  undef GetClassName
#  undef GetClassInfo
#  undef Yield
#  undef GetMessage
#  undef FindWindow
#  undef GetCharWidth
#  undef DrawText
#  undef StartDoc
#  undef CreateDialog
#  undef Sleep
#  undef Connect
#  undef connect

// flag type to keep track of stuff like typemap arg allocations that need to be freed in freearg typemaps
// by default always 'false'
struct wxrb_flag
{
  bool flag_ {};
  wxrb_flag() = default;
  wxrb_flag(const wxrb_flag&) = default;
  wxrb_flag(wxrb_flag&&) = default;
  operator bool () const { return flag_; }
  bool operator! () const { return !flag_; }
  wxrb_flag& operator =(const wxrb_flag&) = default;
  wxrb_flag& operator =(wxrb_flag&&) = default;
  wxrb_flag& operator =(bool f) { flag_ = f; return *this; }
};

// Different string conversions for ruby 2.5+

#define WXSTR_TO_RSTR(wx_str) rb_utf8_str_new_cstr((const char *)wx_str.utf8_str())
#define WXSTR_PTR_TO_RSTR(wx_str) (wx_str ? rb_utf8_str_new_cstr((const char *)wx_str->utf8_str()) : Qnil)

#define RSTR_TO_WXSTR(rstr) (rstr == Qnil ? wxString() : wxString(StringValuePtr(rstr), wxConvUTF8))
#define RSTR_TO_WXSTR_PTR(rstr) (rstr == Qnil ? 0 : new wxString(StringValuePtr(rstr), wxConvUTF8))

// problematic Wx definition of _ macro conflicts with SWIG
#define WXINTL_NO_GETTEXT_MACRO 1

// appears in both ruby headers and wx headers, avoid warning on MSW
#ifdef __WXMSW__
#undef HAVE_FSYNC
#endif

#include <wx/wx.h>
#include <wx/dcbuffer.h>
#if wxUSE_VARIANT
#include <wx/variant.h>
#endif

#if ! wxCHECK_VERSION(3,1,5)
#error "This version of wxRuby requires WxWidgets 3.1.5 or greater"
#endif

#ifdef __WXRB_DEBUG__
WXRUBY_EXPORT int wxRuby_TraceLevel();
#endif

WXRUBY_EXPORT VALUE wxRuby_Funcall(VALUE rcvr, ID func, int argc, ...);

WXRUBY_EXPORT bool wxRuby_IsAppRunning();
typedef void (*WXRBMarkFunction)();
WXRUBY_EXPORT void wxRuby_AppendMarker(WXRBMarkFunction marker);

WXRUBY_EXPORT VALUE wxRuby_GetTopLevelWindowClass(); // used for wxWindow typemap in typemap.i
WXRUBY_EXPORT bool GC_IsWindowDeleted(void *ptr);

// Defined in wx.i; getting, setting and using swig_type <-> ruby class
// mappings
WXRUBY_EXPORT swig_type_info* wxRuby_GetSwigTypeForClass(VALUE cls);
WXRUBY_EXPORT void wxRuby_SetSwigTypeForClass(VALUE cls, swig_type_info* ty);

// Common wrapping functions
WXRUBY_EXPORT VALUE wxRuby_WrapWxObjectInRuby(wxObject* obj);
#ifdef __WXRB_DEBUG__
WXRUBY_EXPORT VALUE wxRuby_WrapWxEventInRuby(void* rcvr, wxEvent* event);
#else
WXRUBY_EXPORT VALUE wxRuby_WrapWxEventInRuby(wxEvent* event);
#endif

// event handling helpers
WXRUBY_EXPORT VALUE wxRuby_GetEventTypeClassMap();
WXRUBY_EXPORT VALUE wxRuby_GetDefaultEventClass ();
WXRUBY_EXPORT void wxRuby_ReleaseEvtHandlerProcs(void* evt_handler);

WXRUBY_EXPORT bool wxRuby_IsNativeMethod(VALUE object, ID method_id);

WXRUBY_EXPORT VALUE wxRuby_GetWindowClass();
WXRUBY_EXPORT VALUE wxRuby_GetDialogClass();

// Enum helpers
WXRUBY_EXPORT VALUE wxRuby_GetEnumClass(const char* enum_class_name_cstr);
WXRUBY_EXPORT VALUE wxRuby_CreateEnumClass(const char* enum_class_name_cstr);
WXRUBY_EXPORT VALUE wxRuby_AddEnumValue(VALUE enum_klass, const char* enum_value_name_cstr, VALUE enum_value_num);
WXRUBY_EXPORT VALUE wxRuby_GetEnumValueObject(const char* enum_wx_class_name_cstr, int enum_val);
WXRUBY_EXPORT bool wxRuby_GetEnumValue(const char* enum_class_name_cstr, VALUE rb_enum_val, int &c_eval);
WXRUBY_EXPORT bool wxRuby_IsAnEnum(VALUE rb_val);
WXRUBY_EXPORT bool wxRuby_IsEnumValue(const char* enum_wx_class_name_cstr, VALUE rb_enum_val);

#if wxUSE_VARIANT
// Variant support
WXRUBY_EXPORT VALUE& operator << (VALUE &value, const wxVariant &variant);
WXRUBY_EXPORT wxVariant& operator << (wxVariant &variant, const VALUE &value);
WXRUBY_EXPORT wxVariant wxRuby_ConvertRbValue2Variant(VALUE rbval);
#endif
%}

%include "typedefs.i"
%include "memory_management.i"
