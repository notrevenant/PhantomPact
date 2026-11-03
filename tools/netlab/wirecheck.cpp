// Proof that two players' traffic didn't change: wirecheck.ps1 builds this twice, against two versions of native/, and
// compares what they print. It runs a fixed two-player session in simulated time, through a seeded bad connection, and writes
// every packet out section by section. Only what depends on the real clock is left out of each line: session numbers
// are shown by the order they first appeared, and the time fields not at all.
#include "relay.hpp"

#include <cstdarg>
#include <queue>
#include <random>

namespace {

using relay::Addr;

Addr at(uint32_t ip) {
    Addr a;
    a.ip = ip;
    a.port = 1000;
    return a;
}

std::map<uint32_t, int> session_numbers;

int number(uint32_t session) {
    if (session == 0) return 0;
    auto [it, fresh] = session_numbers.emplace(session, static_cast<int>(session_numbers.size()) + 1);
    return it->second;
}

template <typename T>
T take(std::string_view& d) {
    T v{};
    if (d.size() < sizeof v) {
        d = {};
        return v;
    }
    std::memcpy(&v, d.data(), sizeof v);
    d.remove_prefix(sizeof v);
    return v;
}

std::string_view take_text(std::string_view& d) {
    const auto n = take<uint16_t>(d);
    std::string_view s = d.substr(0, n);
    d.remove_prefix(s.size());
    return s;
}

void dump(FILE* out, double now, uint32_t from, const std::string& packet) {
    std::string_view d = packet;
    const auto marker = take<uint8_t>(d), protocol = take<uint8_t>(d), flags = take<uint8_t>(d);
    const auto session = take<uint32_t>(d), view = take<uint32_t>(d);
    const auto sequence = take<uint16_t>(d);
    take<uint32_t>(d);      // sent at
    take<uint32_t>(d);      // echoed
    take<uint16_t>(d);      // held
    const auto ack = take<uint32_t>(d), bits = take<uint32_t>(d);
    std::fprintf(out, "%.3f from%u size=%zu m=%d p=%d f=%d s=%d v=%d q=%d ack=%u/%u", now, from, packet.size(), marker, protocol, flags, number(session), number(view), sequence, ack, bits);
    while (!d.empty()) {
        const auto section = take<uint8_t>(d);
        if (section == relay::SEC_STATE) {
            std::fprintf(out, " STATE");
            for (char c : d.substr(0, 40)) std::fprintf(out, "%02x", static_cast<unsigned char>(c));
            d.remove_prefix(std::min<size_t>(40, d.size()));
        } else if (section == relay::SEC_SURE) {
            const auto id = take<uint32_t>(d);
            const auto text = take_text(d);
            std::fprintf(out, " SURE%u[%.*s]", id, static_cast<int>(text.size()), text.data());
        } else if (section == relay::SEC_QUICK) {
            const auto id = take<uint32_t>(d);
            const auto age = take<uint16_t>(d);
            const auto text = take_text(d);
            std::fprintf(out, " QUICK%u+%u[%.*s]", id, age, static_cast<int>(text.size()), text.data());
        } else if (section == relay::SEC_ENEMY) {
            const auto text = take_text(d);
            std::fprintf(out, " ENEMY[%.*s]", static_cast<int>(text.size()), text.data());
        } else if (section == relay::SEC_HELLO) {
            std::string text(take_text(d));
            std::replace(text.begin(), text.end(), '\n', '|');
            std::fprintf(out, " HELLO[%s]", text.c_str());
        } else {
            std::fprintf(out, " UNKNOWN%u", section);
            break;
        }
    }
    std::fputc('\n', out);
}

struct Net {
    struct Packet {
        double at;
        long long order;
        Addr from;
        std::string data;
        bool operator<(const Packet& o) const { return at != o.at ? at > o.at : order > o.order; }
    };
    double now = 1000, delay = 0.01, jitter = 0.01, loss = 0;
    long long order = 0;
    std::map<uint32_t, std::priority_queue<Packet>> wires;
    std::mt19937 rng{2026};
    FILE* out = nullptr;

    double unit() { return std::uniform_real_distribution<double>(0, 1)(rng); }

    void send(const Addr& from, const Addr& to, const std::string& data) {
        dump(out, now, from.ip, data);
        if (unit() < loss) return;
        wires[to.ip].push({now + delay + unit() * jitter, order++, from, data});
    }

    std::vector<std::pair<Addr, std::string>> take_for(uint32_t ip) {
        std::vector<std::pair<Addr, std::string>> got;
        auto& wire = wires[ip];
        while (!wire.empty() && wire.top().at <= now) {
            got.emplace_back(wire.top().from, wire.top().data);
            wire.pop();
        }
        return got;
    }
};

class Wire : public relay::Link {
public:
    Wire(Net& net, const Addr& me, std::optional<Addr> host) : net_(net), me_(me) { peer = host; }
    void send(const Addr& to, const std::string& data) override { net_.send(me_, to, data); }
    std::vector<std::pair<Addr, std::string>> receive() override { return net_.take_for(me_.ip); }
    void wait(double, HANDLE) override {}
    std::string describe(const Addr& a) override { return "pc" + std::to_string(a.ip); }
    std::string describe_self() override { return "pc" + std::to_string(me_.ip); }
    const char* via() override { return "wire"; }

private:
    Net& net_;
    Addr me_;
};

relay::Sample sample(double t, float side) {
    relay::Sample s;
    s.ms = static_cast<uint32_t>(t * 1000);
    s.x = static_cast<float>(side + std::cos(t) * 1000);
    s.y = static_cast<float>(std::sin(t) * 1000);
    s.z = 12.5f;
    s.yaw = static_cast<float>(std::fmod(t * 40, 360.0));
    s.vx = 100;
    s.vy = -100;
    s.hp = 850;
    s.max_hp = 1200;
    s.map = 0xDEADBEEF;
    s.flags = 1;
    return s;
}

}  // namespace

int wmain(int argc, wchar_t** argv) {
    if (argc < 2) return 2;
    FILE* out = _wfopen(argv[1], L"w");
    Net net;
    net.out = out;
    const relay::Settings host_ini{{"pvp", "On"}, {"coopenemyhealth", "150"}, {"coopenemyposture", "130"}, {"role", "host"}, {"fourplayers", "off"}};
    const relay::Settings guest_ini{{"pvp", "Off"}, {"coopenemyhealth", "150"}, {"role", "guest"}};
    const auto quiet = [](const std::string&) {};
    relay::Mailbox host_box, guest_box;
    relay::Relay host("host", L".", std::make_unique<Wire>(net, at(1), std::nullopt), host_ini, "1.4.2", quiet, host_box);
    relay::Relay guest("client", L".", std::make_unique<Wire>(net, at(2), at(1)), guest_ini, "1.4.2", quiet, guest_box);
    int n = 0;
    std::string read_host, read_guest;
    const auto step = [&](double seconds) {
        const double end = net.now + seconds;
        while (net.now < end) {
            net.now += 0.005;
            n++;
            host.tick(net.now);
            guest.tick(net.now);
            read_host += host_box.take_events(relay::clock_ms()) + host_box.take_enemies();
            read_guest += guest_box.take_events(relay::clock_ms()) + guest_box.take_enemies();
            if (n % 3 == 0) {
                host_box.post_sample(sample(net.now, 0));
                guest_box.post_sample(sample(net.now, 5000));
            }
            if (n % 20 == 0) {
                char line[64];
                std::snprintf(line, sizeof line, "%d 1 2 3 90 0 0 500.0 600.0 0 40.0", n / 20 % 11);
                host_box.post_enemy(line);
            }
        }
    };
    host_box.post_map("Map_Xigu");
    guest_box.post_map("Map_Xigu");
    step(1);
    for (int i = 0; i < 200; i++) {
        host_box.post_sure("K sp:enemy" + std::to_string(i));
        guest_box.post_sure("D sp:enemy" + std::to_string(i) + " 10.0 2.0 -");
        host_box.post_quick("A sp:enemy /Game/Move.Move_C - 0.10 guest");
        guest_box.post_quick("U /Game/Move.Move 0.25");
        step(0.05);
    }
    net.loss = 0.2;
    for (int i = 0; i < 100; i++) {
        host_box.post_sure("C " + std::to_string(i));
        guest_box.post_sure("T R_" + std::to_string(i) + " 1 -");
        step(0.03);
    }
    net.loss = 0;
    step(1);
    guest_box.reset();
    guest_box.post_sure("after the guest's restart");
    step(1);
    host_box.reset();
    host_box.post_sure("after the host's restart");
    step(1);
    host_box.post_map("Map_Other");
    step(3);
    net.loss = 1;       // the partner goes silent
    step(4);
    net.loss = 0;
    step(2);
    std::fprintf(out, "HOST READ %zu bytes, GUEST READ %zu bytes\n", read_host.size(), read_guest.size());
    std::fputs(read_host.c_str(), out);
    std::fputs(read_guest.c_str(), out);
    // What's left of the status line once the real clock's numbers are taken out of it.
    for (relay::Relay* r : {&host, &guest}) {
        std::string line = r->status(net.now);
        std::string kept;
        size_t pos = 0;
        while (pos < line.size()) {
            size_t end = line.find(' ', pos);
            if (end == std::string::npos) end = line.size();
            const std::string item = line.substr(pos, end - pos);
            pos = end + 1;
            if (item.rfind("rtt_ms=", 0) && item.rfind("time=", 0) && item.rfind("jitter_ms=", 0) && item.rfind("delay_ms=", 0)) kept += item + " ";
        }
        std::fprintf(out, "STATUS %s\n", kept.c_str());
    }
    std::fclose(out);
    return 0;
}

std::unique_ptr<relay::Link> relay::make_steam_link(const std::string&, bool, uint64_t) {
    throw std::runtime_error("no Steam here");
}
