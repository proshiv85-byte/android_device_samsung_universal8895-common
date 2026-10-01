#!/usr/bin/env python3
#
# Copyright (C) 2026 The Android Open Source Project
#
# SPDX-License-Identifier: Apache-2.0
#
"""Turn an AOSP v0 boot.img into a Samsung Exynos (S-Boot) boot image.

S-Boot on universal8895 expects:

    [header][kernel][ramdisk][second][dt.img]   (all page aligned)

where dt.img is a Samsung DTBH image (dtbtool_exynos output) and its size is
stored at header offset 40. AOSP's mkbootimg writes header_version there
(0 for v0), so with a plain AOSP image S-Boot loads no device tree at all and
the kernel runs on whatever DTB happens to be left in RAM.
"""

import argparse
import struct
import sys

BOOT_MAGIC = b"ANDROID!"
DT_SIZE_OFFSET = 40


def aligned(n, page):
    return (n + page - 1) // page * page


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--boot", required=True, help="AOSP v0 boot.img")
    ap.add_argument("--dt", required=True, help="DTBH dt.img")
    ap.add_argument("--max-size", type=int, default=0, help="partition size limit in bytes")
    ap.add_argument("-o", "--output", required=True)
    args = ap.parse_args()

    boot = bytearray(open(args.boot, "rb").read())
    dt = open(args.dt, "rb").read()

    if boot[:8] != BOOT_MAGIC:
        sys.exit("error: %s is not an Android boot image" % args.boot)
    if dt[:4] != b"DTBH":
        sys.exit("error: %s is not a DTBH image (dtbtool_exynos output)" % args.dt)

    (kernel_size, _, ramdisk_size, _, second_size, _, _, page_size,
     header_version) = struct.unpack_from("<9I", boot, 8)
    if header_version != 0:
        sys.exit("error: boot header version %d, expected 0" % header_version)

    payload_end = (page_size + aligned(kernel_size, page_size) +
                   aligned(ramdisk_size, page_size) + aligned(second_size, page_size))
    if len(boot) < payload_end:
        sys.exit("error: boot image is truncated")

    dt_padded = dt + b"\0" * (aligned(len(dt), page_size) - len(dt))
    out = boot[:payload_end] + dt_padded
    struct.pack_into("<I", out, DT_SIZE_OFFSET, len(dt_padded))

    if args.max_size and len(out) > args.max_size:
        sys.exit("error: %s is %d bytes, exceeds partition size %d by %d bytes" %
                 (args.output, len(out), args.max_size, len(out) - args.max_size))

    open(args.output, "wb").write(out)
    print("%s: kernel %d, ramdisk %d, dt %d, total %d bytes%s" %
          (args.output, kernel_size, ramdisk_size, len(dt_padded), len(out),
           " (%d bytes free)" % (args.max_size - len(out)) if args.max_size else ""))


if __name__ == "__main__":
    main()
