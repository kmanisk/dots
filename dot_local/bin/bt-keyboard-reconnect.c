#define _GNU_SOURCE
#include <systemd/sd-bus.h>
#include <systemd/sd-event.h>

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdbool.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

#define KEYBOARD_PATH "/org/bluez/hci0/dev_CC_04_2E_90_66_02"
#define ADAPTER_PATH "/org/bluez/hci0"
#define CONNECT_TIMEOUT_USEC (15ULL * 1000000ULL)
#define MAX_LOG_SIZE (128 * 1024)
#define USEC_PER_SEC 1000000ULL

typedef struct App {
    sd_event *event;
    sd_bus *system_bus;
    sd_bus *user_bus;
    sd_bus_slot *properties_slot;
    sd_bus_slot *interfaces_slot;
    sd_bus_slot *sleep_slot;
    sd_bus_slot *unlock_slot;
    sd_bus_slot *connect_slot;
    sd_bus_slot *xremap_slot;
    sd_event_source *reconnect_timer;
    sd_event_source *ensure_timer;
    sd_event_source *connect_timer;
    unsigned retry_interval;
    bool connecting;
    char log_path[4096];
    char last_property_error[256];
} App;

static void app_log(App *app, const char *fmt, ...) __attribute__((format(printf, 2, 3)));
static int connect_once(App *app);
static int schedule_reconnect(App *app, unsigned delay_sec);
static int schedule_connect(App *app, unsigned delay_sec);
static int schedule_ensure_xremap(App *app, unsigned delay_sec);

static void app_log(App *app, const char *fmt, ...) {
    char msg[2048];
    char line[2300];
    char timestamp[64];
    time_t now = time(NULL);
    struct tm tm_now;
    va_list ap;

    localtime_r(&now, &tm_now);
    strftime(timestamp, sizeof timestamp, "%Y-%m-%d %H:%M:%S", &tm_now);

    va_start(ap, fmt);
    vsnprintf(msg, sizeof msg, fmt, ap);
    va_end(ap);

    snprintf(line, sizeof line, "[%s] [bt-keyboard-reconnect] %s", timestamp, msg);
    fprintf(stdout, "%s\n", line);
    fflush(stdout);

    if (!app || !app->log_path[0])
        return;

    struct stat st;
    if (stat(app->log_path, &st) == 0 && st.st_size > MAX_LOG_SIZE) {
        char old_path[sizeof app->log_path + 8];
        snprintf(old_path, sizeof old_path, "%s.old", app->log_path);
        unlink(old_path);
        rename(app->log_path, old_path);
    }

    int fd = open(app->log_path, O_WRONLY | O_CREAT | O_APPEND | O_CLOEXEC, 0600);
    if (fd >= 0) {
        dprintf(fd, "%s\n", line);
        close(fd);
    }
}

static bool read_line(const char *path, char *buf, size_t size) {
    FILE *f = fopen(path, "r");
    if (!f)
        return false;
    bool ok = fgets(buf, (int)size, f) != NULL;
    fclose(f);
    if (!ok)
        return false;
    buf[strcspn(buf, "\r\n")] = 0;
    return true;
}

static bool is_xremap_attached(void) {
    DIR *proc = opendir("/proc");
    if (!proc)
        return false;

    uid_t uid = getuid();
    bool attached = false;
    struct dirent *ent;

    while (!attached && (ent = readdir(proc)) != NULL) {
        char *end = NULL;
        long pid = strtol(ent->d_name, &end, 10);
        if (!ent->d_name[0] || !end || *end || pid <= 0)
            continue;

        char proc_path[256];
        struct stat st;
        snprintf(proc_path, sizeof proc_path, "/proc/%ld", pid);
        if (stat(proc_path, &st) != 0 || st.st_uid != uid)
            continue;

        char comm[64];
        snprintf(proc_path, sizeof proc_path, "/proc/%ld/comm", pid);
        if (!read_line(proc_path, comm, sizeof comm) || strcmp(comm, "xremap") != 0)
            continue;

        char fd_dir_path[256];
        snprintf(fd_dir_path, sizeof fd_dir_path, "/proc/%ld/fd", pid);
        DIR *fds = opendir(fd_dir_path);
        if (!fds)
            continue;

        struct dirent *fdent;
        while (!attached && (fdent = readdir(fds)) != NULL) {
            if (fdent->d_name[0] == '.')
                continue;

            char link_path[1024];
            char target[4096];
            int link_len = snprintf(link_path, sizeof link_path, "%s/%s", fd_dir_path, fdent->d_name);
            if (link_len < 0 || (size_t)link_len >= sizeof link_path)
                continue;
            ssize_t n = readlink(link_path, target, sizeof target - 1);
            if (n <= 0)
                continue;
            target[n] = 0;

            const char *prefix = "/dev/input/event";
            if (strncmp(target, prefix, strlen(prefix)) != 0)
                continue;

            const char *event_name = strrchr(target, '/');
            if (!event_name || !event_name[1])
                continue;
            event_name++;

            char name_path[512];
            char device_name[256];
            snprintf(name_path, sizeof name_path, "/sys/class/input/%s/device/name", event_name);
            if (read_line(name_path, device_name, sizeof device_name) && strstr(device_name, "Katana S K"))
                attached = true;
        }
        closedir(fds);
    }

    closedir(proc);
    return attached;
}

static int is_connected(App *app, bool *connected) {
    int value = 0;
    sd_bus_error error = SD_BUS_ERROR_NULL;
    int r = sd_bus_get_property_trivial(
        app->system_bus,
        "org.bluez",
        KEYBOARD_PATH,
        "org.bluez.Device1",
        "Connected",
        &error,
        'b',
        &value);

    if (r < 0) {
        const char *detail = error.message ? error.message : strerror(-r);
        if (strcmp(app->last_property_error, detail) != 0) {
            snprintf(app->last_property_error, sizeof app->last_property_error, "%s", detail);
            app_log(app, "Could not read Connected property: %s", detail);
        }
        sd_bus_error_free(&error);
        *connected = false;
        return r;
    }

    app->last_property_error[0] = 0;
    sd_bus_error_free(&error);
    *connected = value != 0;
    return 0;
}

static int on_xremap_restart_reply(sd_bus_message *m, void *userdata, sd_bus_error *ret_error) {
    App *app = userdata;
    app->xremap_slot = sd_bus_slot_unref(app->xremap_slot);

    if (ret_error && sd_bus_error_is_set(ret_error)) {
        const char *detail = ret_error->message ? ret_error->message : ret_error->name;
        app_log(app, "Failed to restart xremap: %s", detail ? detail : "unknown D-Bus error");
        return 0;
    }
    if (sd_bus_message_is_method_error(m, NULL)) {
        const sd_bus_error *e = sd_bus_message_get_error(m);
        app_log(app, "Failed to restart xremap: %s", e && e->message ? e->message : "D-Bus method error");
        return 0;
    }

    app_log(app, "xremap restarted to attach to all connected keyboards.");
    return 0;
}

static void restart_xremap(App *app) {
    if (!app->user_bus) {
        app_log(app, "Cannot restart xremap: user D-Bus unavailable.");
        return;
    }
    if (app->xremap_slot)
        return;

    int r = sd_bus_call_method_async(
        app->user_bus,
        &app->xremap_slot,
        "org.freedesktop.systemd1",
        "/org/freedesktop/systemd1",
        "org.freedesktop.systemd1.Manager",
        "RestartUnit",
        on_xremap_restart_reply,
        app,
        "ss",
        "xremap.service",
        "replace");
    if (r < 0) {
        app->xremap_slot = sd_bus_slot_unref(app->xremap_slot);
        app_log(app, "Failed to request xremap restart: %s", strerror(-r));
    }
}

static void ensure_xremap(App *app) {
    bool connected = false;
    if (is_connected(app, &connected) < 0 || !connected)
        return;

    if (is_xremap_attached()) {
        app_log(app, "Katana connected and xremap is already attached.");
        return;
    }

    app_log(app, "Katana connected but xremap not attached. Restarting xremap...");
    restart_xremap(app);
}

static void cancel_timer(sd_event_source **source) {
    if (*source)
        *source = sd_event_source_unref(*source);
}

static void cancel_reconnect(App *app) {
    cancel_timer(&app->reconnect_timer);
    app->retry_interval = 2;
}

static int ensure_timer_cb(sd_event_source *s, uint64_t usec, void *userdata) {
    (void)usec;
    App *app = userdata;
    if (app->ensure_timer == s)
        app->ensure_timer = NULL;
    sd_event_source_unref(s);
    ensure_xremap(app);
    return 0;
}

static int connect_timer_cb(sd_event_source *s, uint64_t usec, void *userdata) {
    (void)usec;
    App *app = userdata;
    if (app->connect_timer == s)
        app->connect_timer = NULL;
    sd_event_source_unref(s);
    connect_once(app);
    return 0;
}

static int schedule_timer(App *app, sd_event_source **slot, unsigned delay_sec,
                          sd_event_time_handler_t callback) {
    cancel_timer(slot);
    int r = sd_event_add_time_relative(
        app->event,
        slot,
        CLOCK_MONOTONIC,
        (uint64_t)delay_sec * USEC_PER_SEC,
        100000,
        callback,
        app);
    if (r >= 0)
        sd_event_source_set_enabled(*slot, SD_EVENT_ONESHOT);
    return r;
}

static int schedule_ensure_xremap(App *app, unsigned delay_sec) {
    return schedule_timer(app, &app->ensure_timer, delay_sec, ensure_timer_cb);
}

static int schedule_connect(App *app, unsigned delay_sec) {
    return schedule_timer(app, &app->connect_timer, delay_sec, connect_timer_cb);
}

static int on_connect_reply(sd_bus_message *m, void *userdata, sd_bus_error *ret_error) {
    App *app = userdata;
    app->connecting = false;
    app->connect_slot = sd_bus_slot_unref(app->connect_slot);

    if (ret_error && sd_bus_error_is_set(ret_error)) {
        const char *detail = ret_error->message ? ret_error->message : ret_error->name;
        app_log(app, "Connect attempt ended (%s). Passive accept-list listening active.", detail ? detail : "unknown D-Bus error");
        return 0;
    }

    if (sd_bus_message_is_method_error(m, NULL)) {
        const sd_bus_error *e = sd_bus_message_get_error(m);
        const char *name = e && e->name ? e->name : "D-Bus method error";
        const char *message = e && e->message ? e->message : name;
        if (strstr(name, "AlreadyConnected") || strstr(message, "AlreadyConnected")) {
            cancel_reconnect(app);
            app_log(app, "Keyboard is already connected.");
            schedule_ensure_xremap(app, 1);
        } else {
            app_log(app, "Connect attempt ended (%s). Passive accept-list listening active.", message);
        }
        return 0;
    }

    cancel_reconnect(app);
    app_log(app, "Connection established. Ensuring xremap layers attached.");
    schedule_ensure_xremap(app, 1);
    return 0;
}

static int connect_once(App *app) {
    bool connected = false;
    if (app->connecting)
        return 0;

    if (is_connected(app, &connected) >= 0 && connected) {
        cancel_reconnect(app);
        schedule_ensure_xremap(app, 1);
        return 0;
    }

    app->connecting = true;
    app_log(app, "Attempting connection to Katana S K2...");

    sd_bus_message *call = NULL;
    int r = sd_bus_message_new_method_call(
        app->system_bus,
        &call,
        "org.bluez",
        KEYBOARD_PATH,
        "org.bluez.Device1",
        "Connect");
    if (r < 0)
        goto fail;

    r = sd_bus_call_async(
        app->system_bus,
        &app->connect_slot,
        call,
        on_connect_reply,
        app,
        CONNECT_TIMEOUT_USEC);
    sd_bus_message_unref(call);
    if (r < 0)
        goto fail_no_message;
    return 0;

fail:
    sd_bus_message_unref(call);
fail_no_message:
    app->connecting = false;
    app->connect_slot = sd_bus_slot_unref(app->connect_slot);
    app_log(app, "Connect call exception: %s. Passive accept-list listening active.", strerror(-r));
    return r;
}

static int reconnect_timer_cb(sd_event_source *s, uint64_t usec, void *userdata) {
    (void)usec;
    App *app = userdata;
    if (app->reconnect_timer == s)
        app->reconnect_timer = NULL;
    sd_event_source_unref(s);

    bool connected = false;
    if (is_connected(app, &connected) >= 0 && connected) {
        cancel_reconnect(app);
        return 0;
    }

    app_log(app, "Auto-reconnecting to Katana S K2 (retry in %us)...", app->retry_interval);
    connect_once(app);

    if (app->retry_interval < 5)
        app->retry_interval = 5;
    else if (app->retry_interval < 10)
        app->retry_interval = 10;
    else if (app->retry_interval < 30)
        app->retry_interval = 30;
    else
        app->retry_interval = 60;

    schedule_reconnect(app, app->retry_interval);
    return 0;
}

static int schedule_reconnect(App *app, unsigned delay_sec) {
    bool connected = false;
    if (is_connected(app, &connected) >= 0 && connected) {
        cancel_reconnect(app);
        return 0;
    }
    return schedule_timer(app, &app->reconnect_timer, delay_sec, reconnect_timer_cb);
}

static int read_changed_bool(sd_bus_message *m, const char *wanted, bool *found, bool *value) {
    int r = sd_bus_message_enter_container(m, SD_BUS_TYPE_ARRAY, "{sv}");
    if (r < 0)
        return r;

    while ((r = sd_bus_message_enter_container(m, SD_BUS_TYPE_DICT_ENTRY, "sv")) > 0) {
        const char *key = NULL;
        r = sd_bus_message_read(m, "s", &key);
        if (r < 0)
            return r;

        if (key && strcmp(key, wanted) == 0) {
            r = sd_bus_message_enter_container(m, SD_BUS_TYPE_VARIANT, "b");
            if (r < 0)
                return r;
            int b = 0;
            r = sd_bus_message_read(m, "b", &b);
            if (r < 0)
                return r;
            r = sd_bus_message_exit_container(m);
            if (r < 0)
                return r;
            *found = true;
            *value = b != 0;
        } else {
            r = sd_bus_message_skip(m, "v");
            if (r < 0)
                return r;
        }

        r = sd_bus_message_exit_container(m);
        if (r < 0)
            return r;
    }

    if (r < 0)
        return r;
    return sd_bus_message_exit_container(m);
}

static int on_properties_changed(sd_bus_message *m, void *userdata, sd_bus_error *ret_error) {
    (void)ret_error;
    App *app = userdata;
    const char *path = sd_bus_message_get_path(m);
    const char *interface = NULL;
    int r = sd_bus_message_read(m, "s", &interface);
    if (r < 0 || !interface || !path)
        return 0;

    bool found = false;
    bool value = false;

    if (strcmp(path, KEYBOARD_PATH) == 0 && strcmp(interface, "org.bluez.Device1") == 0) {
        if (read_changed_bool(m, "Connected", &found, &value) < 0 || !found)
            return 0;

        app_log(app, "Katana S K2 Connected property changed -> %s", value ? "true" : "false");
        if (value) {
            app->connecting = false;
            app->connect_slot = sd_bus_slot_unref(app->connect_slot);
            cancel_reconnect(app);
            schedule_ensure_xremap(app, 1);
        } else {
            app_log(app, "Katana S K2 entered idle sleep/disconnected. Arming auto-reconnect backoff...");
            schedule_reconnect(app, 2);
        }
    } else if (strcmp(path, ADAPTER_PATH) == 0 && strcmp(interface, "org.bluez.Adapter1") == 0) {
        if (read_changed_bool(m, "Powered", &found, &value) < 0 || !found || !value)
            return 0;
        app_log(app, "Bluetooth adapter powered ON. Triggering initial connect...");
        cancel_reconnect(app);
        schedule_connect(app, 1);
    }

    return 0;
}

static int on_interfaces_added(sd_bus_message *m, void *userdata, sd_bus_error *ret_error) {
    (void)ret_error;
    App *app = userdata;
    const char *path = NULL;
    if (sd_bus_message_read(m, "o", &path) < 0 || !path || strcmp(path, KEYBOARD_PATH) != 0)
        return 0;

    app_log(app, "Katana S K2 interface registered on D-Bus.");
    bool connected = false;
    if (is_connected(app, &connected) >= 0 && connected) {
        cancel_reconnect(app);
        schedule_ensure_xremap(app, 1);
    } else {
        cancel_reconnect(app);
        schedule_connect(app, 1);
    }
    return 0;
}

static int on_prepare_for_sleep(sd_bus_message *m, void *userdata, sd_bus_error *ret_error) {
    (void)ret_error;
    App *app = userdata;
    int sleeping = 0;
    if (sd_bus_message_read(m, "b", &sleeping) < 0 || sleeping)
        return 0;

    app_log(app, "System resumed from sleep. Triggering Katana connect in 1s...");
    cancel_reconnect(app);
    schedule_connect(app, 1);
    return 0;
}

static int on_session_unlock(sd_bus_message *m, void *userdata, sd_bus_error *ret_error) {
    (void)m;
    (void)ret_error;
    App *app = userdata;
    app_log(app, "Session unlocked. Re-arming Katana connect in 1s...");
    cancel_reconnect(app);
    schedule_connect(app, 1);
    return 0;
}

static int setup_log_path(App *app) {
    const char *home = getenv("HOME");
    if (!home || !*home)
        return -EINVAL;

    char state_dir[4096];
    int n = snprintf(state_dir, sizeof state_dir, "%s/.local/state", home);
    if (n < 0 || (size_t)n >= sizeof state_dir)
        return -ENAMETOOLONG;
    if (mkdir(state_dir, 0700) < 0 && errno != EEXIST)
        return -errno;

    n = snprintf(app->log_path, sizeof app->log_path, "%s/.local/state/bt-keyboard-reconnect.log", home);
    if (n < 0 || (size_t)n >= sizeof app->log_path)
        return -ENAMETOOLONG;
    return 0;
}

static int setup_buses(App *app) {
    int r = sd_event_default(&app->event);
    if (r < 0)
        return r;

    r = sd_bus_open_system(&app->system_bus);
    if (r < 0)
        return r;
    r = sd_bus_attach_event(app->system_bus, app->event, 0);
    if (r < 0)
        return r;

    r = sd_bus_open_user(&app->user_bus);
    if (r < 0) {
        app_log(app, "Warning: user D-Bus unavailable; xremap fallback restart disabled: %s", strerror(-r));
        app->user_bus = NULL;
    } else {
        r = sd_bus_attach_event(app->user_bus, app->event, 0);
        if (r < 0) {
            app_log(app, "Warning: could not attach user D-Bus to event loop: %s", strerror(-r));
            app->user_bus = sd_bus_unref(app->user_bus);
        }
    }

    r = sd_bus_add_match(
        app->system_bus,
        &app->properties_slot,
        "type='signal',sender='org.bluez',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged'",
        on_properties_changed,
        app);
    if (r < 0)
        return r;

    r = sd_bus_add_match(
        app->system_bus,
        &app->interfaces_slot,
        "type='signal',sender='org.bluez',interface='org.freedesktop.DBus.ObjectManager',member='InterfacesAdded'",
        on_interfaces_added,
        app);
    if (r < 0)
        return r;

    r = sd_bus_add_match(
        app->system_bus,
        &app->sleep_slot,
        "type='signal',sender='org.freedesktop.login1',path='/org/freedesktop/login1',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'",
        on_prepare_for_sleep,
        app);
    if (r < 0)
        return r;

    /* The previous Python daemon subscribed to a non-existent Manager.SessionUnlock
     * signal. login1 exposes Unlock on org.freedesktop.login1.Session instead. */
    r = sd_bus_add_match(
        app->system_bus,
        &app->unlock_slot,
        "type='signal',sender='org.freedesktop.login1',interface='org.freedesktop.login1.Session',member='Unlock'",
        on_session_unlock,
        app);
    return r;
}

static void app_cleanup(App *app) {
    cancel_timer(&app->reconnect_timer);
    cancel_timer(&app->ensure_timer);
    cancel_timer(&app->connect_timer);
    app->xremap_slot = sd_bus_slot_unref(app->xremap_slot);
    app->connect_slot = sd_bus_slot_unref(app->connect_slot);
    app->unlock_slot = sd_bus_slot_unref(app->unlock_slot);
    app->sleep_slot = sd_bus_slot_unref(app->sleep_slot);
    app->interfaces_slot = sd_bus_slot_unref(app->interfaces_slot);
    app->properties_slot = sd_bus_slot_unref(app->properties_slot);
    app->user_bus = sd_bus_flush_close_unref(app->user_bus);
    app->system_bus = sd_bus_flush_close_unref(app->system_bus);
    app->event = sd_event_unref(app->event);
}

static int run_check(App *app) {
    bool connected = false;
    int r = is_connected(app, &connected);
    if (r < 0) {
        fprintf(stderr, "BlueZ target check failed: %s\n", strerror(-r));
        return 1;
    }
    printf("keyboard_connected=%s\n", connected ? "yes" : "no");
    printf("xremap_attached=%s\n", connected && is_xremap_attached() ? "yes" : "no");
    printf("system_bus=ok\n");
    printf("user_bus=%s\n", app->user_bus ? "ok" : "unavailable");
    return 0;
}

int main(int argc, char **argv) {
    App app = {
        .retry_interval = 2,
    };

    if (setup_log_path(&app) < 0) {
        fprintf(stderr, "bt-keyboard-reconnect: could not initialize log path\n");
        return 1;
    }

    int r = setup_buses(&app);
    if (r < 0) {
        fprintf(stderr, "bt-keyboard-reconnect: D-Bus setup failed: %s\n", strerror(-r));
        app_cleanup(&app);
        return 1;
    }

    if (argc == 2 && strcmp(argv[1], "--check") == 0) {
        int rc = run_check(&app);
        app_cleanup(&app);
        return rc;
    }
    if (argc != 1) {
        fprintf(stderr, "usage: %s [--check]\n", argv[0]);
        app_cleanup(&app);
        return 2;
    }

    bool connected = false;
    if (is_connected(&app, &connected) >= 0 && connected) {
        app_log(&app, "Keyboard already connected at startup.");
        schedule_ensure_xremap(&app, 1);
    } else {
        app_log(&app, "Keyboard not connected at startup. Attempting initial connect...");
        connect_once(&app);
    }

    r = sd_event_loop(app.event);
    if (r < 0)
        app_log(&app, "Event loop ended with error: %s", strerror(-r));

    app_cleanup(&app);
    return r < 0 ? 1 : 0;
}
