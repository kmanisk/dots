/*
 * xscroll.c — Ultra-low-latency persistent UInput mouse wheel emulator
 *
 * Keeps a single persistent virtual mouse device registered in Linux input
 * subsystem, eliminating device creation overhead, libinput churn, and sleep delays.
 *
 * Features:
 *   - Proper mouse classification: EV_KEY (BTN_LEFT), EV_REL (REL_X, REL_Y,
 *     REL_WHEEL, REL_WHEEL_HI_RES) so libinput and Sway seat assign it as a
 *     valid pointer for all Wayland windows (Foot, OpenCode, Brave, etc.).
 *   - Center-of-screen cursor alignment: queries Sway GET_OUTPUTS over IPC and
 *     warps cursor to (x + width/2, y + height/2) of the focused output.
 *     Removes mouse positioning dependency so scrolling always works anywhere.
 *   - Burst throttle: only warps on the initial keypress of a scroll burst
 *     (within 400ms), maintaining <0.2ms latency on continuous key-repeats.
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
 * sway message types: RUN_COMMAND=0, GET_OUTPUTS=3.
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
        return -1;
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

/* Parse GET_OUTPUTS JSON to locate the center of the focused display. */
static int find_focused_output_center(const char *j, long *cx, long *cy) {
    const char *f = strstr(j, "\"focused\"");
    while (f) {
        const char *q = skip_ws(f + 9);
        if (*q == ':') {
            q = skip_ws(q + 1);
            if (strncmp(q, "true", 4) == 0) {
                /* Walk backward to find the enclosing output object start '{' */
                const char *obj_start = f;
                int depth = 0;
                while (obj_start > j) {
                    if (*obj_start == '}') depth++;
                    else if (*obj_start == '{') {
                        if (depth == 0) break;
                        depth--;
                    }
                    obj_start--;
                }
                const char *r = strstr(obj_start, "\"rect\"");
                if (r && r < f) {
                    const char *body = strchr(r, '{');
                    if (body) {
                        long x = 0, y = 0, w = 0, h = 0;
                        if (json_num_after(body, "x", &x) == 0 &&
                            json_num_after(body, "y", &y) == 0 &&
                            json_num_after(body, "width", &w) == 0 &&
                            json_num_after(body, "height", &h) == 0 &&
                            w > 0 && h > 0) {
                            *cx = x + w / 2;
                            *cy = y + h / 2;
                            return 0;
                        }
                    }
                }
            }
        }
        f = strstr(f + 1, "\"focused\"");
    }
    return -1;
}

/* Find center of focused container (GET_TREE) or fallback to output (GET_OUTPUTS) */
static int find_focused_target_center(int fd, long *cx, long *cy) {
    static char jbuf[64 * 1024];
    uint32_t rtype;

    /* Try GET_TREE (type 4) first to get exact focused window rect */
    if (sway_ipc_roundtrip(fd, 4 /*GET_TREE*/, "", 0, jbuf, sizeof(jbuf), &rtype) == 0) {
        const char *f = strstr(jbuf, "\"focused\"");
        while (f) {
            const char *q = skip_ws(f + 9);
            if (*q == ':') {
                q = skip_ws(q + 1);
                if (strncmp(q, "true", 4) == 0) {
                    /* Walk backward to find the container object '{' */
                    const char *obj = f;
                    int depth = 0;
                    while (obj > jbuf) {
                        if (*obj == '}') depth++;
                        else if (*obj == '{') {
                            if (depth == 0) break;
                            depth--;
                        }
                        obj--;
                    }
                    const char *r = strstr(obj, "\"rect\"");
                    if (r && r < f) {
                        const char *body = strchr(r, '{');
                        if (body) {
                            long x = 0, y = 0, w = 0, h = 0;
                            if (json_num_after(body, "x", &x) == 0 &&
                                json_num_after(body, "y", &y) == 0 &&
                                json_num_after(body, "width", &w) == 0 &&
                                json_num_after(body, "height", &h) == 0 &&
                                w > 0 && h > 0) {
                                *cx = x + w / 2;
                                *cy = y + h / 2;
                                return 0;
                            }
                        }
                    }
                }
            }
            f = strstr(f + 1, "\"focused\"");
        }
    }

    /* Fallback to GET_OUTPUTS (type 3) */
    if (sway_ipc_roundtrip(fd, 3 /*GET_OUTPUTS*/, "", 0, jbuf, sizeof(jbuf), &rtype) == 0) {
        if (find_focused_output_center(jbuf, cx, cy) == 0) {
            return 0;
        }
    }
    return -1;
}

static void warp_to_screen_center_sway(int debug) {
    /* Fast-path throttle: during continuous scroll bursts, warp once every 400ms. */
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
            if (diff_ms >= 0 && diff_ms < 400) {
                close(wfd);
                return;
            }
        }
        lseek(wfd, 0, SEEK_SET);
        if (write(wfd, &now, sizeof(now)) != sizeof(now)) {
            /* ignore */
        }
        close(wfd);
    }

    const char *sock = getenv("SWAYSOCK");
    if (!sock || !sock[0]) sock = getenv("I3SOCK");
    if (!sock || !sock[0]) {
        if (debug) fprintf(stderr, "xscroll: no SWAYSOCK/I3SOCK\n");
        return;
    }

    struct sockaddr_un a;
    memset(&a, 0, sizeof(a));
    a.sun_family = AF_UNIX;
    strncpy(a.sun_path, sock, sizeof(a.sun_path) - 1);

    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) return;
    if (connect(fd, (struct sockaddr *)&a, sizeof(a)) < 0) {
        if (debug) fprintf(stderr, "xscroll: connect sway IPC: %s\n", strerror(errno));
        close(fd);
        return;
    }

    long cx = -1, cy = -1;
    if (find_focused_target_center(fd, &cx, &cy) < 0) {
        if (debug) fprintf(stderr, "xscroll: focused target center not found\n");
        close(fd);
        return;
    }

    char cmd[96];
    snprintf(cmd, sizeof(cmd), "seat - cursor set %ld %ld", cx, cy);
    static char reply[512];
    uint32_t rtype;
    if (sway_ipc_roundtrip(fd, 0 /*RUN_COMMAND*/, cmd, strlen(cmd), reply, sizeof(reply), &rtype) < 0) {
        if (debug) fprintf(stderr, "xscroll: cursor set command failed: %s\n", cmd);
        close(fd);
        return;
    }

    if (debug) {
        fprintf(stderr, "xscroll: warped cursor to center (%ld, %ld)\n", cx, cy);
    }
    close(fd);
}

/* ------------------------------ uinput section ---------------------------- */

static int setup_uinput(void) {
    int fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
    if (fd < 0) return -1;

    /* Declare full mouse capabilities so libinput and wlroots classify it as
     * an official pointer and attach it to seat0 for all Wayland surfaces. */
    ioctl(fd, UI_SET_EVBIT, EV_KEY);
    ioctl(fd, UI_SET_KEYBIT, BTN_LEFT);
    ioctl(fd, UI_SET_EVBIT, EV_REL);
    ioctl(fd, UI_SET_RELBIT, REL_X);
    ioctl(fd, UI_SET_RELBIT, REL_Y);
    ioctl(fd, UI_SET_RELBIT, REL_WHEEL);
    ioctl(fd, UI_SET_RELBIT, REL_WHEEL_HI_RES);

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

    /* Micro-motion to unhide mouse cursor in terminals with hide-when-typing */
    memset(&ev, 0, sizeof(ev));
    ev.type = EV_REL;
    ev.code = REL_X;
    ev.value = 1;
    if (write(fd, &ev, sizeof(ev)) > 0) {
        memset(&ev, 0, sizeof(ev));
        ev.type = EV_SYN;
        ev.code = SYN_REPORT;
        ev.value = 0;
        write(fd, &ev, sizeof(ev));

        memset(&ev, 0, sizeof(ev));
        ev.type = EV_REL;
        ev.code = REL_X;
        ev.value = -1;
        write(fd, &ev, sizeof(ev));

        memset(&ev, 0, sizeof(ev));
        ev.type = EV_SYN;
        ev.code = SYN_REPORT;
        ev.value = 0;
        write(fd, &ev, sizeof(ev));
    }

    for (int i = 0; i < ticks; i++) {
        /* High-resolution wheel notch (standard 120 per click) */
        memset(&ev, 0, sizeof(ev));
        ev.type = EV_REL;
        ev.code = REL_WHEEL_HI_RES;
        ev.value = value * 120;
        if (write(fd, &ev, sizeof(ev)) < 0) break;

        /* Standard relative wheel notch (1 or -1) */
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

    while (running) {
        int cfd = accept(sfd, NULL, NULL);
        if (cfd < 0) {
            if (errno == EINTR) continue;
            break;
        }

        char buf[16];
        ssize_t n = read(cfd, buf, sizeof(buf) - 1);
        if (n > 0) {
            buf[n] = '\0';
            if (buf[0] == 'q') {
                close(cfd);
                break;
            }
            int dir = (buf[0] == 'u') ? 1 : -1;
            int ticks = (buf[1] >= '1' && buf[1] <= '9') ? (buf[1] - '0') : 3;
            emit_wheel(ufd, dir, ticks);
            if (write(cfd, "OK\n", 3) != 3) {
                /* ignore */
            }
        }
        close(cfd);
    }

    close(sfd);
    unlink(addr.sun_path);
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

    if (write(sfd, cmd, strlen(cmd)) < 0) {
        close(sfd);
        return -1;
    }
    char ack[8];
    if (read(sfd, ack, sizeof(ack)) < 0) {
        /* ignore */
    }
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
        warp_to_screen_center_sway(debug);
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
