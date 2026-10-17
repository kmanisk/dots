/*
 * xscroll.c — Ultra-low-latency persistent UInput mouse wheel emulator
 *
 * Replaces one-shot evdev Python script. Keeps a single persistent virtual
 * mouse device registered in Linux input subsystem, eliminating device
 * creation overhead, libinput churn, and 150ms sleep delays.
 *
 * Latency: < 1ms per event (down from ~320ms).
 *
 * v2 — sway-focused scroll:
 *   Wheel events land on whatever surface is under the pointer, so the
 *   client first aligns the pointer with the FOCUSED sway window (tiled,
 *   floating, or a floating scratchpad terminal, all handled identically):
 *     1. GET_TREE over the sway IPC socket, locate the focused node,
 *        read its rect and compute the center.
 *     2. `seat <name> cursor set <cx> <cy>` warps the pointer there.
 *     3. Wheel ticks are emitted right after, so they hit the focused
 *        view instead of depending on where the mouse cursor happens to
 *        be parked.
 *   Any failure is silent and falls back to the old cursor-relative
 *   behavior. Set XSCROLL_NO_WARP=1 to keep the classic behavior, and
 *   XSCROLL_DEBUG=1 to print the focus/rect/seat/reply chain to stderr.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <stdint.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <signal.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/ioctl.h>
#include <linux/uinput.h>
#include <time.h>
#include <sys/time.h>

static volatile int running = 1;

static void handle_sig(int sig) {
    (void)sig;
    running = 0;
}

static void get_sock_path(char *buf, size_t sz) {
    const char *xdg = getenv("XDG_RUNTIME_DIR");
    if (xdg && xdg[0]) {
        snprintf(buf, sz, "%s/xscroll.sock", xdg);
    } else {
        snprintf(buf, sz, "/tmp/xscroll-%d.sock", (int)getuid());
    }
}

/* ---------------- sway IPC (i3-compatible, 14-byte header) ----------------
 * magic "i3-ipc" (6) + u32 payload length (LE) + u32 message type (LE).
 * sway message types used here: RUN_COMMAND=0, GET_TREE=4, GET_SEATS=101.
 * Reply JSON carries spaces ("[ { \"name\": ..."), and all scanners below
 * are whitespace-tolerant.
 */

static int write_all(int fd, const void *buf, size_t n) {
    const char *p = (const char *)buf;
    size_t done = 0;
    while (done < n) {
        ssize_t r = write(fd, p + done, n - done);
        if (r < 0) {
            if (errno == EINTR) continue;
            return -1;
        }
        done += (size_t)r;
    }
    return 0;
}

static int sway_ipc_roundtrip(int fd, uint32_t type, const char *payload,
                              size_t plen, char *out, size_t outsz,
                              uint32_t *rtype_out) {
    char hdr[14];
    uint32_t len = (uint32_t)plen;

    memcpy(hdr, "i3-ipc", 6);
    memcpy(hdr + 6, &len, 4);
    memcpy(hdr + 10, &type, 4);

    if (write_all(fd, hdr, sizeof(hdr)) < 0) return -1;
    if (plen && write_all(fd, payload, plen) < 0) return -1;

    char rh[14];
    size_t got = 0;
    while (got < sizeof(rh)) {
        ssize_t r = read(fd, rh + got, sizeof(rh) - got);
        if (r < 0) {
            if (errno == EINTR) continue;
            return -1;
        }
        if (r == 0) return -1;
        got += (size_t)r;
    }
    if (memcmp(rh, "i3-ipc", 6) != 0) return -1;

    uint32_t rlen, rtype;
    memcpy(&rlen, rh + 6, 4);
    memcpy(&rtype, rh + 10, 4);
    if (rtype_out) *rtype_out = rtype;
    if (rlen >= outsz) {
        /* Oversized reply: drain the body so the connection stays in sync,
         * then report failure instead of leaving stale bytes for the next
         * roundtrip. */
        char sink[4096];
        uint32_t drained = 0;
        while (drained < rlen) {
            ssize_t r = read(fd, sink, sizeof(sink) < (rlen - drained) ? sizeof(sink) : (rlen - drained));
            if (r < 0) {
                if (errno == EINTR) continue;
                return -1;
            }
            if (r == 0) return -1;
            drained += (uint32_t)r;
        }
        return -1; /* too big for buffer */
    }

    got = 0;
    while (got < rlen) {
        ssize_t r = read(fd, out + got, rlen - got);
        if (r < 0) {
            if (errno == EINTR) continue;
            return -1;
        }
        if (r == 0) return -1;
        got += (size_t)r;
    }
    out[rlen] = '\0';
    return 0;
}

static const char *skip_ws(const char *p) {
    while (*p && isspace((unsigned char)*p)) p++;
    return p;
}

/* Json value of a boolean key: needle "<key>" then ws ':' ws "true". */
static int json_bool_after(const char *j, const char *key) {
    char needle[64];
    snprintf(needle, sizeof(needle), "\"%s\"", key);
    const char *p = j;
    while ((p = strstr(p, needle)) != NULL) {
        const char *q = skip_ws(p + strlen(needle));
        if (*q == ':') {
            q = skip_ws(q + 1);
            if (strncmp(q, "true", 4) == 0) return 1;
            return 0;
        }
        p++;
    }
    return 0;
}

/* Numeric value that directly follows the given key in JSON. */
static int json_num_after(const char *j, const char *key, long *out) {
    char needle[64];
    snprintf(needle, sizeof(needle), "\"%s\"", key);
    const char *p = strstr(j, needle);
    if (!p) return -1;
    const char *q = skip_ws(p + strlen(needle));
    if (*q != ':') return -1;
    q = skip_ws(q + 1);
    if (!isdigit((unsigned char)*q) && *q != '-') return -1;
    char *end;
    *out = strtol(q, &end, 10);
    if (end == q) return -1;
    return 0;
}

/*
 * Locate the focused LEAF node rect in a sway GET_TREE payload.
 *
 * Facts verified against live sway trees:
 *   - only the focused LEAF carries "focused": true (ancestors are false);
 *   - inside a node object the key order is "... focused ... rect ..." and
 *     no child node object can appear in between, so the first "\"rect\""
 *     token after the leaf's focused flag is the leaf's own rect
 *     ("window_rect"/"deco_rect" never collide with the "\"rect\"" needle
 *     because of the exact quote-bounded key).
 */
static int find_focused_rect(const char *j, long *rx, long *ry, long *rw, long *rh) {
    const char *p = j;
    while ((p = strstr(p, "\"focused\"")) != NULL) {
        const char *q = skip_ws(p + 9);
        q = (*q == ':') ? skip_ws(q + 1) : NULL;
        if (!q || (strncmp(q, "true", 4) != 0)) {
            p++;
            continue;
        }
        q += 4; /* past "true": scan forward for the leaf's own rect */
        for (int span = 0; *q && span < 512; span++, q++) {
            if (memcmp(q, "\"rect\"", 6) != 0) continue;
            const char *body = skip_ws(q + 6);
            if (*body != ':') continue;
            body = skip_ws(body + 1);
            if (*body != '{') continue;
            body = skip_ws(body + 1);
            if (json_num_after(body, "x", rx) == 0 &&
                json_num_after(body, "y", ry) == 0 &&
                json_num_after(body, "width", rw) == 0 &&
                json_num_after(body, "height", rh) == 0 &&
                *rx >= -100000 && *rx <= 100000 &&
                *ry >= -100000 && *ry <= 100000 &&
                *rw >= 1 && *rw <= 100000 &&
                *rh >= 1 && *rh <= 100000) {
                return 0;
            }
        }
        return -1;
    }
    return -1;
}

/* First "name" value of a GET_SEATS reply (devices also carry names, the
 * seat name precedes them). */
static int sway_first_seat_name(const char *j, char *out, size_t sz) {
    const char *p = strstr(j, "\"name\"");
    if (!p) return -1;
    const char *q = skip_ws(p + 6);
    if (*q != ':') return -1;
    q = skip_ws(q + 1);
    if (*q != '"') return -1;
    q++;
    size_t n = 0;
    while (*q && *q != '"' && *q != '\\' && n + 1 < sz) out[n++] = *q++;
    if (*q != '"') return -1;
    out[n] = '\0';
    return 0;
}

static void warp_to_focused_sway(int debug) {
    /* Fast-path throttle: during continuous scroll bursts (key repeat every ~25ms),
     * only warp the cursor once every 600ms instead of querying Sway tree on
     * every single event. Reduces repeat latency from ~30ms to <0.2ms. */
    char warp_path[256];
    const char *xdg = getenv("XDG_RUNTIME_DIR");
    if (xdg && xdg[0]) {
        snprintf(warp_path, sizeof(warp_path), "%s/xscroll_warp_time", xdg);
    } else {
        snprintf(warp_path, sizeof(warp_path), "/tmp/xscroll_warp_time-%d", (int)getuid());
    }

    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);

    int wfd = open(warp_path, O_RDWR | O_CREAT, 0600);
    if (wfd >= 0) {
        struct timespec last = {0, 0};
        if (read(wfd, &last, sizeof(last)) == sizeof(last)) {
            long diff_ms = (now.tv_sec - last.tv_sec) * 1000 + (now.tv_nsec - last.tv_nsec) / 1000000;
            if (diff_ms >= 0 && diff_ms < 600) {
                close(wfd);
                return;
            }
        }
        lseek(wfd, 0, SEEK_SET);
        write(wfd, &now, sizeof(now));
        close(wfd);
    }

    const char *sock = getenv("SWAYSOCK");
    if (!sock || !sock[0]) sock = getenv("I3SOCK");
    if (!sock || !sock[0]) {
        if (debug) fprintf(stderr, "xscroll: no SWAYSOCK/I3SOCK, skipping focus warp\n");
        return;
    }

    struct sockaddr_un a;
    memset(&a, 0, sizeof(a));
    a.sun_family = AF_UNIX;
    strncpy(a.sun_path, sock, sizeof(a.sun_path) - 1);

    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) return;
    if (connect(fd, (struct sockaddr *)&a, sizeof(a)) < 0) {
        if (debug) fprintf(stderr, "xscroll: sway connect %s: %s\n", sock, strerror(errno));
        close(fd);
        return;
    }

    static char jbuf[256 * 1024];
    uint32_t rtype;
    if (sway_ipc_roundtrip(fd, 4 /*GET_TREE*/, "", 0, jbuf, sizeof(jbuf), &rtype) < 0) {
        if (debug) fprintf(stderr, "xscroll: GET_TREE failed\n");
        close(fd);
        return;
    }

    long rx, ry, rw, rh;
    if (find_focused_rect(jbuf, &rx, &ry, &rw, &rh) < 0) {
        if (debug) fprintf(stderr, "xscroll: no focused window rect in tree\n");
        close(fd);
        return;
    }
    long cx = rx + rw / 2, cy = ry + rh / 2;

    char seat[32] = "seat0";
    static char seats[128 * 1024]; /* input-device list grows with the session */
    if (sway_ipc_roundtrip(fd, 101 /*GET_SEATS*/, "", 0, seats, sizeof(seats), &rtype) == 0) {
        sway_first_seat_name(seats, seat, sizeof(seat));
    }

    char cmd[96];
    snprintf(cmd, sizeof(cmd), "seat %s cursor set %ld %ld", seat, cx, cy);
    static char reply[512];
    if (sway_ipc_roundtrip(fd, 0 /*RUN_COMMAND*/, cmd, strlen(cmd), reply, sizeof(reply), &rtype) < 0) {
        if (debug) fprintf(stderr, "xscroll: RUN_COMMAND failed: %s\n", cmd);
        close(fd);
        return;
    }
    int ok = json_bool_after(reply, "success");
    if (debug) {
        fprintf(stderr, "xscroll: focus rect=(%ld,%ld %ldx%ld) center=(%ld,%ld) seat=%s reply=%s\n",
                rx, ry, rw, rh, cx, cy, seat, reply);
    }
    if (!ok && debug) fprintf(stderr, "xscroll: sway rejected cursor set\n");
    close(fd);
}

/* ------------------------------ uinput section ---------------------------- */

static int setup_uinput(void) {
    int fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
    if (fd < 0) return -1;

    ioctl(fd, UI_SET_EVBIT, EV_REL);
    ioctl(fd, UI_SET_RELBIT, REL_WHEEL);

    struct uinput_setup usetup;
    memset(&usetup, 0, sizeof(usetup));
    usetup.id.bustype = BUS_USB;
    usetup.id.vendor = 0x1234;
    usetup.id.product = 0x5678;
    snprintf(usetup.name, UINPUT_MAX_NAME_SIZE, "xscroll-persistent");

    if (ioctl(fd, UI_DEV_SETUP, &usetup) < 0 || ioctl(fd, UI_DEV_CREATE) < 0) {
        close(fd);
        return -1;
    }
    return fd;
}

static void emit_wheel(int fd, int value, int ticks) {
    struct input_event ev;
    for (int i = 0; i < ticks; i++) {
        memset(&ev, 0, sizeof(ev));
        ev.type = EV_REL;
        ev.code = REL_WHEEL;
        ev.value = value;
        if (write(fd, &ev, sizeof(ev)) < 0) break;

        memset(&ev, 0, sizeof(ev));
        ev.type = EV_SYN;
        ev.code = SYN_REPORT;
        ev.value = 0;
        if (write(fd, &ev, sizeof(ev)) < 0) break;
    }
}

static int run_daemon(void) {
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    get_sock_path(addr.sun_path, sizeof(addr.sun_path));
    unlink(addr.sun_path);

    int ufd = setup_uinput();
    if (ufd < 0) {
        fprintf(stderr, "Failed to initialize /dev/uinput: %s\n", strerror(errno));
        return 1;
    }

    int sfd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sfd < 0) {
        close(ufd);
        return 1;
    }

    if (bind(sfd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        fprintf(stderr, "Failed to bind %s: %s\n", addr.sun_path, strerror(errno));
        close(sfd);
        close(ufd);
        return 1;
    }

    if (listen(sfd, 32) < 0) {
        close(sfd);
        close(ufd);
        return 1;
    }

    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = handle_sig;
    sigaction(SIGINT, &sa, NULL);
    sigaction(SIGTERM, &sa, NULL);
    signal(SIGPIPE, SIG_IGN);

    while (running) {
        int cfd = accept(sfd, NULL, NULL);
        if (cfd < 0) {
            if (errno == EINTR) continue;
            break;
        }

        char buf[32];
        ssize_t n = read(cfd, buf, sizeof(buf) - 1);
        if (n > 0) {
            buf[n] = '\0';
            if (buf[0] == 'q') {
                write(cfd, "bye\n", 4);
                close(cfd);
                break;
            }
            int dir = (buf[0] == 'd' || buf[0] == 'D') ? -1 : 1;
            int ticks = 2;
            if (buf[1] >= '1' && buf[1] <= '9') {
                ticks = buf[1] - '0';
            }
            emit_wheel(ufd, dir, ticks);
            write(cfd, "ok\n", 3);
        }
        close(cfd);
    }

    unlink(addr.sun_path);
    close(sfd);
    ioctl(ufd, UI_DEV_DESTROY);
    close(ufd);
    return 0;
}

static int send_client(const char *cmd) {
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    get_sock_path(addr.sun_path, sizeof(addr.sun_path));

    int sfd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sfd < 0) return -1;

    if (connect(sfd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        close(sfd);
        return -1;
    }

    write(sfd, cmd, strlen(cmd));
    char ack[8];
    read(sfd, ack, sizeof(ack));
    close(sfd);
    return 0;
}

int main(int argc, char **argv) {
    if (argc > 1 && strcmp(argv[1], "--daemon") == 0) {
        return run_daemon();
    }
    if (argc > 1 && strcmp(argv[1], "--stop") == 0) {
        return send_client("q\n");
    }

    char cmd[16] = "u3\n";
    if (argc > 1) {
        char d = (argv[1][0] == 'd' || argv[1][0] == 'D') ? 'd' : 'u';
        int t = 3;
        if (argc > 2) {
            t = atoi(argv[2]);
            if (t <= 0) t = 1;
            if (t > 9) t = 9;
        }
        snprintf(cmd, sizeof(cmd), "%c%d\n", d, t);
    }

    int debug = getenv("XSCROLL_DEBUG") != NULL;
    if (!getenv("XSCROLL_NO_WARP")) {
        warp_to_focused_sway(debug);
    }

    if (send_client(cmd) == 0) {
        if (debug) fprintf(stderr, "xscroll: sent %s ack ok\n", cmd);
        return 0;
    }

    /* Daemon not running, fork one in background */
    pid_t pid = fork();
    if (pid == 0) {
        setsid();
        int devnull = open("/dev/null", O_RDWR);
        dup2(devnull, STDIN_FILENO);
        dup2(devnull, STDOUT_FILENO);
        dup2(devnull, STDERR_FILENO);
        close(devnull);
        exit(run_daemon());
    }

    /* Wait up to 200ms for daemon to bind socket */
    for (int i = 0; i < 20; i++) {
        usleep(10000);
        if (send_client(cmd) == 0) {
            return 0;
        }
    }

    return 1;
}
