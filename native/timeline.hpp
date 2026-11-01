// Turns the partner's samples, which arrive late and unevenly, into a smooth path: the ghost plays them a little in the
// past, just far enough that the next sample has nearly always arrived, and that distance follows the connection. The
// two PCs' clocks are never compared: the fastest trip seen lately is taken as "on time", and everything is measured
// from that. Plain logic with no Windows calls, so relay_cli can test it against simulated connections.
#pragma once
#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <deque>
#include <vector>

namespace relay {

struct Sample {
    uint32_t ms = 0;            // the sender's clock when the game read it
    float x = 0, y = 0, z = 0, yaw = 0;
    float vx = 0, vy = 0, vz = 0;
    float hp = 0, max_hp = 0;
    uint32_t map = 0;           // hash of the area's name
    uint16_t flags = 0;
};

constexpr uint16_t FLAG_GROUNDED = 1, FLAG_CUTSCENE = 2;   // sent by the mod
constexpr uint16_t FLAG_JUMP = 0x4000;                     // set here: this sample teleported, don't blend into it
constexpr uint16_t FLAG_STALE = 0x8000;                    // set here: nothing new for longer than it can guess ahead

inline float shortest_turn(float from, float to) {
    float d = std::fmod(to - from + 540.0f, 360.0f);
    if (d < 0) d += 360.0f;
    return d - 180.0f;
}

class Timeline {
public:
    static constexpr size_t KEEP = 96;
    static constexpr size_t LATE_SAMPLES = 90;           // about 1.5 s of arrivals
    static constexpr int FASTEST_BUCKETS = 8;
    static constexpr double FASTEST_BUCKET_MS = 750;     // so the fastest trip is remembered for 6 s
    static constexpr double MIN_DELAY_MS = 4, MAX_DELAY_MS = 220;
    static constexpr double EXTRAPOLATE_MS = 160;        // past this it stops guessing and holds the last place
    static constexpr double SLACK_MS = 2;
    static constexpr double JUMP_CM = 900;               // this far between samples, and faster than any move: a teleport
    static constexpr double JUMP_SPEED_CM_S = 4000;
    static constexpr double RESET_MS = 1500;             // play position this far off: the sender's clock restarted
    static constexpr double CLOCK_BACK_MS = 400;         // samples this far behind the newest are never a late packet...
    static constexpr int CLOCK_BACK_SAMPLES = 3;         // ...once several come in a row: the sender's clock went back

    Timeline() { clear(); }

    void clear() {
        samples_.clear();
        late_.clear();
        late_at_ = 0;
        have_offset_ = false;
        bucket_start_ = 0;
        buckets_.fill(1e18);
        fastest_ = 0;
        interval_ = 16.7;
        jitter_ = 0;
        last_arrival_ = 0;
        last_at_ = 0;
        played_ = 0;
        clock_back_ = 0;
    }

    void push(const Sample& sent, double arrived_ms) {
        Sample s = sent;
        s.flags &= ~(FLAG_JUMP | FLAG_STALE);        // these two are this class's own, never the sender's
        if (!samples_.empty() && static_cast<double>(s.ms) + CLOCK_BACK_MS < samples_.back().ms) {
            if (++clock_back_ >= CLOCK_BACK_SAMPLES) clear();   // nothing measured against the old clock means anything now
        } else {
            clock_back_ = 0;
        }
        const double trip = arrived_ms - static_cast<double>(s.ms);
        track_fastest(trip, arrived_ms);
        note_late(trip - fastest_);
        last_arrival_ = arrived_ms;
        if (!samples_.empty()) {
            const Sample& newest = samples_.back();
            if (s.ms == newest.ms) return;
            if (s.ms > newest.ms) {
                const double gap = static_cast<double>(s.ms - newest.ms);
                if (gap < 200) interval_ += (gap - interval_) * 0.05;
                if (is_jump(newest, s)) s.flags |= FLAG_JUMP;
                samples_.push_back(s);
            } else {
                // Arrived out of order: useful only if it's still ahead of what has been played.
                if (static_cast<double>(s.ms) <= played_) return;
                auto at = std::lower_bound(samples_.begin(), samples_.end(), s,
                                           [](const Sample& a, const Sample& b) { return a.ms < b.ms; });
                if (at != samples_.end() && at->ms == s.ms) return;
                at = samples_.insert(at, s);
                // It may be the sample on either side of a teleport: the jump belongs wherever the path really broke.
                if (at != samples_.begin()) mark_jump(*(at - 1), *at);
                if (at + 1 != samples_.end()) mark_jump(*at, *(at + 1));
            }
        } else {
            samples_.push_back(s);
        }
        while (samples_.size() > KEEP) samples_.pop_front();
    }

    // Where the partner was, on the path as it's being played. False until the first sample arrives.
    bool at(double now_ms, Sample& out) {
        if (samples_.empty()) return false;
        const double step = last_at_ > 0 ? std::clamp(now_ms - last_at_, 0.0, 100.0) : 0.0;
        last_at_ = now_ms;
        const double want = fastest_ + target_delay();
        if (!have_offset_ || std::fabs(want - offset_) > RESET_MS) {
            offset_ = want;
            have_offset_ = true;
        }
        // Eased in: more delay quickly (a spike is here now), less delay slowly (the ghost mustn't speed up visibly).
        offset_ += std::clamp(want - offset_, -step * 0.06, step * 0.25);
        const double t = now_ms - offset_;
        played_ = t;

        const Sample& newest = samples_.back();
        if (t >= newest.ms) {
            out = newest;
            const double over = t - newest.ms;
            const double ahead = std::min(over, EXTRAPOLATE_MS) / 1000.0;
            out.x += static_cast<float>(newest.vx * ahead);
            out.y += static_cast<float>(newest.vy * ahead);
            if (!(newest.flags & FLAG_GROUNDED)) out.z += static_cast<float>(newest.vz * ahead);
            if (over > EXTRAPOLATE_MS) {
                out.flags |= FLAG_STALE;
                out.vx = out.vy = out.vz = 0;
            }
            return true;
        }
        size_t i = 0;
        while (i + 1 < samples_.size() && samples_[i + 1].ms <= t) i++;
        while (i > 0) {                      // what's been played is never needed again, bar the one before it
            samples_.pop_front();
            i--;
        }
        const Sample& a = samples_[0];
        if (samples_.size() < 2 || t < a.ms) {
            out = a;
            return true;
        }
        const Sample& b = samples_[1];
        const double dt = static_cast<double>(b.ms - a.ms);
        if (b.flags & FLAG_JUMP) {
            out = a;                         // holds until the jump's moment comes, then lands in one step
            return true;
        }
        const double f = (t - a.ms) / dt;
        out = b;
        out.ms = static_cast<uint32_t>(t);
        out.x = lerp(a.x, b.x, f);
        out.y = lerp(a.y, b.y, f);
        out.z = lerp(a.z, b.z, f);
        out.yaw = a.yaw + static_cast<float>(shortest_turn(a.yaw, b.yaw) * f);
        // The speed along this stretch of the path, not the sender's own number: following it stays on the path.
        if (dt >= 8) {
            out.vx = static_cast<float>((b.x - a.x) * 1000.0 / dt);
            out.vy = static_cast<float>((b.y - a.y) * 1000.0 / dt);
            out.vz = static_cast<float>((b.z - a.z) * 1000.0 / dt);
        }
        return true;
    }

    double delay_ms() const { return have_offset_ ? offset_ - fastest_ : 0; }
    double jitter_ms() const { return jitter_; }
    double interval_ms() const { return interval_; }
    double silence_ms(double now_ms) const { return last_arrival_ > 0 ? now_ms - last_arrival_ : 1e9; }

private:
    static float lerp(float a, float b, double f) { return static_cast<float>(a + (b - a) * f); }

    static bool is_jump(const Sample& a, const Sample& b) {
        const double dx = b.x - a.x, dy = b.y - a.y, dz = b.z - a.z;
        const double d = std::sqrt(dx * dx + dy * dy + dz * dz);
        const double dt = std::max(1.0, static_cast<double>(b.ms - a.ms));
        return d > JUMP_CM && d * 1000.0 / dt > JUMP_SPEED_CM_S;
    }

    static void mark_jump(const Sample& a, Sample& b) {
        if (is_jump(a, b)) b.flags |= FLAG_JUMP;
        else b.flags &= ~FLAG_JUMP;
    }

    double target_delay() const {
        return std::clamp(interval_ + jitter_ + SLACK_MS, MIN_DELAY_MS, MAX_DELAY_MS);
    }

    void track_fastest(double trip, double now_ms) {
        if (bucket_start_ == 0) bucket_start_ = now_ms;
        if (now_ms - bucket_start_ >= FASTEST_BUCKET_MS * FASTEST_BUCKETS) {    // a long silence: nothing kept is recent
            buckets_.fill(1e18);
            bucket_start_ = now_ms;
        }
        while (now_ms - bucket_start_ >= FASTEST_BUCKET_MS) {
            bucket_start_ += FASTEST_BUCKET_MS;
            std::rotate(buckets_.begin(), buckets_.begin() + 1, buckets_.end());
            buckets_.back() = 1e18;
        }
        buckets_.back() = std::min(buckets_.back(), trip);
        fastest_ = *std::min_element(buckets_.begin(), buckets_.end());
    }

    // The 90th percentile of how late arrivals are: one bad spike doesn't drag the whole path back, but a connection
    // that is often late does.
    void note_late(double late) {
        if (late_.size() < LATE_SAMPLES) late_.push_back(late);
        else late_[late_at_ % LATE_SAMPLES] = late;
        late_at_++;
        if (late_at_ % 8 == 0 || late_.size() < 8) {
            scratch_ = late_;
            auto mid = scratch_.begin() + static_cast<long>(scratch_.size() * 9 / 10);
            std::nth_element(scratch_.begin(), mid, scratch_.end());
            jitter_ = *mid;
        }
    }

    std::deque<Sample> samples_;
    std::vector<double> late_, scratch_;
    size_t late_at_ = 0;
    std::array<double, FASTEST_BUCKETS> buckets_{};
    double bucket_start_ = 0;
    double fastest_ = 0;
    double interval_ = 16.7, jitter_ = 0;
    double offset_ = 0;
    bool have_offset_ = false;
    double last_arrival_ = 0, last_at_ = 0, played_ = 0;
    int clock_back_ = 0;
};

}  // namespace relay
