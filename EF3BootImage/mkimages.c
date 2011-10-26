
#include <sys/types.h>
#include <sys/stat.h>
#include <errno.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

static unsigned char buff[1024 * 1024];
static FILE*    fp;
static size_t   crt_size;

#define MAX_BANK  0x7f
#define BANK_SIZE 0x4000


/******************************************************************************/
/**
 * Read a binary image and write it to the CRT file.
 * Return 1 on success, 0 on error.
 */
static int write_bin(char* filename, long bank, long offset)
{
    FILE *fp;
    struct stat st;
    size_t abs_offset;

    abs_offset = 0x4000 * bank + offset;

    if (stat(filename, &st))
    {
        fprintf(stderr, "Cannot stat %s: %s\n", filename, strerror(errno));
        return 0;
    }
    if (st.st_size > sizeof(buff) - abs_offset)
    {
        fprintf(stderr, "File %s is too large!\n", filename);
        return 0;
    }
    fp = fopen(filename, "rb");
    if (fp == NULL)
    {
        fprintf(stderr, "Cannot open %s: %s\n", filename, strerror(errno));
        return 0;
    }
    if (fread(buff + abs_offset, st.st_size, 1, fp) != 1)
    {
        fprintf(stderr, "Cannot read %s: %s\n", filename, strerror(errno));
        return 0;
    }
    fclose(fp);

    return 1;
}

/******************************************************************************/
int main(int argc, char *argv[])
{
    int i;
    long bank, offset;
    char *filename;

    memset(buff, 0xff, sizeof(buff));

    if (argc < 4 || ((argc - 2) % 3) != 0)
    {
        fprintf(stderr,
                "Usage: %s binfile bankno offset [binfile bankno offset...] crtfile\n", argv[0]);
        return 1;
    }

    filename = argv[argc-1];
    fp = fopen(filename, "wb");

    if (fp == NULL)
    {
        fprintf(stderr, "Cannot open %s: %s\n", argv[argc-1], strerror(errno));
        return 1;
    }

    for (i = 1; i < argc-1; i += 3)
    {
        char *endptr;

        bank = strtol(argv[i+1], &endptr, 0);
        if (*endptr != 0 || bank < 0 || bank > MAX_BANK)
        {
            fprintf(stderr, "Invalid bank: %s\n", argv[i+1]);
            goto error;
        }

        offset = strtol(argv[i+2], &endptr, 0);
        if (*endptr != 0 || offset < 0 || offset >= BANK_SIZE)
        {
            fprintf(stderr, "Invalid offset: %s\n", argv[i+2]);
            goto error;
        }

        write_bin(argv[i], bank, offset);
    }

    if (fwrite(buff, sizeof(buff), 1, fp) != 1)
    {
        fprintf(stderr, "Failed to write binary image to %s: %s\n",
                filename, strerror(errno));
        goto error;
    }
    fclose(fp);
    return 0;

error:
    fclose(fp);
    remove(argv[argc-1]);
    return 1;
}
