/* ctm-test: Intel i915 CRTC CTM inspect/set utility (DRM master required for set).
 *
 * Safety model:
 *  --inspect : read-only, safe inside Sway (no master needed).
 *  --saturation/--identity/--restore : require DRM master. Refuses with EPERM
 *   hint when Sway holds master. Intended to run from a clean VT, not live Sway.
 *  Saves original CTM to ~/.cache/ctm-test-orig.bin (0 bytes = NULL/identity).
 *  Auto-restores on SIGINT/SIGTERM.
 *
 * Matrix: Rec.709 luma saturation, same coefficients as
 *  ~/.config/sway/scripts/generate-vibrance-icc.py (0.2126,0.7152,0.0722).
 *  DRM CTM format: S31.32 sign-magnitude (NOT two's complement).
 *
 * Build: gcc -O2 -o ~/.local/bin/ctm-test ~/.local/bin/ctm-test.c $(pkg-config --cflags --libs libdrm) -lm
 */
#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <errno.h>
#include <signal.h>
#include <unistd.h>
#include <fcntl.h>
#include <math.h>
#include <limits.h>
#include <sys/stat.h>
#include <xf86drm.h>
#include <xf86drmMode.h>

static const char *INTEL_CARD = "/dev/dri/card1";
static const char *WANT_CONN = "eDP-1";

static int drm_fd = -1;
static uint32_t g_crtc = 0, g_ctm_prop = 0;
static uint8_t g_orig[72];
static int g_orig_is_null = 1;
static int g_have_orig = 0;
static int g_committed = 0;

static void save_path(char *buf, size_t n) {
    const char *h = getenv("HOME");
    if (!h) h = "/tmp";
    snprintf(buf, n, "%s/.cache/ctm-test-orig.bin", h);
}

static double u64_to_double(uint64_t v) {
    if (v & (1ULL << 63)) {
        uint64_t mag = v & ~(1ULL << 63);
        return -((double)mag / 4294967296.0);
    }
    return (double)v / 4294967296.0;
}

static uint64_t double_to_u64(double v) {
    if (v < 0) {
        uint64_t mag = (uint64_t)((-v) * 4294967296.0 + 0.5);
        mag &= ~(1ULL << 63);
        return mag | (1ULL << 63);
    }
    return (uint64_t)(v * 4294967296.0 + 0.5);
}

/* Rec.709 saturation matrix, luminance-preserving, greys fixed. */
static void sat_matrix(double s, double m[9]) {
    const double lr = 0.2126, lg = 0.7152, lb = 0.0722;
    const double t = 1.0 - s;
    m[0] = s + t * lr;  m[1] = t * lg;      m[2] = t * lb;
    m[3] = t * lr;      m[4] = s + t * lg;  m[5] = t * lb;
    m[6] = t * lr;      m[7] = t * lg;      m[8] = s + t * lb;
}

static void restore_orig(void) {
    if (drm_fd < 0 || !g_have_orig || !g_committed) return;
    drmModeAtomicReq *req = drmModeAtomicAlloc();
    if (!req) return;
    uint64_t val = 0;
    uint32_t blob = 0;
    if (!g_orig_is_null) {
        if (drmModeCreatePropertyBlob(drm_fd, g_orig, sizeof(g_orig), &blob) != 0) {
            drmModeAtomicFree(req);
            return;
        }
        val = blob;
    }
    drmModeAtomicAddProperty(req, g_crtc, g_ctm_prop, val);
    drmModeAtomicCommit(drm_fd, req, 0, NULL);
    if (blob) drmModeDestroyPropertyBlob(drm_fd, blob);
    drmModeAtomicFree(req);
    g_committed = 0;
}

static void on_sig(int sig) {
    (void)sig;
    restore_orig();
    _exit(130);
}

static int open_intel(void) {
    int fd = open(INTEL_CARD, O_RDWR | O_CLOEXEC);
    if (fd < 0) {
        fprintf(stderr, "open %s: %s\n", INTEL_CARD, strerror(errno));
        return -1;
    }
    drmVersionPtr v = drmGetVersion(fd);
    if (v) {
        if (strcmp(v->name, "i915") != 0)
            fprintf(stderr, "warn: driver is '%s', expected 'i915'\n", v->name);
        drmFreeVersion(v);
    }
    if (drmSetClientCap(fd, DRM_CLIENT_CAP_UNIVERSAL_PLANES, 1) != 0) {
        fprintf(stderr, "warn: drmSetClientCap(UNIVERSAL_PLANES): %s\n", strerror(errno));
    }
    if (drmSetClientCap(fd, DRM_CLIENT_CAP_ATOMIC, 1) != 0) {
        fprintf(stderr, "warn: drmSetClientCap(ATOMIC): %s\n", strerror(errno));
    }
    return fd;
}

/* Find eDP-1 connector + its driving CRTC. Returns 0 on success. */
static int find_edp(int fd, uint32_t *conn_id, uint32_t *crtc_id) {
    drmModeRes *res = drmModeGetResources(fd);
    if (!res) { fprintf(stderr, "GetResources: %s\n", strerror(errno)); return -1; }
    int ret = -1;
    for (int i = 0; i < res->count_connectors; i++) {
        drmModeConnector *c = drmModeGetConnector(fd, res->connectors[i]);
        if (!c) continue;
        char name[32];
        snprintf(name, sizeof(name), "%s-%d",
            c->connector_type == DRM_MODE_CONNECTOR_eDP ? "eDP" :
            c->connector_type == DRM_MODE_CONNECTOR_DisplayPort ? "DP" :
            c->connector_type == DRM_MODE_CONNECTOR_HDMIA ? "HDMI" : "OTHER",
            c->connector_type_id);
        if (strcmp(name, WANT_CONN) == 0 && c->connection == DRM_MODE_CONNECTED) {
            *conn_id = c->connector_id;
            /* preferred: encoder's crtc */
            uint32_t crtc = 0;
            if (c->encoder_id) {
                drmModeEncoder *e = drmModeGetEncoder(fd, c->encoder_id);
                if (e) { crtc = e->crtc_id; drmModeFreeEncoder(e); }
            }
            if (!crtc) {
                /* fallback: first active CRTC */
                for (int k = 0; k < res->count_crtcs; k++) {
                    drmModeCrtc *cc = drmModeGetCrtc(fd, res->crtcs[k]);
                    if (cc) {
                        if (cc->buffer_id && cc->mode_valid) crtc = cc->crtc_id;
                        drmModeFreeCrtc(cc);
                        if (crtc) break;
                    }
                }
            }
            *crtc_id = crtc;
            drmModeFreeConnector(c);
            ret = crtc ? 0 : -2;
            break;
        }
        drmModeFreeConnector(c);
    }
    drmModeFreeResources(res);
    return ret;
}

static int get_ctm_prop(int fd, uint32_t crtc, uint32_t *prop_id, uint64_t *cur) {
    drmModeObjectPropertiesPtr ps =
        drmModeObjectGetProperties(fd, crtc, DRM_MODE_OBJECT_CRTC);
    if (!ps) { fprintf(stderr, "CRTC props: %s\n", strerror(errno)); return -1; }
    int ret = -1;
    for (uint32_t i = 0; i < ps->count_props; i++) {
        drmModePropertyPtr p = drmModeGetProperty(fd, ps->props[i]);
        if (!p) continue;
        if (strcmp(p->name, "CTM") == 0) {
            *prop_id = p->prop_id;
            *cur = ps->prop_values[i];
            ret = 0;
            drmModeFreeProperty(p);
            break;
        }
        drmModeFreeProperty(p);
    }
    drmModeFreeObjectProperties(ps);
    return ret;
}

static int do_inspect(void) {
    uint32_t conn = 0, crtc = 0;
    int fr = find_edp(drm_fd, &conn, &crtc);
    if (fr == -2) { fprintf(stderr, "eDP-1 found but no active CRTC\n"); return 1; }
    if (fr) { fprintf(stderr, "eDP-1 connector not found/active\n"); return 1; }
    uint32_t prop = 0; uint64_t cur = 0;
    if (get_ctm_prop(drm_fd, crtc, &prop, &cur)) {
        fprintf(stderr, "no CTM property on CRTC %u\n", crtc);
        return 1;
    }
    printf("driver : i915 (%s)\nconn   : eDP-1 (id %u)\ncrtc   : %u\nctm_prop: %u\nctm_blob: %llu%s\n",
        INTEL_CARD, conn, crtc, prop,
        (unsigned long long)cur, cur == 0 ? " (NULL = identity)" : "");
    if (cur) {
        drmModePropertyBlobPtr b = drmModeGetPropertyBlob(drm_fd, (uint32_t)cur);
        if (!b) { printf("blob read failed: %s\n", strerror(errno)); return 1; }
        if (b->length < sizeof(struct drm_color_ctm)) {
            printf("blob len %u < 72\n", b->length);
            drmModeFreePropertyBlob(b);
            return 1;
        }
        struct drm_color_ctm *ctm = b->data;
        printf("matrix (float):\n");
        for (int r = 0; r < 3; r++)
            printf("  [ % .6f  % .6f  % .6f ]\n",
                u64_to_double(ctm->matrix[r*3]),
                u64_to_double(ctm->matrix[r*3+1]),
                u64_to_double(ctm->matrix[r*3+2]));
        drmModeFreePropertyBlob(b);
    } else {
        printf("matrix (float): identity (NULL passthrough)\n");
    }
    /* gamma sizes for pipeline context */
    drmModeObjectPropertiesPtr ps =
        drmModeObjectGetProperties(drm_fd, crtc, DRM_MODE_OBJECT_CRTC);
    if (ps) {
        for (uint32_t i = 0; i < ps->count_props; i++) {
            drmModePropertyPtr p = drmModeGetProperty(drm_fd, ps->props[i]);
            if (p) {
                if (!strcmp(p->name, "DEGAMMA_LUT_SIZE") || !strcmp(p->name, "GAMMA_LUT_SIZE"))
                    printf("%s: %llu\n", p->name, (unsigned long long)ps->prop_values[i]);
                drmModeFreeProperty(p);
            }
        }
        drmModeFreeObjectProperties(ps);
    }
    return 0;
}

static int require_master(void) {
    if (drmSetMaster(drm_fd) != 0) {
        fprintf(stderr,
            "drmSetMaster failed: %s\n"
            "Sway (or another compositor) holds DRM master.\n"
            "Switch to a clean VT (Ctrl+Alt+F3), stop Sway / log out,\n"
            "then retry. --inspect works without master.\n",
            strerror(errno));
        return -1;
    }
    return 0;
}

/* Generic prop lookup by name on the CRTC. */
static int get_prop(int fd, uint32_t crtc, const char *name,
                    uint32_t *prop_id, uint64_t *cur) {
    drmModeObjectPropertiesPtr ps =
        drmModeObjectGetProperties(fd, crtc, DRM_MODE_OBJECT_CRTC);
    if (!ps) return -1;
    int ret = -1;
    for (uint32_t i = 0; i < ps->count_props; i++) {
        drmModePropertyPtr p = drmModeGetProperty(fd, ps->props[i]);
        if (!p) continue;
        if (strcmp(p->name, name) == 0) {
            if (prop_id) *prop_id = p->prop_id;
            if (cur) *cur = ps->prop_values[i];
            ret = 0;
            drmModeFreeProperty(p);
            break;
        }
        drmModeFreeProperty(p);
    }
    drmModeFreeObjectProperties(ps);
    return ret;
}

/* One TEST_ONLY probe with optional degamma+ctm in a single request.
 * Never touches hardware. Returns 0 if driver accepts. */
static int probe_state(uint32_t degamma_prop, uint32_t degamma_blob,
                       uint32_t ctm_prop, uint32_t ctm_blob,
                       uint32_t flags, const char *tag) {
    drmModeAtomicReq *t = drmModeAtomicAlloc();
    if (!t) { fprintf(stderr, "%s: alloc failed\n", tag); return -1; }
    if (degamma_prop)
        drmModeAtomicAddProperty(t, g_crtc, degamma_prop, degamma_blob);
    if (ctm_prop)
        drmModeAtomicAddProperty(t, g_crtc, ctm_prop, ctm_blob);
    int tr = drmModeAtomicCommit(drm_fd, t,
        flags | DRM_MODE_ATOMIC_TEST_ONLY, NULL);
    fprintf(stderr, "%s flags=0x%x -> %s\n",
        tag, flags | DRM_MODE_ATOMIC_TEST_ONLY,
        tr == 0 ? "OK" : strerror(errno));
    drmModeAtomicFree(t);
    return tr;
}

static int snapshot_orig(uint32_t prop, uint64_t cur) {
    g_ctm_prop = prop;
    if (cur == 0) {
        g_orig_is_null = 1;
    } else {
        drmModePropertyBlobPtr b = drmModeGetPropertyBlob(drm_fd, (uint32_t)cur);
        if (!b || b->length < sizeof(g_orig)) {
            fprintf(stderr, "cannot snapshot orig CTM blob\n");
            if (b) drmModeFreePropertyBlob(b);
            return -1;
        }
        memcpy(g_orig, b->data, sizeof(g_orig));
        g_orig_is_null = 0;
        drmModeFreePropertyBlob(b);
    }
    g_have_orig = 1;
    /* persist */
    char path[PATH_MAX]; save_path(path, sizeof(path));
    FILE *f = fopen(path, "wb");
    if (f) {
        if (!g_orig_is_null) fwrite(g_orig, 1, sizeof(g_orig), f);
        fclose(f);
        chmod(path, 0600);
    }
    return 0;
}

static int commit_ctm_flags(uint64_t val, uint32_t flags, const char *tag) {
    drmModeAtomicReq *req = drmModeAtomicAlloc();
    if (!req) { fprintf(stderr, "%s: atomic alloc failed\n", tag); return -1; }
    int ap = drmModeAtomicAddProperty(req, g_crtc, g_ctm_prop, val);
    if (ap <= 0) {
        fprintf(stderr, "%s: AddProperty(crtc %u, prop %u) failed: %s\n",
            tag, g_crtc, g_ctm_prop, strerror(errno));
        drmModeAtomicFree(req);
        return -1;
    }
    /* TEST_ONLY first: validates without touching hardware */
    drmModeAtomicReq *t = drmModeAtomicAlloc();
    if (t) {
        drmModeAtomicAddProperty(t, g_crtc, g_ctm_prop, val);
        int tr = drmModeAtomicCommit(drm_fd, t,
            flags | DRM_MODE_ATOMIC_TEST_ONLY, NULL);
        fprintf(stderr, "%s: TEST_ONLY flags=0x%x -> %s\n",
            tag, flags | DRM_MODE_ATOMIC_TEST_ONLY,
            tr == 0 ? "OK" : strerror(errno));
        drmModeAtomicFree(t);
        if (tr != 0) {
            drmModeAtomicFree(req);
            errno = EINVAL;
            return -1;
        }
    }
    int r = drmModeAtomicCommit(drm_fd, req, flags, NULL);
    fprintf(stderr, "%s: COMMIT flags=0x%x -> %s\n",
        tag, flags, r == 0 ? "OK" : strerror(errno));
    drmModeAtomicFree(req);
    return r;
}

static int commit_ctm(uint64_t val) {
    /* Fresh master after VT takeover usually needs ALLOW_MODESET to latch
     * state; property-only (0) may EINVAL. Try modeset first, fall back. */
    if (commit_ctm_flags(val, DRM_MODE_ATOMIC_ALLOW_MODESET, "try1") == 0)
        return 0;
    return commit_ctm_flags(val, 0, "try2");
}

/* Linear degamma ramp (identity): satisfies "CTM needs DEGAMMA" checks
 * without changing colors. n = DEGAMMA_LUT_SIZE (33 on this panel). */
static int make_linear_degamma(uint32_t n, struct drm_color_lut **out) {
    if (n == 0 || n > 4096) return -1;
    struct drm_color_lut *lut = calloc(n, sizeof(*lut));
    if (!lut) return -1;
    for (uint32_t i = 0; i < n; i++) {
        uint16_t v = (uint16_t)((uint64_t)i * 0xffff / (n - 1));
        lut[i].red = lut[i].green = lut[i].blue = v;
        lut[i].reserved = 0;
    }
    *out = lut;
    return 0;
}

static void usage(const char *a) {
    fprintf(stderr,
        "usage: %s --inspect | --diagnose | --set <s> | --saturation <s> | --identity | --restore\n"
        "  --inspect        read-only dump (safe under Sway)\n"
        "  --diagnose       TEST_ONLY ladder, changes nothing (needs master/VT)\n"
        "  --set <s>        apply Rec.709 saturation s permanently (exits immediately)\n"
        "  --saturation <s> set Rec.709 saturation s temporarily (restores on Ctrl+C)\n"
        "  --identity       reset CTM to NULL (passthrough)\n"
        "  --restore        restore snapshot from ~/.cache/ctm-test-orig.bin\n", a);
}

int main(int argc, char **argv) {
    if (argc < 2) { usage(argv[0]); return 2; }
    drm_fd = open_intel();
    if (drm_fd < 0) return 1;

    if (!strcmp(argv[1], "--inspect")) {
        int r = do_inspect();
        close(drm_fd);
        return r;
    }

    /* set paths need master + discovery */
    uint32_t conn = 0, crtc = 0;
    int fr = find_edp(drm_fd, &conn, &crtc);
    if (fr) { fprintf(stderr, "eDP-1 not active (err %d)\n", fr); return 1; }
    if (crtc != 151)
        fprintf(stderr, "note: CRTC is %u (not 151 — IDs vary per boot; using discovered)\n",
            crtc);
    g_crtc = crtc;
    uint32_t prop = 0; uint64_t cur = 0;
    if (get_ctm_prop(drm_fd, crtc, &prop, &cur)) {
        fprintf(stderr, "no CTM on CRTC %u\n", crtc);
        return 1;
    }
    if (require_master() != 0) return 1;
    /* re-read after master (state may have changed) */
    if (get_ctm_prop(drm_fd, crtc, &prop, &cur) != 0) return 1;
    g_ctm_prop = prop;
    signal(SIGINT, on_sig);
    signal(SIGTERM, on_sig);

    if (!strcmp(argv[1], "--diagnose")) {
        uint32_t dg_prop = 0, gm_prop = 0;
        uint64_t dg_cur = 0, gm_cur = 0, dg_size = 0;
        get_prop(drm_fd, crtc, "DEGAMMA_LUT", &dg_prop, &dg_cur);
        get_prop(drm_fd, crtc, "GAMMA_LUT", &gm_prop, &gm_cur);
        get_prop(drm_fd, crtc, "DEGAMMA_LUT_SIZE", NULL, &dg_size);
        if (!dg_size) dg_size = 33;
        printf("degamma_prop=%u cur=%llu size=%llu  ctm_prop=%u\n",
            dg_prop, (unsigned long long)dg_cur, (unsigned long long)dg_size, prop);
        /* identity + saturation blobs */
        struct drm_color_ctm ident, sat;
        for (int i = 0; i < 9; i++)
            ident.matrix[i] = (i % 4 == 0) ? (1ULL << 32) : 0;
        double m[9]; sat_matrix(1.3, m);
        for (int i = 0; i < 9; i++) sat.matrix[i] = double_to_u64(m[i]);
        uint32_t b_ident = 0, b_sat = 0;
        drmModeCreatePropertyBlob(drm_fd, &ident, sizeof(ident), &b_ident);
        drmModeCreatePropertyBlob(drm_fd, &sat, sizeof(sat), &b_sat);
        struct drm_color_lut *lin = NULL;
        uint32_t b_dg = 0;
        if (make_linear_degamma((uint32_t)dg_size, &lin) == 0)
            drmModeCreatePropertyBlob(drm_fd, lin,
                sizeof(*lin) * (uint32_t)dg_size, &b_dg);
        probe_state(0, 0, prop, 0, 0, "d0 null-ctm");
        probe_state(0, 0, prop, 0, DRM_MODE_ATOMIC_ALLOW_MODESET, "d1 null-ctm+modeset");
        probe_state(0, 0, prop, b_ident, DRM_MODE_ATOMIC_ALLOW_MODESET, "d2 identity-blob");
        probe_state(0, 0, prop, b_sat, DRM_MODE_ATOMIC_ALLOW_MODESET, "d3 sat1.3-ctm-only");
        if (dg_prop && b_dg)
            probe_state(dg_prop, b_dg, prop, b_sat, DRM_MODE_ATOMIC_ALLOW_MODESET, "d4 linear-degamma+sat1.3");
        else
            fprintf(stderr, "d4 skipped (no degamma prop/blob)\n");
        if (b_ident) drmModeDestroyPropertyBlob(drm_fd, b_ident);
        if (b_sat) drmModeDestroyPropertyBlob(drm_fd, b_sat);
        if (b_dg) drmModeDestroyPropertyBlob(drm_fd, b_dg);
        free(lin);
        printf("diagnose done. d0/d1 must be OK (mechanics). "
               "d2 OK + d3 FAIL = matrix/range issue. "
               "d3 FAIL + d4 OK = needs DEGAMMA.\n");
        return 0;
    }
    if (!strcmp(argv[1], "--identity")) {
        if (snapshot_orig(prop, cur)) return 1;
        if (commit_ctm(0) != 0) {
            fprintf(stderr, "commit identity failed: %s\n", strerror(errno));
            return 1;
        }
        printf("CTM -> NULL (identity) permanently applied on eDP-1.\n");
        return 0;
    }
    if (!strcmp(argv[1], "--restore")) {
        char path[PATH_MAX]; save_path(path, sizeof(path));
        FILE *f = fopen(path, "rb");
        uint8_t buf[72]; size_t n = 0;
        if (f) { n = fread(buf, 1, sizeof(buf), f); fclose(f); }
        else { fprintf(stderr, "no snapshot %s\n", path); return 1; }
        uint64_t val = 0; uint32_t blob = 0;
        if (n == sizeof(buf)) {
            if (drmModeCreatePropertyBlob(drm_fd, buf, sizeof(buf), &blob)) {
                fprintf(stderr, "create blob: %s\n", strerror(errno)); return 1;
            }
            val = blob;
        }
        drmModeAtomicReq *req = drmModeAtomicAlloc();
        if (!req) { if (blob) drmModeDestroyPropertyBlob(drm_fd, blob); return 1; }
        int ap = drmModeAtomicAddProperty(req, g_crtc, prop, val);
        if (ap <= 0) {
            fprintf(stderr, "restore AddProperty failed: %s\n", strerror(errno));
            drmModeAtomicFree(req);
            if (blob) drmModeDestroyPropertyBlob(drm_fd, blob);
            return 1;
        }
        int r = drmModeAtomicCommit(drm_fd, req, DRM_MODE_ATOMIC_ALLOW_MODESET, NULL);
        fprintf(stderr, "restore COMMIT flags=0x%x -> %s\n",
            DRM_MODE_ATOMIC_ALLOW_MODESET, r == 0 ? "OK" : strerror(errno));
        if (r != 0)
            r = drmModeAtomicCommit(drm_fd, req, 0, NULL);
        drmModeAtomicFree(req);
        if (blob) drmModeDestroyPropertyBlob(drm_fd, blob);
        if (r) { fprintf(stderr, "restore commit: %s\n", strerror(errno)); return 1; }
        printf("restored (%s).\n", n == sizeof(buf) ? "matrix" : "NULL");
        return 0;
    }
    if (!strcmp(argv[1], "--saturation") || !strcmp(argv[1], "--set") || !strcmp(argv[1], "--apply")) {
        int persistent = strcmp(argv[1], "--saturation") != 0;
        if (argc < 3) { usage(argv[0]); return 2; }
        double s = atof(argv[2]);
        if (!(s >= 0.0 && s <= 4.0)) { fprintf(stderr, "s out of range 0..4\n"); return 2; }
        double m[9]; sat_matrix(s, m);
        struct drm_color_ctm ctm;
        for (int i = 0; i < 9; i++) ctm.matrix[i] = double_to_u64(m[i]);
        if (snapshot_orig(prop, cur)) return 1;
        uint32_t blob = 0;
        if (drmModeCreatePropertyBlob(drm_fd, &ctm, sizeof(ctm), &blob)) {
            fprintf(stderr, "create blob: %s\n", strerror(errno)); return 1;
        }
        if (commit_ctm(blob) != 0) {
            fprintf(stderr, "ctm-only rejected, trying linear-degamma+ctm...\n");
            uint32_t dg_prop = 0; uint64_t dg_size = 0;
            get_prop(drm_fd, crtc, "DEGAMMA_LUT", &dg_prop, NULL);
            get_prop(drm_fd, crtc, "DEGAMMA_LUT_SIZE", NULL, &dg_size);
            if (!dg_size) dg_size = 33;
            struct drm_color_lut *lin = NULL;
            uint32_t b_dg = 0;
            int ok = -1;
            if (dg_prop && make_linear_degamma((uint32_t)dg_size, &lin) == 0 &&
                drmModeCreatePropertyBlob(drm_fd, lin,
                    sizeof(*lin) * (uint32_t)dg_size, &b_dg) == 0) {
                drmModeAtomicReq *req = drmModeAtomicAlloc();
                if (req) {
                    drmModeAtomicAddProperty(req, g_crtc, dg_prop, b_dg);
                    drmModeAtomicAddProperty(req, g_crtc, g_ctm_prop, blob);
                    ok = drmModeAtomicCommit(drm_fd, req,
                        DRM_MODE_ATOMIC_ALLOW_MODESET, NULL);
                    fprintf(stderr, "combined COMMIT -> %s\n",
                        ok == 0 ? "OK" : strerror(errno));
                    drmModeAtomicFree(req);
                }
                drmModeDestroyPropertyBlob(drm_fd, b_dg);
            }
            free(lin);
            if (ok != 0) {
                fprintf(stderr, "commit saturation failed: %s\n", strerror(errno));
                drmModeDestroyPropertyBlob(drm_fd, blob);
                return 1;
            }
        }
        drmModeDestroyPropertyBlob(drm_fd, blob);
        if (persistent) {
            printf("CTM -> saturation %.3g permanently applied on eDP-1 (CRTC %u). Orig saved.\n", s, crtc);
            return 0;
        }
        g_committed = 1;
        printf("CTM -> saturation %.3g on eDP-1 (CRTC %u). Orig saved.\n", s, crtc);
        printf("Matrix:\n  [ % .6f  % .6f  % .6f ]\n  [ % .6f  % .6f  % .6f ]\n  [ % .6f  % .6f  % .6f ]\n",
            m[0],m[1],m[2],m[3],m[4],m[5],m[6],m[7],m[8]);
        printf("Press Ctrl+C to restore and exit.\n");
        pause();
        restore_orig();
        printf("restored.\n");
        return 0;
    }
    usage(argv[0]);
    return 2;
}
