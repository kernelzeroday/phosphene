// exit_catcher.c
// SIGTRAP skip handler: advances the instruction pointer past brk
// instructions so _start() can continue past assertion failures.

#include <signal.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <stdio.h>

static bool _ext_main_called = false;
static volatile int _trap_count = 0;

int ext_main_already_called(void) {
    return _ext_main_called ? 1 : 0;
}

void set_ext_main_called(void) {
    _ext_main_called = true;
}

#if defined(__aarch64__) || defined(__arm64__)
static void _sigtrap_skip_handler(int sig, siginfo_t *info, void *context) {
    ucontext_t *uc = (ucontext_t *)context;
    uint64_t pc = uc->uc_mcontext->__ss.__pc;
    _trap_count++;
    fprintf(stderr, "[exit_catcher] SIGTRAP #%d at PC=0x%llx — skipping\n",
            _trap_count, (unsigned long long)pc);
    uc->uc_mcontext->__ss.__pc = pc + 4;
}
#endif

void install_sigtrap_skip_handler(void) {
#if defined(__aarch64__) || defined(__arm64__)
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_sigaction = _sigtrap_skip_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = SA_SIGINFO;
    sigaction(SIGTRAP, &sa, NULL);
    fprintf(stderr, "[exit_catcher] SIGTRAP skip handler installed\n");
#endif
}

int catch_exit_and_call_ext_main(int (*ext_main)(int, char **), int argc, char *argv[]) {
    _ext_main_called = true;
    install_sigtrap_skip_handler();

    int result = 0;
    if (ext_main != NULL) {
        result = ext_main(argc, argv);
    }

    fprintf(stderr, "[exit_catcher] ext_main returned %d (traps skipped: %d)\n",
            result, _trap_count);
    return result;
}
