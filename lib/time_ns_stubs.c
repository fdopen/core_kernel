#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <caml/mlvalues.h>

#include <caml/memory.h>
#include <caml/alloc.h>
#include <caml/custom.h>
#include <caml/fail.h>
#include <caml/signals.h>
#include <caml/unixsupport.h>

#include <time.h>
#include <stdint.h>

#include "ocaml_utils.h"
#include "config.h"

#include "timespec.h"

#define NANOS_PER_SECOND 1000000000

#ifdef JSC_ARCH_SIXTYFOUR
#  define caml_alloc_int63(v) Val_long(v)
#  define Int63_val(v) Long_val(v)
#else
#  define caml_alloc_int63(v) caml_copy_int64(v)
#  define Int63_val(v) Int64_val(v)
#endif


#if defined(JSC_POSIX_TIMERS)

/* Note: this is imported noalloc if (and only if) ARCH_SIXTYFOUR is defined.
 * This is OK because caml_alloc_int63 doesn't actually allocate in that case. */
CAMLprim value core_kernel_time_ns_gettime_or_zero()
{
  struct timespec ts;

  if (clock_gettime(CLOCK_REALTIME, &ts) != 0)
    return caml_alloc_int63(0);
  else
    return caml_alloc_int63(NANOS_PER_SECOND * (uint64_t)ts.tv_sec + (uint64_t)ts.tv_nsec);
}

#else

#include <sys/types.h>
#include <sys/time.h>

CAMLprim value core_kernel_time_ns_gettime_or_zero()
{
  struct timeval tp;
  if (gettimeofday(&tp, NULL) == -1)
    return caml_alloc_int63(0);
  else
    return caml_alloc_int63(NANOS_PER_SECOND * (uint64_t)tp.tv_sec + (uint64_t)tp.tv_usec * 1000);
}

#endif


CAMLprim value core_kernel_time_ns_strftime(value v_tm, value v_fmt)
{
  struct tm tm;
  size_t len;
  char* buf;
  int buf_len;
  value v_str;

  buf_len = 128*1024 + caml_string_length(v_fmt);
  buf = malloc(buf_len);
  if (!buf) caml_failwith("unix_strftime: malloc failed");

  tm.tm_sec  = Int_val(Field(v_tm, 0));
  tm.tm_min  = Int_val(Field(v_tm, 1));
  tm.tm_hour = Int_val(Field(v_tm, 2));
  tm.tm_mday = Int_val(Field(v_tm, 3));
  tm.tm_mon  = Int_val(Field(v_tm, 4));
  tm.tm_year = Int_val(Field(v_tm, 5));
  tm.tm_wday = Int_val(Field(v_tm, 6));
  tm.tm_yday = Int_val(Field(v_tm, 7));
  tm.tm_isdst = Bool_val(Field(v_tm, 8));
#ifdef __USE_BSD
  tm.tm_gmtoff = 0;  /* GNU extension, may not be visible everywhere */
  tm.tm_zone = NULL; /* GNU extension, may not be visible everywhere */
#endif

  len = strftime(buf, buf_len, String_val(v_fmt), &tm);

  if (len == 0) {
    /* From the man page:
         "Note that the return value 0 does not necessarily indicate an error;
          for example, in many locales %p yields an empty string."
       Given how large our buffer is we just assume that 0 always indicates
       an empty string. */
    v_str = caml_copy_string("");
    free(buf);
    return v_str;
  }

  v_str = caml_copy_string(buf);  /* [strftime] always null terminates the string */
  free(buf);
  return v_str;
}

CAMLprim value core_kernel_time_ns_nanosleep(value v_seconds)
{
  struct timespec req = timespec_of_double(Double_val(v_seconds));
  struct timespec rem;
  int retval;

  caml_enter_blocking_section();
  retval = nanosleep(&req, &rem);
  caml_leave_blocking_section();

  if (retval == 0)
    return caml_copy_double(0.0);
  else if (retval == -1) {
    if (errno == EINTR)
      return caml_copy_double(timespec_to_double(rem));
    else
      uerror("nanosleep", Nothing);
  }
  else
    caml_failwith("core_kernel_time_ns_nanosleep: impossible return value from nanosleep(2)");
}
