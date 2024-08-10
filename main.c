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

struct Context;

void setupContext(struct Context *ctx);

void runTests(void);

struct Context {
    char *data;
    size_t len;
    size_t *lineOffsets;
    size_t numLineOffsets;
};

int main() {
    if (0) {
        runTests();
        return 0;
    }
    struct Context ctx;
    setupContext(&ctx);
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
    printf("Read\n");
    assert(readPos == fileLength);
}

void runTests(void) {}
