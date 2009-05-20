/*
 * cart.c - Functions to access crt images
 *
 * (c) 2009 Thomas Giesel
 *
 * This software is provided 'as-is', without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 *
 * Thomas Giesel skoe@directbox.com
 */

#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>

#include "cart.h"

// global variables to make the code more compact on cc65
uint8_t      internalCartType;
CartHeader   cartHeader;
uint8_t      nChips;
uint32_t     nCartBytes;

static const char strCartSignature[16] = CART_SIGNATURE;
static const char strChipSignature[4] = CHIP_SIGNATURE;


uint8_t readCartHeader(int fd)
{
    if (read(fd, &cartHeader, sizeof(cartHeader)) != 
        sizeof(cartHeader))
    {
        printf("??? Reading file header failed\n");
        return 0;
    }
    if (memcmp(cartHeader.signature, strCartSignature,
               sizeof(strCartSignature)) != 0)
    {
        printf("??? Wrong signature, file damaged?\n");
        return 0;
    }

    // Evaluate the cartridge type
    internalCartType = INTERNAL_CART_TYPE_UNKNOWN;
    if (cartHeader.type[1] == CART_TYPE_NORMAL)
    {
        if (!cartHeader.exromLine)
        {
            if (cartHeader.gameLine)
            {
                internalCartType = INTERNAL_CART_TYPE_NORMAL_8K;
            }
        }
        else
        {
            if (cartHeader.gameLine)
            {
                internalCartType = INTERNAL_CART_TYPE_NORMAL_16K;
            }
            else
            {
                internalCartType = INTERNAL_CART_TYPE_ULTIMAX;
            }
        }
    }
    else if (cartHeader.type[1] == CART_TYPE_OCEAN1)
    {
        internalCartType = INTERNAL_CART_TYPE_OCEAN1;
    }

    return 1;
}

void eraseFlash()
{
}

uint8_t readNextChipHeader(int fd)
{
    uint16_t n, i;
    uint8_t dummy;
    ChipHeader chipHeader;

    if (read(fd, &chipHeader, sizeof(chipHeader)) !=
        sizeof(chipHeader))
    {
        // EOF
        return 0;
    }

    if (memcmp(chipHeader.signature, strChipSignature, 
               sizeof(strChipSignature)) != 0)
    {
        printf("??? Wrong chip signature, file damaged?\n");
        return 0;
    }

    printf("Found chip/bank\n");
    printf("Bank number :  %4d\n", chipHeader.bank[1]);
    n = 256 * chipHeader.loadAddr[0] + chipHeader.loadAddr[1];
    printf("Load address: $%04X\n", n);
    n = 256 * chipHeader.romLen[0] + chipHeader.romLen[1];
    printf("Bank size   : $%04X (%d kByte)\n", n, n / 1024);
    nCartBytes += n;
    ++nChips;

    // skip rest of bank
#if 0 // lseek missing in cc65?
    if (lseek(fd, n, SEEK_CUR) == -1)
#endif
    for (i = 0; i < n; ++i)
    {
        if (read(fd, &dummy, 1) != 1)
        {
            printf("??? Chip data incomplete, file damaged?\n");
            return 0;
        }
    }

    return 1;
}

void printCartInfo()
{
    const char* pStr;

    // fixme: name is not 0-terminated if it is 32 chars long
    printf("Name: %s\n", cartHeader.name);

    switch (internalCartType)
    {
    case INTERNAL_CART_TYPE_NORMAL_8K:
        pStr = "Normal, up to 8 kByte";
        break;

    case INTERNAL_CART_TYPE_NORMAL_16K:
        pStr = "Normal, up to 16 kByte";
        break;

    case INTERNAL_CART_TYPE_ULTIMAX:
        pStr = "Ultimax, up to 16 kByte";
        break;

    default:
        pStr = "Not supported";
    }
    printf("Type: %s\n", pStr);

    printf("Number of chips/banks: %d\n", nChips);
    printf("Size                 : %d kByte\n", nCartBytes / 1024);
}

