import std.algorithm;
import std.exception;
import std.file;
import std.format;
import std.math;
import std.stdio;

struct StationName {
    const(ubyte)[] data;
    size_t hash;

    this(const(ubyte)[] data) {
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

    int opCmp(ref const StationName other) const => cmp(data, other.data);

    string toString() const pure => cast(string) data;
}

unittest {
    auto a = StationName([5, 3, 4]);
    auto b = StationName([3, 4]);
    assert(a > b);
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
    const(ubyte)[] data;
    Stats[StationName] stats;
    int numThreads;
    int threadNum;
    const size_t length;

    this(const(ubyte)[] data) {
        this.data = data;
        this.length = this.data.length;
    }

    void readLine(size_t* offset, Line *line) {
        size_t start = *offset;
        size_t end = start;

        while (end < length && data[end] != ';') {
            ++end;
        }
        enforce(end != length && end > start);
        line.identifier = StationName(data[start .. end]);
        ++end;

        start = end;
        while (end < length && data[end] != '\n') {
            ++end;
        }
        enforce(end != length && end > start);
        const(ubyte)[] tempBytes = data[start .. end];
        int v = 0;
        bool sign = tempBytes[0] == '-';
        foreach (c; tempBytes) {
            if ('0' <= c && c <= '9') {
                v = 10 * v + c - '0';
            }
        }
        line.temp = sign ? -v : v;

        *offset = end + 1;
    }
}

Reader[] makeReaders(const(ubyte)[] data, int numThreads) {
    Reader[] readers;
    foreach (i; 0 .. numThreads) {
        auto reader = new Reader(data);
        reader.numThreads = numThreads;
        reader.threadNum = i;
        readers ~= reader;
    }
    return readers;
}

struct Line {
    StationName identifier;
    int temp;
    this(StationName identifier, int temp) {
        this.identifier = identifier;
        this.temp = temp;
    }
}

static const size_t BLOCK_SIZE = 256 * 1024;

void readStats(Reader reader) {
    size_t numThreads = reader.numThreads;
    size_t threadNum = reader.threadNum;
    auto stride = numThreads * BLOCK_SIZE;
    for (size_t start = threadNum * BLOCK_SIZE; start < reader.length; start += stride) {
        // block start, end
        auto bStart = start;
        size_t bEnd = min(start + BLOCK_SIZE, reader.length);
        // If it's the first block, we know it's at a boundary. Otherwise find the first line in the block
        if (bStart > 0) {
            // If the previous block ended on a newline, we do start on the boundary
            --bStart;
            while (bStart < bEnd && reader.data[bStart] != '\n') {
                ++bStart;
            }
            // Advance past the newline
            ++bStart;
        }
        size_t currentOffset = bStart;
        while (currentOffset < bEnd) {
            Line line;
            reader.readLine(&currentOffset, &line);
            Stats* stats = &reader.stats.require(line.identifier, Stats());
            stats.min = min(stats.min, line.temp);
            stats.max = max(stats.max, line.temp);
            stats.sum += line.temp;
            stats.n += 1;
        }
    }
}

Stats[StationName] mergeStats(Reader[] readers) {
    Stats[StationName] stats;
    foreach (reader; readers) {
        foreach (ref station; reader.stats.keys) {
            auto src = &reader.stats[station];
            Stats* dest = &stats.require(station, Stats());
            dest.min = min(dest.min, src.min);
            dest.max = max(dest.max, src.max);
            dest.sum += src.sum;
            dest.n += src.n;
        }
    }
    return stats;
}

void main(string[] args) {
    import std.mmfile;
    import std.parallelism;
    enforce(args.length >= 2);
    scope fileData = new MmFile(args[1], MmFile.Mode.read, 0, null, 0);
    auto data = cast(const(ubyte)[]) fileData[];
    auto readers = makeReaders(data, 8);
    writeln("Read");
    foreach (i, ref reader; taskPool.parallel(readers)) {
    // foreach (ref reader; readers) {
        reader.readStats();
    }
    writeln("Parsed");
    auto mergedStats = mergeStats(readers);
    auto keys = mergedStats.keys.dup;
    keys.sort();
    foreach (s; keys) {
        Stats* stats = &mergedStats[s];
        writefln("%s: [%s -> %s] %s", s, Fixed10(stats.min), Fixed10(stats.max), Fixed10(
                stats.sum / stats.n));
    }
    writeln(mergedStats.length, " distinct entries");
}
