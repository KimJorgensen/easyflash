
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


/******************************************************************************/

static const char* apStrJumperTest[] =
{
        "Make sure the jumpers are set to",
        "\"auto\". Otherwise set them now",
        "and press <Enter>.",
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
static void showStatusBox()
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
static void showMainScreen(void)
{
    screenPrintFrame();
    showFlashTypeBox(1, 3, 0);
    showFlashTypeBox(1, 6, 1);
    showStatusBox();
}


/******************************************************************************/
/**
 * Show the Screen asking for the Flash jumper setting.
 */
static void checkJumpers(void)
{
    showMainScreen();
    screenPrintDialog(apStrJumperTest);
    showMainScreen();
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

    showMainScreen();

    if ((anFlashId[0] != FLASH_TYPE_AMD_AM29F040) ||
            (anFlashId[1] != FLASH_TYPE_AMD_AM29F040))
    {
        bWrongFlash = 1;
        screenPrintDialog(apStrWrongFlash);
        showMainScreen();
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
    showStatusBox();
}


/******************************************************************************/
/**
 *
 */
int main(void)
{
	char strFileName[40];
    int fd;
    uint8_t nChip;
    uint16_t nOffset;

    screenInit();
    checkJumpers();
    checkFlashTypes();

    if (bWrongFlash)
    {
        for (;;);
    }

    if (!eraseAll())
    {
        screenPrintDialog(apStrEraseFailed);
        showMainScreen();
        for (;;);
    }

    for (nChip = 0; nChip < 2; ++nChip)
    {
        for (nOffset = 0; nOffset < 8 * 1024; ++nOffset)
        {
            if ((nOffset & 0xff) == 0)
            {
                sprintf(strStatus, "Writing: %02X:%X:%04X", 0, nChip, nOffset);
                setStatus(strStatus);
            }
            if (!flashWrite(nChip, nOffset, nOffset & 0xff))
            {
                for (;;)
                    ;
            }
        }
    }

    // impossible
    flashWrite(0, 3, 255);

    for (;;);
#if 0
	printf("Cartridge file name:");
    scanf("%s", strFileName);

    printf("Checking %s...\n", strFileName);

    fd = open(strFileName, O_RDONLY);

    if (fd == -1)
    {
        printf("Cannot open input file\n");
        return 1;
    }

    if (!readCartHeader(fd))
        return 1;

    eraseFlash();

    while (readNextChipHeader(fd));
    printCartInfo();
#endif
    return 0;
}
