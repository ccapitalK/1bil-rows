import std.algorithm;
import std.exception;
import std.file;
import std.format;
import std.math;
import std.stdio;

struct StationName {
    const ubyte[] data;
    size_t hash;

    this(const ubyte[] data) {
        this.data = data;
        this.hash = calcHash();
    }

    size_t toHash() const nothrow pure => hash;

    size_t calcHash() const nothrow pure {
        size_t h = 1337;
        foreach (k; data) {
            h = 13 * (h ^ k) ^ (37 * (h >> 2));
        }
        return h;
    }

    bool opEquals(ref const StationName other) const nothrow pure {
        if (other.data.length != data.length || hash != other.hash) {
            return false;
        }
        auto N = data.length;
        size_t i = 0;
        while (i < N && data[i] == other.data[i]) {
            ++i;
        }
        return i == N;
    }

    string toString() const pure => cast(string) data;
}

struct Stats {
    long sum = 0;
    long n = 0;
    int min = int.max;
    int max = int.min;
}

struct Fixed10 {
    int v;
    string toString() const {
        int x = abs(v);
        if (v < 0) {
            return format("-%d.%d", x / 10, x % 10);
        } else {
            return format("%d.%d", x / 10, x % 10);
        }
    }
}

class Reader {
    const ubyte[] data;
    Stats[StationName] stats;

    this(const ubyte[] data) {
        this.data = data;
    }

    size_t length() const => data.length;

    Line readLine(size_t* offset) {
        import std.conv;

        size_t start = *offset;
        size_t end = start;
        const size_t length = length();

        while (end < length && data[end] != ';') {
            ++end;
        }
        enforce(end != length && end > start);
        StationName identifier = StationName(data[start .. end]);
        ++end;

        start = end;
        while (end < length && data[end] != '\n') {
            ++end;
        }
        enforce(end != length && end > start);
        const ubyte[] tempBytes = data[start .. end];
        int v = 0;
        bool sign = tempBytes[0] == '-';
        foreach (c; tempBytes) {
            if ('0' <= c && c <= '9') {
                v = 10 * v + c - '0';
            }
        }
        int temp = sign ? -v : v;

        *offset = end + 1;
        return Line(identifier, temp);
    }
}

Reader makeReader(string filename) {
    auto data = cast(ubyte[]) read(filename);
    auto reader = new Reader(data);
    return reader;
}

struct Line {
    StationName identifier;
    int temp;
    this(StationName identifier, int temp) {
        this.identifier = identifier;
        this.temp = temp;
    }
}

void readStats(Reader reader) {
    size_t currentOffset = 0;
    while (currentOffset < reader.length) {
        auto line = reader.readLine(&currentOffset);
        Stats* stats = &reader.stats.require(line.identifier, Stats());
        stats.min = min(stats.min, line.temp);
        stats.max = max(stats.max, line.temp);
        stats.sum += line.temp;
        stats.n += 1;
    }
}

void main(string[] args) {
    enforce(args.length >= 2);
    auto reader = makeReader(args[1]);
    writeln("Read");
    readStats(reader);
    writeln("Parsed");
    foreach (s; reader.stats.keys) {
        Stats* stats = &reader.stats[s];
        writefln("%s: [%s -> %s] %s", s, Fixed10(stats.min), Fixed10(stats.max), Fixed10(
                stats.sum / stats.n));
    }
    writeln(reader.stats.length, " distinct entries");
}
