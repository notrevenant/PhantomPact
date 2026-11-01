# Two virtual Xbox 360 pads on the ViGEm bus, driven from a command file, for testing local co-op without hands.
# Commands in vpad_cmd.txt, one per line: "<pad 1|2> <lx> <ly> <rx> <ry> <buttons> <seconds>", or "quit".
import ctypes, struct, sys, time, os
from ctypes import wintypes as w
HERE = os.path.dirname(os.path.abspath(__file__))
CMD = os.path.join(HERE, 'vpad_cmd.txt')
k = ctypes.WinDLL('kernel32', use_last_error=True)
s = ctypes.WinDLL('setupapi', use_last_error=True)
k.CreateFileW.restype = w.HANDLE
k.CreateFileW.argtypes = [w.LPCWSTR, w.DWORD, w.DWORD, ctypes.c_void_p, w.DWORD, w.DWORD, w.HANDLE]
k.CreateEventW.restype = w.HANDLE
k.CreateEventW.argtypes = [ctypes.c_void_p, w.BOOL, w.BOOL, w.LPCWSTR]
k.DeviceIoControl.argtypes = [w.HANDLE, w.DWORD, ctypes.c_void_p, w.DWORD, ctypes.c_void_p, w.DWORD, ctypes.POINTER(w.DWORD), ctypes.c_void_p]
k.GetOverlappedResultEx.argtypes = [w.HANDLE, ctypes.c_void_p, ctypes.POINTER(w.DWORD), w.DWORD, w.BOOL]
s.SetupDiGetClassDevsW.restype = w.HANDLE
s.SetupDiGetClassDevsW.argtypes = [ctypes.c_void_p, w.LPCWSTR, w.HWND, w.DWORD]
s.SetupDiEnumDeviceInterfaces.argtypes = [w.HANDLE, ctypes.c_void_p, ctypes.c_void_p, w.DWORD, ctypes.c_void_p]
s.SetupDiGetDeviceInterfaceDetailW.argtypes = [w.HANDLE, ctypes.c_void_p, ctypes.c_void_p, w.DWORD, ctypes.POINTER(w.DWORD), ctypes.c_void_p]

class GUID(ctypes.Structure):
    _fields_ = [('a', w.DWORD), ('b', w.WORD), ('c', w.WORD), ('d', ctypes.c_ubyte * 8)]
class IFACE(ctypes.Structure):
    _fields_ = [('cb', w.DWORD), ('g', GUID), ('flags', w.DWORD), ('res', ctypes.c_size_t)]
class OV(ctypes.Structure):
    _fields_ = [('Internal', ctypes.c_size_t), ('InternalHigh', ctypes.c_size_t), ('Offset', w.DWORD), ('OffsetHigh', w.DWORD), ('hEvent', w.HANDLE)]

BUS = GUID(0x96E42B22, 0xF5E9, 0x42F8, (ctypes.c_ubyte * 8)(0xB0, 0x43, 0xED, 0x0F, 0x93, 0x2F, 0x01, 0x4F))

def ioctl_code(fn):
    return (0x2A << 16) | (2 << 14) | (fn << 2)
BASE = 0x801
PLUG, UNPLUG, VERSION, READY, SUBMIT = [ioctl_code(BASE + x) for x in (0, 1, 2, 3, 0x201)]

def paths():
    h = s.SetupDiGetClassDevsW(ctypes.byref(BUS), None, None, 0x12)
    out, i = [], 0
    while True:
        d = IFACE(); d.cb = ctypes.sizeof(IFACE)
        if not s.SetupDiEnumDeviceInterfaces(h, None, ctypes.byref(BUS), i, ctypes.byref(d)):
            break
        need = w.DWORD(0)
        s.SetupDiGetDeviceInterfaceDetailW(h, ctypes.byref(d), None, 0, ctypes.byref(need), None)
        buf = ctypes.create_string_buffer(need.value)
        struct.pack_into('<I', buf, 0, 8)
        if s.SetupDiGetDeviceInterfaceDetailW(h, ctypes.byref(d), buf, need.value, None, None):
            out.append(ctypes.wstring_at(ctypes.addressof(buf) + 4))
        i += 1
    return out

class Bus:
    def __init__(self, path):
        self.h = k.CreateFileW(path, 0xC0000000, 3, None, 3, 0x80 | 0x40000000 | 0x20000000 | 0x80000000, None)
        if self.h in (None, w.HANDLE(-1).value):
            raise OSError(ctypes.get_last_error())
        self.ev = k.CreateEventW(None, True, False, None)

    def call(self, code, data, wait_ms=3000):
        o = OV(); o.hEvent = self.ev
        k.ResetEvent(w.HANDLE(self.ev))
        got = w.DWORD(0)
        buf = ctypes.create_string_buffer(data, len(data))
        ok = k.DeviceIoControl(self.h, code, buf, len(data), buf, len(data), ctypes.byref(got), ctypes.byref(o))
        err = ctypes.get_last_error()
        if not ok and err == 997:
            ok = k.GetOverlappedResultEx(self.h, ctypes.byref(o), ctypes.byref(got), wait_ms, False)
            err = ctypes.get_last_error()
        return (bool(ok), err)

def main():
    ps = paths()
    print('bus paths', ps, flush=True)
    pads = []
    for p in ps:
        try:
            bus = Bus(p)
        except OSError as e:
            print('open failed', e, flush=True); continue
        print('version', bus.call(VERSION, struct.pack('<II', 8, 1)), flush=True)
        for serial in range(1, 12):
            if len(pads) == 2:
                break
            r = bus.call(PLUG, struct.pack('<IIiHH', 16, serial, 0, 0x045E, 0x028E))
            print('plug', serial, r, flush=True)
            if r[0]:
                print('ready', bus.call(READY, struct.pack('<II', 8, serial), 5000), flush=True)
                pads.append((bus, serial))
        if len(pads) == 2:
            break
    if len(pads) < 2:
        print('FAILED: pads', len(pads), flush=True)
        return 1
    state = {1: [0, 0, 0, 0, 0, 0.0], 2: [0, 0, 0, 0, 0, 0.0]}
    def send(n):
        bus, serial = pads[n - 1]
        lx, ly, rx, ry, b, _ = state[n]
        report = struct.pack('<HBBhhhh', b, 0, 0, lx, ly, rx, ry)
        return bus.call(SUBMIT, struct.pack('<II', 20, serial) + report, 500)
    print('READY', flush=True)
    open(os.path.join(HERE, 'vpad_ready.txt'), 'w').write('1')
    try:
        while True:
            if os.path.exists(CMD):
                lines = open(CMD).read().split('\n')
                os.remove(CMD)
                for ln in lines:
                    a = ln.split()
                    if not a:
                        continue
                    if a[0] == 'quit':
                        return 0
                    n = int(a[0]); v = [int(x) for x in a[1:6]]
                    state[n] = v + [time.time() + float(a[6])]
                    print('cmd', ln, send(n), flush=True)
            now = time.time()
            for n in (1, 2):
                if state[n][5] and now > state[n][5]:
                    state[n] = [0, 0, 0, 0, 0, 0.0]
                send(n)
            time.sleep(0.02)
    finally:
        for bus, serial in pads:
            print('unplug', serial, bus.call(UNPLUG, struct.pack('<II', 8, serial)), flush=True)

sys.exit(main())
