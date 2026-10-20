#include <sys/types.h>
#include <sys/stat.h>
#include <stdint.h>

#define UART_TX 0xC0000000

void _putchar(char c) {
    *(volatile char*)UART_TX = c;
}

int _write(int file, char *ptr, int len) {
    for (int i = 0; i < len; i++) {
        _putchar(ptr[i]);
    }
    return len;
}

int _close(int file) { return -1; }
#include <sys/time.h>

int _gettimeofday(struct timeval *tv, void *tz) {
    if (tv) {
        uint64_t cycles = *((volatile uint64_t*)0xC0000008);
        tv->tv_sec = cycles;
        tv->tv_usec = 0;
    }
    return 0;
}

int _fstat(int file, struct stat *st) {
    st->st_mode = S_IFCHR;
    return 0;
}
int _isatty(int file) { return 1; }
off_t _lseek(int file, off_t ptr, int dir) { return 0; }
int _read(int file, char *ptr, int len) { return 0; }
void _exit(int status) {
    extern volatile uint64_t tohost;
    if (status == 0) {
        // Success
        tohost = 1;
    } else {
        // Failure
        tohost = (status << 1) | 1;
    }
    while (1);
}

void setStats(int enable) {
    (void)enable;
}

void* _sbrk(int incr) {
    extern char _end;
    static char* heap_end;
    char* prev_heap_end;

    if (heap_end == 0) {
        heap_end = &_end;
    }
    prev_heap_end = heap_end;
    heap_end += incr;
    return (void*)prev_heap_end;
}
