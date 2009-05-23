
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <fcntl.h>
#include <conio.h>

#include "easyprog.h"
#include "cart.h"
#include "screen.h"
#include "flashcode.h"
#include "flash.h"

/******************************************************************************/

/// Low/High flash chip menufacturer/device ID
uint16_t anFlashId[2];

/// Is != 0 if we didn't find the right flash chips
uint8_t  bWrongFlash;

/// String describes the current action
char strStatus[41];

/// buffer for up to 16 kByte
uint8_t aBankBuffer[16 * 1024];

/******************************************************************************/

static const char* apStrJumperTest[] =
{
        "Make sure the jumpers are set to",
        "\"auto\". Otherwise set them now.",
        NULL
};

static const char* apStrLowHigh[] =
{
        "Low",
        "High"
};

static const char* apStrWrongFlash[] =
{
        "A flash chip does not work",
        "or has a wrong type. Check",
        "jumpers and hardware, then",
        "run EasyProg again.",
        NULL
};

static const char* apStrEraseFailed[] =
{
        "Flash erase failed,",
        "check your hardware.",
        NULL
};

static const char* apStrFileOpenError[] =
{
        "Cannot open image file.",
        NULL
};

/******************************************************************************/
/**
 * Show a box with the current Flash type.
 */
static void showFlashTypeBox(uint8_t x, uint8_t y, uint8_t nChip)
{
    uint16_t id;

    textcolor(COLOR_LIGHTFRAME);
    screenPrintBox(16, y, 23, 3);
    textcolor(COLOR_FOREGROUND);

    id = anFlashId[nChip];

    gotoxy (2, y + 1);
    cprintf("%4s Flash ID:", apStrLowHigh[nChip]);

    gotoxy (17, y + 1);
    cprintf("%04X (%s)", id,
        id == FLASH_TYPE_AMD_AM29F040 ? "Am29F040(B)" : "unknown");
}


/******************************************************************************/
/**
 * Show or update a box with the current action.
 */
static void refreshStatusBox()
{
    textcolor(COLOR_LIGHTFRAME);
    screenPrintBox(9, 9, 30, 3);
    textcolor(COLOR_FOREGROUND);

    cputsxy(2, 10, "Status:");

    gotoxy (10, 10);
    cclear(28);
    gotoxy (10, 10);
    cputs(strStatus);
}


/******************************************************************************/
/**
 * Show the Screen which reports the Flash IDs.
 */
static void refreshMainScreen(void)
{
    screenPrintFrame();
    showFlashTypeBox(1, 3, 0);
    showFlashTypeBox(1, 6, 1);
    refreshStatusBox();
}


/******************************************************************************/
/**
 * Show the Screen asking for the Flash jumper setting.
 */
static void checkJumpers(void)
{
    refreshMainScreen();
    screenPrintDialog(apStrJumperTest);
    refreshMainScreen();
}


/******************************************************************************/
/**
 * Read Flash manufacturer and device IDs, print then on the screen.
 * If they are not okay, print an error message and set bWrongFlash.
 */
static void checkFlashTypes(void)
{
#ifdef EASYFLASH_FAKE
    anFlashId[0] = FLASH_TYPE_AMD_AM29F040;
    anFlashId[1] = FLASH_TYPE_AMD_AM29F040;
#else
    anFlashId[0] = flashCodeReadIds(ROM0_BASE);
    anFlashId[1] = flashCodeReadIds(ROM1_BASE_ULTIMAX);
#endif

    refreshMainScreen();

    if ((anFlashId[0] != FLASH_TYPE_AMD_AM29F040) ||
            (anFlashId[1] != FLASH_TYPE_AMD_AM29F040))
    {
        bWrongFlash = 1;
        screenPrintDialog(apStrWrongFlash);
        refreshMainScreen();
    }
}


/******************************************************************************/
/**
 * Set the status text and update the display.
 */
void setStatus(const char* pStrStatus)
{
    strncpy(strStatus, pStrStatus, sizeof(strStatus - 1));
    strStatus[sizeof(strStatus) - 1] = '\0';
    refreshStatusBox();
}


/******************************************************************************/
/**
 *
 */
void checkWriteImage(void)
{
    const char *pStrInput;
    char strFileName[FILENAME_MAX];
    FILE* fp;
    uint8_t nChip;
    uint16_t nOffset;
    uint8_t  nBank;
    uint8_t  nVal;
    uint16_t nAddress;
    uint16_t nStart;
    uint16_t nEnd;
    uint16_t nSize;
    ChipHeader chipHeader;

    pStrInput = screenReadInput("Write cartridge image", "Enter file name");
    refreshMainScreen();

    if (!pStrInput)
        return;

    strcpy(strFileName, pStrInput);

    sprintf(strStatus, "Checking %s...\n", strFileName);
    refreshStatusBox();

    fp = fopen(strFileName, "r");

    if (fp == NULL)
    {
        screenPrintDialog(apStrFileOpenError);
        return;
    }

    if (!readCartHeader(fp))
    {
        fclose(fp);
        return;
    }

    if (!eraseAll())
    {
        screenPrintDialog(apStrEraseFailed);
        fclose(fp);
        return;
    }

    sprintf(strStatus, "Reading next bank");
    refreshStatusBox();

    while (readNextChip(&chipHeader, aBankBuffer, fp))
    {
        nBank = chipHeader.bank[1];
        nAddress = 256 * chipHeader.loadAddr[0] + chipHeader.loadAddr[1];
        nSize = 256 * chipHeader.romLen[0] + chipHeader.romLen[1];

        nEnd = nAddress + nSize;

        // Chip 0 and Chip 1 needed?
        if ((nAddress == (uint16_t)ROM0_BASE) && (nSize > 0x2000))
        {
            // flash first chip
            nStart = 0;
            nEnd   = 0x2000;
            nChip  = 0;

            sprintf(strStatus, "Writing %u bytes to %02X:%X", 0x2000,
                    0, nChip);
            refreshStatusBox();

            for (nOffset = 0; nOffset < nEnd; ++nOffset)
            {
                flashWrite(nChip, nOffset, aBankBuffer[nOffset]);
            }

            // flash second chip
            nStart = 0x2000;
            nEnd   = nSize - 0x2000;
            nChip  = 1;
            sprintf(strStatus, "Writing %u bytes to %02X:%X", 0x2000,
                    0, nChip);
            refreshStatusBox();

            for (nOffset = 0; nOffset < nEnd; ++nOffset)
            {
                flashWrite(nChip, nOffset, aBankBuffer[nOffset + 0x2000]);
            }
        }
    }

    screenWaitOKKey();

    printCartInfo();
}


/******************************************************************************/
/**
 *
 */
int main(void)
{
    screenInit();
    checkJumpers();
    checkFlashTypes();

    if (bWrongFlash)
        for (;;);

    for (;;)
    {
        checkWriteImage();
        screenWaitOKKey();
    }

    return 0;
}
