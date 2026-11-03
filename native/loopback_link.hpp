// Tests only, never in main.dll: the relay over UDP on this PC's loopback, for relay_cli's bench (bots, a bad connection
// between two ports, the sockets test). Players always connect through Steam Networking (steam.cpp); one Steam account
// can't reach itself, so this is how two relays on one PC can talk.
#pragma once
#include "relay.hpp"    // first: it sets up windows.h (lean, no min/max macros), which leaves Winsock 2 to this file

#include <winsock2.h>
#include <ws2tcpip.h>

namespace relay {

class LoopbackLink : public Link {
public:
    LoopbackLink(const std::string& role, int port) {
        WSADATA wsa;
        if (WSAStartup(MAKEWORD(2, 2), &wsa) != 0) throw std::runtime_error("Winsock didn't start");
        sock_ = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
        if (sock_ == INVALID_SOCKET) throw std::runtime_error("couldn't open a UDP socket");
        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
        addr.sin_port = htons(static_cast<u_short>(role == "host" ? port : 0));
        if (bind(sock_, reinterpret_cast<sockaddr*>(&addr), sizeof addr) != 0) {
            const int err = WSAGetLastError();
            closesocket(sock_);
            throw std::runtime_error("UDP port " + std::to_string(port) + (err == WSAEADDRINUSE ? " is in use on this PC" : " can't be used") +
                                     " (error " + std::to_string(err) + "): pick another --port");
        }
        if (role != "host") {
            Addr a;
            a.ip = INADDR_LOOPBACK;
            a.port = static_cast<uint16_t>(port);
            peer = a;
        }
        // Signalled the moment a packet lands, so the relay sleeps instead of polling. Makes the socket non-blocking.
        readable_ = WSACreateEvent();
        WSAEventSelect(sock_, readable_, FD_READ);
    }

    ~LoopbackLink() override {
        WSACloseEvent(readable_);
        closesocket(sock_);
        WSACleanup();
    }

    void send(const Addr& to, const std::string& data) override {
        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = htonl(to.ip);
        addr.sin_port = htons(to.port);
        sendto(sock_, data.data(), static_cast<int>(data.size()), 0, reinterpret_cast<sockaddr*>(&addr), sizeof addr);
    }

    std::vector<std::pair<Addr, std::string>> receive() override {
        std::vector<std::pair<Addr, std::string>> out;
        static thread_local std::vector<char> buf(65536);
        for (int i = 0; i < MAX_PACKETS_PER_RECEIVE; i++) {
            sockaddr_in from{};
            int from_len = sizeof from;
            int n = recvfrom(sock_, buf.data(), static_cast<int>(buf.size()), 0, reinterpret_cast<sockaddr*>(&from), &from_len);
            if (n < 0) {
                int err = WSAGetLastError();
                // Windows reports ICMP "port unreachable" this way while the peer isn't running yet.
                if (err == WSAECONNRESET || err == WSAEMSGSIZE) continue;
                break;
            }
            Addr a;
            a.ip = ntohl(from.sin_addr.s_addr);
            a.port = ntohs(from.sin_port);
            if (peer && a != *peer) filtered++;      // a client listens to its host's exact port only
            else out.emplace_back(a, std::string(buf.data(), n));
        }
        return out;
    }

    void wait(double seconds, HANDLE wake) override {
        HANDLE events[2] = {wake, readable_};
        // A socket event stays set until it's reset: left alone, this thread spins a whole core from the first packet on.
        // Reset before the read that follows, so a packet landing after that read sets it again.
        if (WaitForMultipleObjects(2, events, FALSE, static_cast<DWORD>(std::ceil(seconds * 1000))) == WAIT_OBJECT_0 + 1)
            WSAResetEvent(readable_);
    }

    std::string describe(const Addr& a) override {
        char s[32];
        std::snprintf(s, sizeof s, "%u.%u.%u.%u:%u", a.ip >> 24, (a.ip >> 16) & 255, (a.ip >> 8) & 255, a.ip & 255, a.port);
        return s;
    }

    std::string describe_self() override {
        sockaddr_in me{};
        int len = sizeof me;
        getsockname(sock_, reinterpret_cast<sockaddr*>(&me), &len);
        return "UDP " + std::to_string(ntohs(me.sin_port));
    }

    const char* via() override { return "udp"; }

private:
    SOCKET sock_ = INVALID_SOCKET;
    WSAEVENT readable_ = WSA_INVALID_EVENT;
};

}  // namespace relay
