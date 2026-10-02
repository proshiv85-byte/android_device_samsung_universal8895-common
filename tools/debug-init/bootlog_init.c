// Debug-only /init wrapper for bring-up of devices whose boot failures end in
// a cold reset (RAM, last_kmsg and pstore are lost).
//
// Stays PID 1, forks a logger that streams /dev/kmsg to the start of the CACHE
// partition, and runs the real Android init (/init.real) as a child. If that
// child dies, the kernel does not panic: we log its exit status, let the
// logger flush, then reboot to recovery. Read the log back from recovery with:
//   dd if=/dev/block/by-name/CACHE bs=1M count=8 | strings
//
// Build: aarch64-linux-gnu-gcc -static -O2 -o init bootlog_init.c

#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <linux/reboot.h>
#include <string.h>
#include <sys/klog.h>
#include <sys/mount.h>
#include <sys/syscall.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <sys/sysmacros.h>
#include <sys/types.h>
#include <unistd.h>

#define CACHE_SYSFS "/dbgsys/class/block/sda21/dev"
#define CACHE_NODE "/dbgcache"

static int open_cache(void) {
    mkdir("/dbgsys", 0755);
    if (mount("sysfs", "/dbgsys", "sysfs", 0, NULL) != 0) return -1;

    char buf[32] = {0};
    for (int i = 0; i < 200; i++) {  // UFS may still be probing: wait up to 20 s
        int fd = open(CACHE_SYSFS, O_RDONLY);
        if (fd >= 0) {
            read(fd, buf, sizeof(buf) - 1);
            close(fd);
            break;
        }
        usleep(100 * 1000);
    }
    umount("/dbgsys");

    unsigned maj, min;
    if (sscanf(buf, "%u:%u", &maj, &min) != 2) return -1;
    unlink(CACHE_NODE);
    if (mknod(CACHE_NODE, S_IFBLK | 0600, makedev(maj, min)) != 0) return -1;
    int fd = open(CACHE_NODE, O_RDWR | O_CLOEXEC);
    unlink(CACHE_NODE);
    return fd;
}

static void logger(int kmsg) {
    signal(SIGTERM, SIG_IGN);
    signal(SIGHUP, SIG_IGN);
    int out = open_cache();
    if (out < 0 || kmsg < 0) _exit(1);

    // Stream /dev/kmsg to CACHE: drain all available records, write them in
    // one go and fdatasync, then wait for more. Survives panics/cold resets.
    static char buf[4 << 20];
    int fl = fcntl(kmsg, F_GETFL);
    fcntl(kmsg, F_SETFL, fl | O_NONBLOCK);
    off_t off = 0;
    const char hdr[] = "BOOTLOG-STREAM\n";
    pwrite(out, hdr, sizeof(hdr) - 1, 0);
    off = sizeof(hdr) - 1;
    for (;;) {
        size_t len = 0;
        for (;;) {
            if (len > sizeof(buf) - 8192) break;
            ssize_t n = read(kmsg, buf + len, sizeof(buf) - len);
            if (n > 0) { len += n; continue; }
            if (n < 0 && errno == EPIPE) continue;  // records overwritten
            break;                                  // EAGAIN: drained
        }
        if (len) {
            pwrite(out, buf, len, off);
            off += len;
            pwrite(out, "BOOTLOG-END\n", 12, off);
            fdatasync(out);
            if (off > 64 << 20) _exit(0);
        } else {
            struct pollfd p = {.fd = kmsg, .events = POLLIN};
            poll(&p, 1, 200);
        }
    }
}

// Write the whole kernel log buffer to CACHE at 32 MiB, independent of the
// streaming logger.
static int final_fd = -1;
static off_t final_off = 32 << 20;

// Rotate through 8 slots of 4 MiB (at 32 MiB + slot * 4 MiB) so the logs of
// the previous boots survive the boot used to enter recovery. A boot counter
// lives at 31 MiB.
static void pick_slot(void) {
    char hdr[64] = {0};
    unsigned n = 0;
    if (pread(final_fd, hdr, sizeof(hdr) - 1, 31 << 20) > 0) sscanf(hdr, "BOOTLOG-COUNTER %u", &n);
    n++;
    int len = snprintf(hdr, sizeof(hdr), "BOOTLOG-COUNTER %u\n", n);
    pwrite(final_fd, hdr, len, 31 << 20);
    fdatasync(final_fd);
    final_off = (32 << 20) + (off_t)(n % 8) * (4 << 20);
}

static void dump_klog_final(void) {
    int size = klogctl(10 /* SYSLOG_ACTION_SIZE_BUFFER */, NULL, 0);
    if (size <= 0) size = 4 << 20;
    static char* log;
    if (!log) log = malloc(size);
    if (!log) return;
    int n = klogctl(3 /* SYSLOG_ACTION_READ_ALL */, log, size);
    int out = final_fd;
    if (out < 0 || n <= 0) return;
    if (n > (4 << 20) - 64) n = (4 << 20) - 64;
    const char hdr[] = "BOOTLOG-FINAL\n";
    pwrite(out, hdr, sizeof(hdr) - 1, final_off);
    pwrite(out, log, n, final_off + sizeof(hdr) - 1);
    pwrite(out, "\nBOOTLOG-FINAL-END\n", 19, final_off + sizeof(hdr) - 1 + n);
    fdatasync(out);
}

static void kmsg_note(const char* msg) {
    int fd = open("/dev/kmsg", O_WRONLY | O_CLOEXEC);
    if (fd >= 0) {
        write(fd, msg, strlen(msg));
        close(fd);
    }
}

int main(int argc, char** argv) {
    (void)argc;
    if (getpid() != 1) {
        argv[0] = "/init";
        execv("/init.real", argv);
        return 127;
    }

    // Open the ramdisk's /dev/kmsg node now: first stage init mounts a tmpfs
    // over /dev right away.
    int kmsg = open("/dev/kmsg", O_RDONLY | O_CLOEXEC);
    (void)kmsg;  // streaming logger disabled; periodic snapshots below
    final_fd = open_cache();
    if (final_fd >= 0) pick_slot();

    // Keep PID 1 ourselves and run Android init as a child, so that if it
    // crashes (or oopses) the kernel does not panic and the logger can flush.
    pid_t child = fork();
    if (child == 0) {
        argv[0] = "/init";
        execv("/init.real", argv);
        _exit(127);
    }

    // Snapshot the whole kernel log buffer to CACHE every 300 ms, so the last
    // messages before any reboot (even one requested by Android init itself)
    // are on disk.
    for (;;) {
        int status;
        pid_t p = waitpid(-1, &status, WNOHANG);
        if (p == child) {
            char msg[128];
            snprintf(msg, sizeof(msg), "<0>BOOTLOG: android init exited, status=0x%x (%s %d)\n",
                     status, WIFSIGNALED(status) ? "signal" : "exit",
                     WIFSIGNALED(status) ? WTERMSIG(status) : WEXITSTATUS(status));
            kmsg_note(msg);
            dump_klog_final();
            sleep(2);
            dump_klog_final();
            sync();
            syscall(SYS_reboot, LINUX_REBOOT_MAGIC1, LINUX_REBOOT_MAGIC2,
                    LINUX_REBOOT_CMD_RESTART2, "recovery");
        }
        dump_klog_final();
        usleep(300 * 1000);
    }
}
