#!/usr/bin/env python3
"""Reliably REMOVE the code signature from an arm64 Mach-O dylib so the install
tool (Sideloadly) re-signs it with the app's identity. Removing LC_CODE_SIGNATURE,
truncating the signature bytes, shrinking __LINKEDIT, and clearing MH_NOUNDEFS."""
import struct, sys

def strip(path):
    d = bytearray(open(path, "rb").read())
    magic, cpu, sub, ftype, ncmds, sizeofcmds, flags, res = struct.unpack_from("<IIIIIIII", d, 0)
    if flags & 0x1:
        flags &= ~0x1
        struct.pack_into("<I", d, 24, flags)
        print(f"  cleared MH_NOUNDEFS -> {hex(flags)}")
    off = 32; cs_off = cs_dataoff = cs_datasize = None; le_off = None
    for _ in range(ncmds):
        cmd, cmdsize = struct.unpack_from("<II", d, off)
        if cmd == 0x1d:
            cs_off = off
            cs_dataoff, cs_datasize = struct.unpack_from("<II", d, off + 8)
        elif cmd == 0x19:
            if d[off+8:off+24].split(b"\0")[0] == b"__LINKEDIT":
                le_off = off
        off += cmdsize
    if cs_off is None:
        print("  already UNSIGNED (no LC_CODE_SIGNATURE)."); open(path,"wb").write(d); return
    # shrink __LINKEDIT to end at the signature start
    if le_off is not None:
        le_vmaddr, le_vmsize, le_fileoff, le_filesize = struct.unpack_from("<QQQQ", d, le_off + 24)
        new_fs = cs_dataoff - le_fileoff
        new_vs = (new_fs + 0x3fff) & ~0x3fff
        struct.pack_into("<Q", d, le_off + 32, new_vs)  # vmsize  @ seg+32
        struct.pack_into("<Q", d, le_off + 48, new_fs)  # filesize @ seg+48
        print(f"  __LINKEDIT filesize {le_filesize} -> {new_fs}, vmsize -> {new_vs}")
    # remove the LC_CODE_SIGNATURE load command
    after = cs_off + 16
    end = 32 + sizeofcmds
    d[cs_off:end-16] = d[after:end]
    d[end-16:end] = b"\x00" * 16
    ncmds -= 1; sizeofcmds -= 16
    struct.pack_into("<I", d, 16, ncmds)
    struct.pack_into("<I", d, 20, sizeofcmds)
    # truncate the signature bytes off the file end
    del d[cs_dataoff:]
    open(path, "wb").write(d)
    print(f"  stripped LC_CODE_SIGNATURE; new size={len(d)} bytes")

if __name__ == "__main__":
    for p in sys.argv[1:]:
        print(f"[strip] {p}"); strip(p)
