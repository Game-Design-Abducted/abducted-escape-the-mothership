"""Convert Fah's big 1001x1001 sprite exports into crisp 64x64 game sprites.

Usage (from the project folder):
    python tools/convert_sprites.py art_source/hires_sprites assets/sprites

Fah's art is drawn on a 32x32 pixel grid, so sampling the centre of each grid
cell gives an exact, lossless copy. Pure Python, no extra installs needed.
"""
import glob, os, struct, sys, zlib
def read_png(path):
    d = open(path, 'rb').read(); assert d[:8] == b'\x89PNG\r\n\x1a\n'
    i = 8; idat = b''; plte = None; trns = None
    while i < len(d):
        L = struct.unpack('>I', d[i:i+4])[0]; t = d[i+4:i+8]; c = d[i+8:i+8+L]; i += 12 + L
        if t == b'IHDR': w, h, bd, ct, _, _, il = struct.unpack('>IIBBBBB', c)
        elif t == b'PLTE': plte = c
        elif t == b'tRNS': trns = c
        elif t == b'IDAT': idat += c
    assert bd == 8 and il == 0, (bd, il)
    ch = {6: 4, 2: 3, 0: 1, 4: 2, 3: 1}[ct]
    raw = zlib.decompress(idat); stride = w * ch; out = []; prev = bytearray(stride); p = 0
    for y in range(h):
        f = raw[p]; line = bytearray(raw[p+1:p+1+stride]); p += 1 + stride
        for x in range(stride):
            a = line[x-ch] if x >= ch else 0; b = prev[x]; c = prev[x-ch] if x >= ch else 0
            if f == 1: line[x] = (line[x] + a) & 255
            elif f == 2: line[x] = (line[x] + b) & 255
            elif f == 3: line[x] = (line[x] + (a + b) // 2) & 255
            elif f == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2*c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        out.append(bytes(line)); prev = line
    px = []
    for row in out:
        r = []
        for x in range(w):
            s = row[x*ch:(x+1)*ch]
            if ct == 6: r.append(tuple(s))
            elif ct == 2: r.append((*s, 255))
            elif ct == 0: r.append((s[0], s[0], s[0], 255))
            elif ct == 4: r.append((s[0], s[0], s[0], s[1]))
            else:
                k = s[0]; a = trns[k] if trns and k < len(trns) else 255
                r.append((plte[3*k], plte[3*k+1], plte[3*k+2], a))
        px.append(r)
    return w, h, px
def write_png(path, w, h, px):
    raw = b''.join(b'\x00' + b''.join(bytes(p) for p in row) for row in px)
    def chunk(t, d): return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    open(path, 'wb').write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))


BLOCK = 1001 / 64   # 32-cell art grid on a 1001 px canvas, sampled at 64 to keep half-cell detail


def main(src_dir, dst_dir):
    for f in sorted(glob.glob(os.path.join(src_dir, '*.png'))):
        w, h, px = read_png(f)
        nw, nh = max(1, round(w / BLOCK)), max(1, round(h / BLOCK))
        out = [[px[min(h - 1, int((j + 0.5) * h / nh))][min(w - 1, int((i + 0.5) * w / nw))]
                for i in range(nw)] for j in range(nh)]
        write_png(os.path.join(dst_dir, os.path.basename(f)), nw, nh, out)
        print(f'{os.path.basename(f):24s} {w}x{h} -> {nw}x{nh}')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
