#include "moonbit.h"
#include <errno.h>
#include <limits.h>
#include <pwd.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>
#if defined(__APPLE__)
#include <mach-o/dyld.h>
#endif

MOONBIT_FFI_EXPORT
const char *
moonbit_moonstat_os_getenv(moonbit_bytes_t key) {
  return getenv((const char *)key);
}

MOONBIT_FFI_EXPORT
int32_t
moonbit_moonstat_os_setenv(
  moonbit_bytes_t key,
  moonbit_bytes_t value,
  int overwrite
) {
  if (setenv((const char *)key, (const char *)value, overwrite) != 0) {
    return errno;
  } else {
    return 0;
  }
}

MOONBIT_FFI_EXPORT
int
moonbit_moonstat_os_unsetenv(moonbit_bytes_t key) {
  return unsetenv((const char *)key);
}

MOONBIT_FFI_EXPORT
uint32_t
moonbit_moonstat_os_getuid() {
  return (uint32_t)getuid();
}

MOONBIT_FFI_EXPORT
int32_t
moonbit_moonstat_os_getpwuid_r(
  uint32_t uid,
  moonbit_bytes_t pwd,
  char *buf,
  uint64_t buf_len,
  void **result
) {
  return getpwuid_r(
    uid, (struct passwd *)pwd, (char *)buf, buf_len, (struct passwd **)result
  );
}

MOONBIT_FFI_EXPORT
int32_t
moonbit_moonstat_os_passwd_sizeof() {
  return sizeof(struct passwd);
}

MOONBIT_FFI_EXPORT
int32_t
moonbit_moonstat_sysconf_SC_GETPW_R_SIZE_MAX() {
  return (int32_t)sysconf(_SC_GETPW_R_SIZE_MAX);
}

MOONBIT_FFI_EXPORT
char *
moonbit_moonstat_os_passwd_get_dir(moonbit_bytes_t pwd) {
  struct passwd *p = (struct passwd *)pwd;
  return p->pw_dir;
}

MOONBIT_FFI_EXPORT
int64_t
moonbit_moonstat_sysconf_SC_HOST_NAME_MAX(void) {
  return (int64_t)sysconf(_SC_HOST_NAME_MAX);
}

MOONBIT_FFI_EXPORT
int32_t
moonbit_moonstat_os_gethostname(moonbit_bytes_t name) {
  errno = 0;
  if (gethostname((char *)name, Moonbit_array_length(name)) == -1) {
    return errno;
  }
  return 0;
}

MOONBIT_FFI_EXPORT
int32_t
moonbit_moonstat_os_chdir(moonbit_bytes_t path) {
  int result = chdir((const char *)path);
  if (result != 0) {
    return errno;
  } else {
    return 0;
  }
}

MOONBIT_FFI_EXPORT
void
moonbit_moonstat_os_exit(int32_t code) {
  exit(code);
}

MOONBIT_FFI_EXPORT
int64_t
moonbit_moonstat_os_unix_seconds(void) {
  struct timeval tv;
  if (gettimeofday(&tv, NULL) != 0) {
    return 0;
  }
  return (int64_t)tv.tv_sec;
}

static moonbit_bytes_t
moonbit_moonstat_os_bytes_from_cstr(const char *str) {
  int32_t len = (int32_t)strlen(str);
  moonbit_bytes_t bytes = moonbit_make_bytes(len, 0);
  memcpy(bytes, str, len);
  return bytes;
}

static int
moonbit_moonstat_os_local_tm(int64_t timestamp, struct tm *tm) {
  time_t raw = (time_t)timestamp;
  tzset();
  return localtime_r(&raw, tm) != NULL;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t
moonbit_moonstat_os_local_rfc3339(int64_t timestamp) {
  struct tm tm;
  char compact[40];
  char formatted[48];
  if (!moonbit_moonstat_os_local_tm(timestamp, &tm) ||
      strftime(compact, sizeof(compact), "%Y-%m-%dT%H:%M:%S%z", &tm) == 0) {
    snprintf(formatted, sizeof(formatted), "%lld", (long long)timestamp);
    return moonbit_moonstat_os_bytes_from_cstr(formatted);
  }
  size_t len = strlen(compact);
  if (len >= 5 &&
      (compact[len - 5] == '+' || compact[len - 5] == '-')) {
    size_t prefix = len - 5;
    snprintf(
      formatted,
      sizeof(formatted),
      "%.*s%c%c%c:%c%c",
      (int)prefix,
      compact,
      compact[prefix],
      compact[prefix + 1],
      compact[prefix + 2],
      compact[prefix + 3],
      compact[prefix + 4]
    );
    return moonbit_moonstat_os_bytes_from_cstr(formatted);
  }
  return moonbit_moonstat_os_bytes_from_cstr(compact);
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t
moonbit_moonstat_os_local_date_key(int64_t timestamp) {
  struct tm tm;
  char formatted[16];
  if (!moonbit_moonstat_os_local_tm(timestamp, &tm) ||
      strftime(formatted, sizeof(formatted), "%Y-%m-%d", &tm) == 0) {
    snprintf(formatted, sizeof(formatted), "1970-01-01");
  }
  return moonbit_moonstat_os_bytes_from_cstr(formatted);
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t
moonbit_moonstat_os_local_month_key(int64_t timestamp) {
  struct tm tm;
  char formatted[16];
  if (!moonbit_moonstat_os_local_tm(timestamp, &tm) ||
      strftime(formatted, sizeof(formatted), "%Y-%m", &tm) == 0) {
    snprintf(formatted, sizeof(formatted), "1970-01");
  }
  return moonbit_moonstat_os_bytes_from_cstr(formatted);
}

MOONBIT_FFI_EXPORT
int64_t
moonbit_moonstat_os_local_day_start_seconds(int64_t timestamp) {
  struct tm tm;
  if (!moonbit_moonstat_os_local_tm(timestamp, &tm)) {
    return timestamp;
  }
  tm.tm_hour = 0;
  tm.tm_min = 0;
  tm.tm_sec = 0;
  tm.tm_isdst = -1;
  return (int64_t)mktime(&tm);
}

MOONBIT_FFI_EXPORT
int64_t
moonbit_moonstat_os_local_next_day_start_seconds(int64_t timestamp) {
  struct tm tm;
  if (!moonbit_moonstat_os_local_tm(timestamp, &tm)) {
    return timestamp + 86400;
  }
  tm.tm_mday += 1;
  tm.tm_hour = 0;
  tm.tm_min = 0;
  tm.tm_sec = 0;
  tm.tm_isdst = -1;
  return (int64_t)mktime(&tm);
}

MOONBIT_FFI_EXPORT
int32_t
moonbit_moonstat_os_executable(moonbit_bytes_t buf) {
#if defined(__APPLE__)
  uint32_t bufsize = Moonbit_array_length(buf);
  int rc = _NSGetExecutablePath((char *)buf, &bufsize);
  if (rc == -1) {
    return bufsize;
  } else {
    return strlen((char *)buf);
  }
#elif defined(__linux__)
  size_t bufsize = Moonbit_array_length(buf);
  ssize_t len = readlink("/proc/self/exe", (char *)buf, bufsize);
  if (len == bufsize) {
    return bufsize * 2;
  } else {
    return len;
  }
#endif
}
