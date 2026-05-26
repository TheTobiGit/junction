#include <fcntl.h>
#include <unistd.h>

int main(int argc, char **argv) {
    if (argc < 2) return 1;
    int fd = open(argv[1], O_RDWR);
    if (fd < 0) return 2;
    struct flock lock = {.l_type = F_WRLCK, .l_whence = SEEK_SET};
    if (fcntl(fd, F_SETLK, &lock) != 0) return 3;
    pause();
    return 0;
}
