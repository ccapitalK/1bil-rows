#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#define MIN(a, b) ((a) < (b) ? (a) : (b))
#define MAX(a, b) ((a) > (b) ? (a) : (b))

#undef NDEBUG
#include <assert.h>

void die(const char *msg) {
    printf("ERROR: %s\n", msg);
    exit(1);
}

const char *filename = "measurements.txt";

struct Statistics {
    int64_t min;
    int64_t max;
    int64_t sum;
    size_t n;
};

struct Context {
    char *data;
    size_t len;
    size_t *lineOffsets;
    size_t numLineOffsets;
};

struct Span {
    char *start;
    size_t length;
};

void setupContext(struct Context *ctx);
void parseLines(struct Context *ctx);

void runTests(void);

int main() {
    if (1) {
        runTests();
        return 0;
    }
    struct Context ctx;
    setupContext(&ctx);
    parseLines(&ctx);
}

static size_t fileLen(FILE *file) {
    fseek(file, 0, SEEK_END);
    size_t v = ftell(file);
    fseek(file, 0, SEEK_SET);
    return v;
}

void setupContext(struct Context *ctx) {
    FILE *fp = fopen(filename, "r");
    assert(fp != NULL);
    int fd = fileno(fp);
    size_t fileLength = fileLen(fp);
    ctx->data = malloc(fileLength);
    assert(ctx->data != NULL);
    printf("Allocated\n");

    size_t readPos = 0;
    while (readPos < fileLength) {
        int64_t nread = read(fd, ctx->data + readPos, MIN(fileLength - readPos, 1 << 24));
        if (nread <= 0) {
            perror("Failed to read");
            die("Failed to read");
        }
        readPos += nread;
    }
    assert(readPos == fileLength);
    printf("Read\n");
}

void calcTerminate(struct Context *ctx, size_t start, size_t *delimOffset, size_t *lineLength) {
    *delimOffset = 0;
    char *data = ctx->data;
    // while (start < ctx->len && ctx->data[start] != '\0') {
    //     if ();
    //     ++start;
    // }
}

void parseLines(struct Context *ctx) {
    size_t offset = 0;
    while (offset < ctx->len) {
        size_t delimOffset;
        size_t lineLength;
        calcTerminate(ctx, offset, &delimOffset, &lineLength);
        offset += lineLength + 1;
    }
}

void runTests(void) {
}
