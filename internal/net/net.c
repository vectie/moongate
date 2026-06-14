#include "moonbit.h"
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <string.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <unistd.h>
#include <netinet/in.h>
#include <arpa/inet.h>

MOONBIT_FFI_EXPORT
int32_t
moonbit_moonstat_net_tcp_localhost_port_open(int32_t port, int32_t timeout_ms) {
  if (port <= 0 || port > 65535) {
    return 0;
  }
  if (timeout_ms < 0) {
    timeout_ms = 0;
  }

  int fd = socket(AF_INET, SOCK_STREAM, 0);
  if (fd < 0) {
    return 0;
  }

  int flags = fcntl(fd, F_GETFL, 0);
  if (flags < 0 || fcntl(fd, F_SETFL, flags | O_NONBLOCK) < 0) {
    close(fd);
    return 0;
  }

  struct sockaddr_in addr;
  memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_port = htons((uint16_t)port);
  addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);

  int rc = connect(fd, (struct sockaddr *)&addr, sizeof(addr));
  if (rc == 0) {
    close(fd);
    return 1;
  }
  if (errno != EINPROGRESS) {
    close(fd);
    return 0;
  }

  fd_set writefds;
  FD_ZERO(&writefds);
  FD_SET(fd, &writefds);

  struct timeval tv;
  tv.tv_sec = timeout_ms / 1000;
  tv.tv_usec = (timeout_ms % 1000) * 1000;

  rc = select(fd + 1, NULL, &writefds, NULL, &tv);
  if (rc <= 0) {
    close(fd);
    return 0;
  }

  int err = 0;
  socklen_t len = sizeof(err);
  if (getsockopt(fd, SOL_SOCKET, SO_ERROR, &err, &len) < 0) {
    close(fd);
    return 0;
  }

  close(fd);
  return err == 0 ? 1 : 0;
}
