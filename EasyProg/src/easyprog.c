
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <conio.h>
#include <stdlib.h>
#include <cbm.h>

#include "easyprog.h"
#include "cart.h"
#include "screen.h"
#include "flashcode.h"
#include "flash.h"
#include "texts.h"

/******************************************************************************/

// Low/High flash chip manufacturer/device ID
uint16_t anFlashId[2];

/******************************************************************************/
/* Static variables */

// String describes the current action
static char strStatus[41];

// buffer for up to 16 kByte
static uint8_t aBankBuffer[16 * 1024];

// Index to the currently chosen menu entry
static uint8_t nMenuSelection;

/******************************************************************************/

ScreenMenuEntry aMainMenuEntries[] =
{
        { EASYPROG_MENU_ENTRY_WRITE_CRT,  "Write cartridge image" },
        { EASYPROG_MENU_ENTRY_CHECK_TYPE, "Check flash type" },
        { EASYPROG_MENU_ENTRY_ERASE_ALL,  "Erase all" },
        { EASYPROG_MENU_ENTRY_QUIT,       "Quit" },
        { 0, NULL }
};


ScreenMenuEntry aHelpMenuEntries[] =
{
        { EASYPROG_MENU_ENTRY_ABOUT,      "About" },
        { 0, NULL }
};

/******************************************************************************/
/**
 * Show a box with the current Flash type.
 */
static void showFlashTypeBox(uint8_t y, uint8_t nChip)
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
static void refreshStatusLine(void)
{
    gotoxy (1, 23);
    cputs(strStatus);
    cclear(39 - wherex());
}


/******************************************************************************/
/**
 * Show the Screen which reports the Flash IDs.
 */
static void refreshMainScreen(void)
{
    screenPrintFrame();
    showFlashTypeBox(15, 0);
    showFlashTypeBox(18, 1);
    refreshStatusLine();

    gotoxy (1, 1);
    textcolor(COLOR_EXTRA);
    cputc('M');
    textcolor(COLOR_FOREGROUND);
    cputs("enu  ");

    textcolor(COLOR_EXTRA);
    cputc('H');
    textcolor(COLOR_FOREGROUND);
    cputs("elp");
}


/******************************************************************************/
/**
 * Read Flash manufacturer and device IDs, print then on the screen.
 * If they are not okay, print an error message and return 0.
 * If everything is okay, return 1.
 */
static uint8_t checkFlashType(void)
{
#ifdef EASYFLASH_FAKE
    anFlashId[0] = FLASH_TYPE_AMD_AM29F040;
    anFlashId[1] = FLASH_TYPE_AMD_AM29F040;
#else
    anFlashId[0] = flashCodeReadIds(ROM0_BASE);
    anFlashId[1] = flashCodeReadIds(ROM1_BASE_ULTIMAX);
#endif

    if ((anFlashId[0] != FLASH_TYPE_AMD_AM29F040) ||
            (anFlashId[1] != FLASH_TYPE_AMD_AM29F040))
    {
        screenPrintSimpleDialog(apStrWrongFlash);
        refreshMainScreen();
        return 0;
    }

    refreshMainScreen();
    return 1;
}


/******************************************************************************/
/**
 * Set the status text and update the display.
 */
void __fastcall__ setStatus(const char* pStrStatus)
{
    strncpy(strStatus, pStrStatus, sizeof(strStatus - 1));
    strStatus[sizeof(strStatus) - 1] = '\0';
    refreshStatusLine();
}


/******************************************************************************/
/**
 *
 */
void checkWriteImage(void)
{
    const char *pStrInput;
    char strFileName[FILENAME_MAX];
    uint8_t lfn, rv;
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

    sprintf(strStatus, "Checking %s", strFileName);
    refreshStatusLine();

    lfn = 2;

    rv = cbm_open(lfn, 8, CBM_READ, strFileName);

    if (rv)
    {
        screenPrintSimpleDialog(apStrFileOpenError);
        return;
    }

    setStatus("Reading header");

    if (!readCartHeader(lfn))
    {
        screenPrintSimpleDialog(apStrHeaderReadError);
        cbm_close(lfn);
        return;
    }

    setStatus("Erasing flash memory");

    if (!eraseAll())
    {
        screenPrintSimpleDialog(apStrEraseFailed);
        cbm_close(lfn);
        return;
    }

    sprintf(strStatus, "Reading chip data");
    refreshStatusLine();

    do
    {
        rv = readNextChip(&chipHeader, aBankBuffer, lfn);
        if (rv == CART_RV_OK)
        {
            sprintf(strStatus, "Flashing chip data");
            refreshStatusLine();

            nBank = chipHeader.bank[1];
            nAddress = 256 * chipHeader.loadAddr[0] + chipHeader.loadAddr[1];
            nSize = 256 * chipHeader.romLen[0] + chipHeader.romLen[1];

            nEnd = nAddress + nSize;

            // Chip 0 and Chip 1 needed?
            if ((nAddress == (uint16_t)ROM0_BASE) && (nSize > 0x2000))
            {
                // flash first chip
                nStart = 0;
                nEnd = 0x2000;
                nChip = 0;

                sprintf(strStatus, "Writing %u bytes to %02X:%X", 0x2000,
                        0, nChip);
                refreshStatusLine();

                for (nOffset = 0; nOffset < nEnd; ++nOffset)
                {
                    flashWrite(nChip, nOffset, aBankBuffer[nOffset]);
                }

                // flash second chip
                nStart = 0x2000;
                nEnd = nSize - 0x2000;
                nChip = 1;
                sprintf(strStatus, "Writing %u bytes to %02X:%X", 0x2000,
                        0, nChip);
                refreshStatusLine();

                for (nOffset = 0; nOffset < nEnd; ++nOffset)
                {
                    flashWrite(nChip, nOffset, aBankBuffer[nOffset + 0x2000]);
                }
            }
            else if (rv == CART_RV_ERR)
            {
                screenPrintSimpleDialog(apStrChipReadError);
            }
        }
    } while (rv == CART_RV_OK);

    cbm_close(lfn);


    //screenWaitKey(BUTTON_ENTER);

    //printCartInfo();
}


/******************************************************************************/
/**
 * Execute the currently selected menu entry.
 */
void execMenuEntry(void)
{
    switch (nMenuSelection)
    {
    case EASYPROG_MENU_ENTRY_CHECK_TYPE:
        checkFlashType();
        break;

    case EASYPROG_MENU_ENTRY_ERASE_ALL:
        if (checkFlashType())
        {
            checkWriteImage();
        }
        break;
    }
}


/******************************************************************************/
/**
 * Execute an action according to the given menu ID.
 */
static void __fastcall__ execMenu(uint8_t x, uint8_t y,
                                  const ScreenMenuEntry* pMenuEntries)
{
    switch (screenDoMenu(x, y, pMenuEntries))
    {
    case EASYPROG_MENU_ENTRY_WRITE_CRT:
        checkFlashType();
        checkWriteImage();
        break;

    case EASYPROG_MENU_ENTRY_CHECK_TYPE:
        checkFlashType();
        break;

    case EASYPROG_MENU_ENTRY_ERASE_ALL:
        checkFlashType();
        eraseAll();
        break;

    case EASYPROG_MENU_ENTRY_QUIT:
        clrscr();
        exit(0);
        break;

    case EASYPROG_MENU_ENTRY_ABOUT:
        screenPrintSimpleDialog(apStrAbout);
        break;

    default:
        break;
    }

    refreshMainScreen();
}


/******************************************************************************/
/**
 *
 */
int main(void)
{
    char key;

    screenInit();
    refreshMainScreen();

    for (;;)
    {
        setStatus("Ready. Press <m> for Menu.");

        key = cgetc();
        switch (key)
        {
        case 'm':
            execMenu(3, 2, aMainMenuEntries);
            break;

        case 'h':
            execMenu(7, 2, aHelpMenuEntries);
            break;

        default:
            break;
        }
    }
}
