
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include "cart.h"

static const char* ef2_crt_name = "ef2-multi-crt.crt";

static FILE*    fp;
static size_t   crt_size;

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
 * Read the fc3 binary image and write it to the CRT file.
 * Return 1 on success, 0 on error.
 */
static int writeFC3(void)
{
    FILE* fpIn;
    char buff[64 * 1024];
    int bank;

    fpIn = fopen("fc3-1988.bin", "rb");
    if (fpIn == NULL)
    {
        fprintf(stderr, "Cannot open FC-III binary\n");
        return 0;
    }
    if (fread(buff, 64 * 1024, 1, fpIn) != 1)
    {
        fprintf(stderr, "Cannot read FC-III binary\n");
        return 0;
    }
    fclose(fpIn);

    for (bank = 0; bank < 4; ++bank)
    {
        writeChipHeader(64 + bank, 0x8000, 0x4000);
        if (fwrite(buff + 0x4000 * bank, 0x4000, 1, fp) != 1)
        {
            fprintf(stderr, "Cannot write FC-III data\n");
            return 0;
        }
    }

    return 1;
}

/******************************************************************************/
int main(void)
{
    fp = fopen(ef2_crt_name, "wb");

    if (!writeCRTHeader())
        goto error;

    if (!writeFC3())
        goto error;

    fclose(fp);
    return 0;
error:
    remove(ef2_crt_name);
    return 1;
}
