"""Reads a LandSandBoat Detour navmesh (.nav, 32-bit poly refs) and answers: is this FFXI position on walkable ground,
and at what height? Detour stores (x, -y, -z) of the game's coordinates (src/map/navmesh/detour_navmesh.cpp toDetour)."""
import math
import struct

SET_MAGIC = ord('M') << 24 | ord('S') << 16 | ord('E') << 8 | ord('T')


class NavMesh:
    def __init__(self, path):
        data = open(path, 'rb').read()
        magic, _version, ntiles = struct.unpack_from('<iii', data, 0)
        if magic != SET_MAGIC:
            raise ValueError('not a navmesh set file: ' + path)
        off = 12 + 28
        self.polys = []   # (triangles [(a, b, c) detour points], (minx, minz), (maxx, maxz))
        for _ in range(ntiles):
            _ref, size = struct.unpack_from('<Ii', data, off)
            off += 8
            self._tile(data[off:off + size])
            off += size

    def _tile(self, t):
        h = struct.unpack_from('<4s i 13i 10f', t, 0)
        if h[0] not in (b'DNAV', b'VAND'):
            raise ValueError('bad tile')
        pc, vc, ml, dm, dv, dt, bv, om = h[6:14]
        expected = 100 + vc * 12 + pc * 32 + ml * 12 + dm * 12 + dv * 12 + dt * 4 + bv * 16 + om * 36
        if expected != len(t):
            raise ValueError('unexpected tile layout (64-bit poly refs?)')
        off = 100
        verts = [struct.unpack_from('<3f', t, off + i * 12) for i in range(vc)]
        off += vc * 12
        polys = [struct.unpack_from('<I6H6HHBB', t, off + i * 32) for i in range(pc)]
        off += pc * 32 + ml * 12
        details = [struct.unpack_from('<IIBB', t, off + i * 12) for i in range(dm)]
        off += dm * 12
        dverts = [struct.unpack_from('<3f', t, off + i * 12) for i in range(dv)]
        off += dv * 12
        dtris = [struct.unpack_from('<4B', t, off + i * 4) for i in range(dt)]
        for i, p in enumerate(polys):
            nv = p[14]
            if (p[15] >> 6) != 0 or i >= dm:   # off-mesh connection
                continue
            pv = [verts[p[1 + k]] for k in range(nv)]
            vbase, tbase, _dvc, tcount = details[i]

            def vert(idx):
                return pv[idx] if idx < nv else dverts[vbase + idx - nv]
            tris = [(vert(a), vert(b), vert(c)) for a, b, c, _f in dtris[tbase:tbase + tcount]]
            xs = [v[0] for v in pv]
            zs = [v[2] for v in pv]
            self.polys.append((tris, (min(xs), min(zs)), (max(xs), max(zs))))

    @staticmethod
    def _tri_height(tri, x, z):
        (x0, y0, z0), (x1, y1, z1), (x2, y2, z2) = tri
        d = (z1 - z2) * (x0 - x2) + (x2 - x1) * (z0 - z2)
        if abs(d) < 1e-9:
            return None
        a = ((z1 - z2) * (x - x2) + (x2 - x1) * (z - z2)) / d
        b = ((z2 - z0) * (x - x2) + (x0 - x2) * (z - z2)) / d
        c = 1 - a - b
        if a >= -1e-5 and b >= -1e-5 and c >= -1e-5:
            return a * y0 + b * y1 + c * y2
        return None

    def height(self, x, y, z, tol=2.5):
        """FFXI (x, y, z) -> walkable FFXI y at that spot (closest floor to y), or None."""
        dx, dy, dz = x, -y, -z
        best = None
        for tris, mn, mx in self.polys:
            if not (mn[0] - 1e-3 <= dx <= mx[0] + 1e-3 and mn[1] - 1e-3 <= dz <= mx[1] + 1e-3):
                continue
            for tri in tris:
                hy = self._tri_height(tri, dx, dz)
                if hy is not None and abs(hy - dy) <= tol and (best is None or abs(hy - dy) < abs(best - dy)):
                    best = hy
        return None if best is None else -best

    def clear(self, x, y, z, radius=0.8):
        """Walkable here and on 8 points around it (so not hugging a wall or a ledge). Returns the height or None."""
        h = self.height(x, y, z)
        if h is None:
            return None
        for k in range(8):
            a = k * math.pi / 4
            ring = self.height(x + radius * math.cos(a), h, z + radius * math.sin(a), tol=0.6)
            if ring is None:
                return None
        return h
