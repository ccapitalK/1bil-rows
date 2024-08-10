import std.algorithm;
import std.exception;
import std.file;
import std.format;
import std.math;
import std.stdio;

V* setDefault(M, K, V)(M *map, K key, V delegate() def) {
    V* val = key in *map;
    if (val == null) {
        (*map)[key] = def();
        val = &(*map)[key];
    }
    return val;
}

struct Stats {
    int min = int.max;
    int max = int.min;
    long sum;
    long n;
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
    Stats[string] stats;

    this(const ubyte[] data) {
        this.data = data;
    }

    size_t length() const => data.length;

    Line readLine(size_t *offset) {
        import std.conv;
        Line line;
        size_t start = *offset;
        size_t end = start;
        const size_t length = length();

        while (end < length && data[end] != ';') ++end;
        enforce(end != length && end > start);
        line.identifier = cast(string) data[start .. end];
        ++end;

        start = end;
        while (end < length && data[end] != '\n') ++end;
        enforce(end != length && end > start);
        const ubyte[] tempBytes = data[start .. end];
        int v = 0;
        bool sign = tempBytes[0] == '-';
        foreach (c; tempBytes) {
            if ('0' <= c && c <= '9') {
                v = 10 * v + c - '0';
            }
        }
        line.temp = sign ? -v : v;

        *offset = end + 1;
        return line;
    }
}

Reader makeReader(string filename) {
    auto data = cast(ubyte[]) read(filename);
    auto reader = new Reader(data);
    return reader;
}

struct Line {
    string identifier;
    int temp;
}

void readStats(Reader reader) {
    size_t currentOffset = 0;
    while (currentOffset < reader.length) {
        auto line = reader.readLine(&currentOffset);
        Stats *stats = (&reader.stats).setDefault(line.identifier, () => Stats());
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
        Stats *stats = &reader.stats[s];
        writefln("%s: [%s -> %s] %s", s, Fixed10(stats.min), Fixed10(stats.max), Fixed10(stats.sum / stats.n));
    }
}
