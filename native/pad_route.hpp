// Two joysticks on one PC. The engine maps every joystick to Windows user 0, so all of them reach player 1. Its
// bOffsetPlayerGamepadIds setting moves them to player 2 instead, all of them, and while it's on player 1 gets no stick
// input at all. So the setting stays off, and is turned on only while player 2's joystick event goes through the viewport.
// Those are virtual calls: the viewport object's vtable pointer is swapped for a copy in our own memory, so nothing in the
// game's code changes.
//   vp.txt         written by the mod: the GameViewportClient's address, then the setting's. Removed once taken
//   pad_stay.txt   written by the mod: the input device on player 1 (absent: no routing, the setting is left alone)
#pragma once
#include "relay.hpp"
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

namespace route {

constexpr int TABLE_OFFSET = 0x28;                  // FViewportClient inside UGameViewportClient
constexpr int INPUT_KEY_SLOT = 8, INPUT_AXIS_SLOT = 9;   // found by counting calls on this build
constexpr int DEVICE_AT = 0x0C;                     // in FInputKeyEventArgs
constexpr int MAX_TABLE = 256;
constexpr int MIN_TABLE = INPUT_AXIS_SLOT + 1;
constexpr DWORD POLL_MS = 40;                       // a menu closing hands the pads back within a frame or two
constexpr USHORT GENERIC_PAGE = 0x01, JOYSTICK = 0x04, GAMEPAD = 0x05, MULTI_AXIS = 0x08;

using Input = ULONG_PTR(*)(void*, BYTE*, void*, void*);

volatile LONG xinput_pads = 0;                      // set by pads_thread

Input real_key = nullptr, real_axis = nullptr;
volatile LONG stay = -1;
volatile BYTE* offset_setting = nullptr;

bool is_mover(const BYTE* args) {
    const LONG keep = stay;
    if (keep < 0 || !offset_setting) return false;
    __try {
        return *reinterpret_cast<const int*>(args + DEVICE_AT) == 3 - keep;
    } __except (EXCEPTION_EXECUTE_HANDLER) {
        return false;
    }
}

ULONG_PTR call(Input real, void* self, BYTE* args, void* a3, void* a4) {
    if (!is_mover(args)) return real(self, args, a3, a4);
    *offset_setting = 1;
    const ULONG_PTR result = real(self, args, a3, a4);
    *offset_setting = 0;
    return result;
}

ULONG_PTR input_key(void* self, BYTE* args, void* a3, void* a4) {
    return call(real_key, self, args, a3, a4);
}

ULONG_PTR input_axis(void* self, BYTE* args, void* a3, void* a4) {
    return call(real_axis, self, args, a3, a4);
}

bool executable(const void* p) {
    MEMORY_BASIC_INFORMATION m{};
    if (!VirtualQuery(p, &m, sizeof m) || m.State != MEM_COMMIT) return false;
    return (m.Protect & (PAGE_EXECUTE | PAGE_EXECUTE_READ | PAGE_EXECUTE_READWRITE | PAGE_EXECUTE_WRITECOPY)) != 0;
}

bool install(unsigned long long viewport) {
    auto* holder = reinterpret_cast<ULONG_PTR*>(viewport + TABLE_OFFSET);
    auto* table = reinterpret_cast<ULONG_PTR*>(*holder);
    int n = 0;
    while (n < MAX_TABLE && executable(reinterpret_cast<void*>(table[n]))) n++;
    if (n < MIN_TABLE) return false;
    auto* copy = static_cast<ULONG_PTR*>(VirtualAlloc(nullptr, (n + 1) * sizeof(ULONG_PTR), MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE));
    if (!copy) return false;
    copy[0] = table[-1];                            // the RTTI pointer
    std::memcpy(copy + 1, table, n * sizeof(ULONG_PTR));
    real_key = reinterpret_cast<Input>(table[INPUT_KEY_SLOT]);
    real_axis = reinterpret_cast<Input>(table[INPUT_AXIS_SLOT]);
    copy[1 + INPUT_KEY_SLOT] = reinterpret_cast<ULONG_PTR>(&input_key);
    copy[1 + INPUT_AXIS_SLOT] = reinterpret_cast<ULONG_PTR>(&input_axis);
    InterlockedExchangePointer(reinterpret_cast<void**>(holder), copy + 1);
    return true;
}

// The game also reads PlayStation pads as raw Windows input, and that always lands on player 1. With a tool like
// DS4Windows the same pad then arrives twice, which also makes the game flip between input types and stutter.
void drop_raw_gamepads(const std::wstring& log) {
    UINT count = 0;
    GetRegisteredRawInputDevices(nullptr, &count, sizeof(RAWINPUTDEVICE));
    if (!count) return;
    std::vector<RAWINPUTDEVICE> devices(count);
    const UINT got = GetRegisteredRawInputDevices(devices.data(), &count, sizeof(RAWINPUTDEVICE));
    if (got == static_cast<UINT>(-1)) return;
    for (UINT i = 0; i < got; i++) {
        const USHORT usage = devices[i].usUsage;
        if (devices[i].usUsagePage != GENERIC_PAGE || (usage != JOYSTICK && usage != GAMEPAD && usage != MULTI_AXIS)) continue;
        RAWINPUTDEVICE remove{GENERIC_PAGE, usage, RIDEV_REMOVE, nullptr};
        const BOOL ok = RegisterRawInputDevices(&remove, 1, sizeof remove);
        relay::append_lines(log, {"raw usage " + std::to_string(usage) + (ok ? " removed" : " NOT removed, error " + std::to_string(GetLastError()))});
    }
}

LONG read_stay(const std::wstring& path) {
    FILE* f = nullptr;
    if (_wfopen_s(&f, path.c_str(), L"r") != 0 || !f) return -1;
    long value = -1;
    fscanf_s(f, "%ld", &value);
    fclose(f);
    return value;
}

DWORD WINAPI watch(void* dir_) {
    const std::wstring dir = *static_cast<std::wstring*>(dir_);
    const std::wstring address_file = dir + L"\\vp.txt", stay_file = dir + L"\\pad_stay.txt";
    DeleteFileW(address_file.c_str());              // a crashed run's addresses mean nothing now
    while (GetFileAttributesW(address_file.c_str()) == INVALID_FILE_ATTRIBUTES) Sleep(POLL_MS);
    Sleep(POLL_MS);
    unsigned long long viewport = 0, setting = 0;
    FILE* f = nullptr;
    if (_wfopen_s(&f, address_file.c_str(), L"r") == 0 && f) {
        fscanf_s(f, "%llu %llu", &viewport, &setting);
        fclose(f);
    }
    DeleteFileW(address_file.c_str());
    if (!viewport || !setting) return 0;
    offset_setting = reinterpret_cast<volatile BYTE*>(setting);
    if (!install(viewport)) return 0;
    const std::wstring log = dir + L"\\pad_route_log.txt";
    DeleteFileW(log.c_str());
    while (true) {
        Sleep(POLL_MS);
        stay = read_stay(stay_file);
        if (xinput_pads > 0) drop_raw_gamepads(log);
    }
}

}  // namespace route
