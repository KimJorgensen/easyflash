#include <sys/types.h>
#include <sys/stat.h>
#include <errno.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "cart.h"

static unsigned char buff[1024 * 1024];
static FILE*    fp;
static size_t   crt_size;

#define MAX_BANK 0x7f

/******************************************************************************/
/*
 * Write the CRT header to the output file. 
 * Return 1 on success, 0 on error.
 */
static int writeCRTHeader(void)
{
    CartHeader h = {};

    memcpy(h.signature, "C64 CARTRIDGE   ", sizeof(h.signature));
    h.headerLen[3]  = sizeof(h);
    h.version[0]    = 1;
    h.type[1]       = CART_TYPE_EASYFLASH;
    h.exromLine     = 0;
    h.gameLine      = 1;
    memcpy(h.name, "EF2 MULTI CARTRIDGE IMAGE       ", sizeof(h.name));

    if (fwrite(&h, sizeof(h), 1, fp) != 1)
    {
        fprintf(stderr, "Error writing CRT header\n");
        return 0;
    }
    return 1;
}

/******************************************************************************/
/**
 * Write a CRT CHIP header with the given information.
 * Return 1 on success, 0 on error.
 */
static int writeChipHeader(unsigned nBank, unsigned nAddr,
                            unsigned size)
{
    BankHeader header = {};

    // Contained ROM signature "CHIP"
    memcpy(header.signature, "CHIP", 4);

    // Total packet length, ROM image size + header (4 bytes, high/low format)
    header.packetLen[2] = (size + sizeof(header)) / 256;
    header.packetLen[3] = (size + sizeof(header)) % 256;

    // Chip type: 0 - ROM, 1 - RAM, no ROM data, 2 - Flash ROM
    header.chipType[1] = 2;

    // Bank number (2 bytes, high/low format)
    header.bank[0] = nBank / 256;
    header.bank[1] = nBank % 256;

    // Load address (2 bytes, high/low format)
    header.loadAddr[0] = nAddr / 256;
    header.loadAddr[1] = nAddr % 256;

    // ROM image size (2 bytes, high/low format, typically $2000 or $4000)
    header.romLen[0] = size / 256;
    header.romLen[1] = size % 256;

    if (fwrite(&header, sizeof(header), 1, fp) != 1)
    {
        fprintf(stderr, "Error writing CRT CHIP header\n");
        return 0;
    }
    return 1;
}


/******************************************************************************/
/**
 * Read a binary image and write it to the CRT file.
 * Return 1 on success, 0 on error.
 */
static int writeBin(char *filename, int bank)
{
    FILE *fpIn;
    int curBank;
    struct stat st;

    if (stat(filename, &st))
    {
        fprintf(stderr, "Cannot stat %s: %s\n", filename, strerror(errno));
        return 0;
    }
    if (st.st_size > sizeof(buff))
    {
        fprintf(stderr, "File %s is too large!\n", filename);
        return 0;
    }
    fpIn = fopen(filename, "rb");
    if (fpIn == NULL)
    {
        fprintf(stderr, "Cannot open %s: %s\n", filename, strerror(errno));
        return 0;
    }
    if (fread(buff, st.st_size, 1, fpIn) != 1)
    {
        fprintf(stderr, "Cannot read %s: %s\n", filename, strerror(errno));
        return 0;
    }
    fclose(fpIn);

    for (curBank = 0; curBank < (st.st_size + 0x4000 - 1)/0x4000; ++curBank)
    {
        int bankSize;

        if (st.st_size - curBank * 0x4000 < 0x4000)
            bankSize = st.st_size % 0x4000;
        else
            bankSize = 0x4000;

        writeChipHeader(bank + curBank, 0x8000, bankSize);

        if (fwrite(buff + 0x4000 * curBank, bankSize, 1, fp) != 1)
        {
            fprintf(stderr, "Failed to write bank %d of %s: %s\n",
                    curBank, filename, strerror(errno));
            return 0;
        }
    }

    return 1;
}

/******************************************************************************/
int main(int argc, char *argv[])
{
    int i;
    long bank;

    if (argc < 3 || (argc % 2) != 0)
    {
        fprintf(stderr, "Syntax: %s binfile bankno [binfile bankno...] crtfile\n", argv[0]);
        return 1;
    }

    fp = fopen(argv[argc-1], "wb");

    if (fp == NULL)
    {
        fprintf(stderr, "Cannot open %s: %s\n", argv[argc-1], strerror(errno));
        return 1;
    }

    if (!writeCRTHeader())
        goto error;

    for (i = 1; i < argc-1; i += 2)
    {
        char *endptr;

        bank = strtol(argv[i+1], &endptr, 0);
        if (*endptr != 0 || bank < 0 || bank > MAX_BANK)
        {
            fprintf(stderr, "Invalid bank: %s\n", argv[i+1]);
            goto error;
        }

        writeBin(argv[i], bank);
    }

    fclose(fp);
    return 0;

error:
    fclose(fp);
    remove(argv[argc-1]);
    return 1;
}
