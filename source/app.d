import std.algorithm;
import std.exception;
import std.file;
import std.format;
import std.math;
import std.stdio;

// Mask to accept only the left i bytes of a ulong (little endian). Correct for 1 <= i <= 8
ulong lmask(size_t i) pure => (1UL << (8UL * i)) - 1UL;

// Mask to accept only the right i bytes of a ulong (little endian). Correct for 0 <= i <= 7
ulong rmask(size_t i) pure => ~((~0UL) >> (8UL * i));

// unaligned read variant
size_t rhash1(const(ubyte)[] data) pure {
    size_t hash = 1337;
    long length = data.length;
    //size_t longLength = (data.length + 7) / 8;
    auto addr = cast(const(ulong)*) data.ptr;
    size_t offset = 0;
    while (length > 0) {
        ulong val = addr[offset];
        if (length < 8) {
            val &= lmask(length);
        }
        hash ^= val;
        length -= 8;
        offset += 1;
    }
    return hash;
}

ubyte reduceXor(ulong v) {
    v = (v & 0xffff_ffff) ^ (v >> 32);
    v = (v & 0xffff) ^ (v >> 16);
    return cast(ubyte)((v & 0xff) ^ (v >> 8));
}

// aligned read variant
size_t rhash2(const(ubyte)[] data) pure {
    size_t addr = cast(size_t) data.ptr;
    size_t offset = addr & 0x7;
    ulong* alignedStart = cast(ulong*)(addr ^ offset);

    long toRead = data.length + offset;
    size_t index = 0;
    size_t hash = 0;
    while (toRead > 0) {
        ulong val = alignedStart[index];
        if (offset > 0) {
            val &= rmask(8 - offset);
        }
        if (toRead < 8) {
            val &= lmask(toRead);
        }
        toRead -= 8;
        index += 1;
        offset = 0;
    }
    return hash * 1337 + 13;
}

size_t rollHash(const(ubyte)[] data) pure => rhash1(data);

unittest {
    assert(reduceXor(0xf30031) == reduceXor(0x0130f3));
    assert(lmask(1) == 0x00ffUL);
    assert(lmask(3) == 0x00ff_ffffUL);
    assert(lmask(7) == 0x00ff_ffff_ffff_ffffUL);
    assert(rmask(0) == 0UL);
    assert(rmask(1) == 0xff00_0000_0000_0000UL);
    assert(rmask(2) == 0xffff_0000_0000_0000UL);
    assert(rmask(7) == 0xffff_ffff_ffff_ff00UL);
    ubyte[] garbage = [29, 38, 10, 44, 210, 48, 22, 6];
    ubyte[] test = [1, 31, 28, 77, 9, 33, 101, 82, 29, 183, 94, 211];
    ubyte[] prefix = [];
    auto base = rollHash(test);
    auto n = test.length;
    foreach (i; 0 .. 16) {
        prefix ~= cast(ubyte)(i * 13u);
        auto concat = prefix ~ test ~ [cast(ubyte)(i * 19u)] ~ garbage;
        auto inPlace = concat[prefix.length .. (prefix.length + n)];
        assert(rollHash(inPlace) == base);
    }
}

struct StationName {
    const(ubyte)[] data;
    size_t hash;

    this(const(ubyte)[] data) {
        this.data = data;
        this.hash = calcHash();
    }

    size_t toHash() const nothrow pure => hash;

    size_t calcHash() const pure {
        return rollHash(data);
    }

    bool opEquals(ref const StationName other) const nothrow pure {
        if (other.data.length != data.length || hash != other.hash) {
            return false;
        }
        return true;
        // XXX Cursed Assume hash function is enough
        // auto N = data.length;
        // size_t i = 0;
        // while (i < N && data[i] == other.data[i]) {
        //     ++i;
        // }
        // return i == N;
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

void readLine(const(ubyte)[] data, size_t* offset, Line* line) {
    size_t start = *offset;
    size_t end = start;
    size_t length = data.length;

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

unittest {
    auto s1 = cast(const(ubyte)[]) "aad'hello;12.9\n238";
    size_t offset = 4;
    Line line;
    readLine(s1, &offset, &line);
    auto expected = StationName(cast(const(ubyte)[]) "hello");
    assert(line.identifier == expected);
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

    void nextLine(size_t* offset, Line* line) => readLine(data, offset, line);
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
            reader.nextLine(&currentOffset, &line);
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

void writeSummary(Stats[StationName] mergedStats) {
    import std.array;

    auto keys = mergedStats.keys.dup;
    keys.sort();
    write("{");
    bool isFirst = true;
    foreach (s; keys) {
        Stats* stats = &mergedStats[s];
        if (!isFirst) {
            write(", ");
        }
        writef(
            "%s=%s/%s/%s",
            s,
            Fixed10(stats.min),
            Fixed10(cast(int) round(stats.sum / stats.n)),
            Fixed10(stats.max),
        );
        isFirst = false;
    }
    writeln("}");
}

void main(string[] args) {
    import std.mmfile;
    import std.parallelism;

    enforce(args.length >= 2);
    scope fileData = new MmFile(args[1], MmFile.Mode.read, 0, null, 0);
    auto data = cast(const(ubyte)[]) fileData[];
    auto readers = makeReaders(data, 8);
    foreach (i, ref reader; taskPool.parallel(readers)) {
        reader.readStats();
    }
    auto mergedStats = mergeStats(readers);
    mergedStats.writeSummary();
}
