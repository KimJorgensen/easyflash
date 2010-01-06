/*
 * GeoUpload - geoupload.c - The main module
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

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <conio.h>
#include <stdlib.h>
#include <cbm.h>

#include "geoupload.h"
#include "screen.h"
#include "texts.h"
#include "filedlg.h"
#include "util.h"

#define RamPage ((unsigned char *)0xde00)
#define BankLo  (*(unsigned char *)0xdffe)
#define BankHi  (*(unsigned char *)0xdfff)

/******************************************************************************/
static void showAbout(void);
static uint8_t returnTrue(void);
static void uploadImage(void);

/******************************************************************************/

/******************************************************************************/
/* Static variables */

// String describes the current action
static char strStatus[41];

static const char* apStrFileOpenError[] =
{
        "Cannot open this file.",
        NULL
};

static const char* apStrUploadComplete[] =
{
        "Congratulations!",
        "Upload completed.",
        NULL
};

/******************************************************************************/

ScreenMenuEntry aMainMenuEntries[] =
{
        {
            "Upload RAW image",
            uploadImage,
            returnTrue
        },
        {
            "Upload EasySplit image",
            uploadImage,
            returnTrue
        },
        {
            "Reset",
            utilReset,
            returnTrue
        },
        { NULL, NULL, 0 }
};


ScreenMenuEntry aHelpMenuEntries[] =
{
        {
            "About",
            showAbout,
            returnTrue
        },
        { NULL, NULL, 0 }
};


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
 * Show or refresh the Screen which reports the Flash IDs.
 */
void refreshMainScreen(void)
{
    screenPrintFrame();

    // menu entries
    gotoxy (1, 1);
    textcolor(COLOR_EXTRA);
    cputc('M');
    textcolor(COLOR_FOREGROUND);
    cputs("enu  ");

    textcolor(COLOR_EXTRA);
    cputc('H');
    textcolor(COLOR_FOREGROUND);
    cputs("elp");

    refreshStatusLine();
}


/******************************************************************************/
/**
 * Always return 1.
 */
static uint8_t returnTrue(void)
{
   return 1;
}


/******************************************************************************/
/**
 * Show the about dialog.
 */
static void showAbout(void)
{
    screenPrintSimpleDialog(apStrAbout);
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
 * Execute an action according to the given menu ID.
 */
static void __fastcall__ execMenu(uint8_t x, uint8_t y,
                                  const ScreenMenuEntry* pMenuEntries)
{
    screenDoMenu(x, y, pMenuEntries);
    refreshMainScreen();
}


/******************************************************************************/
/**
 * Upload an image to GeoRAM.
 */
static void uploadImage(void)
{
    uint8_t  rv;
    uint16_t nPage;
    uint16_t nBytes;

    do
    {
        rv = fileDlg(strFileName, "a");
        if (!rv)
            return;

        rv = utilOpenFile(fileDlgGetDriveNumber(), strFileName);
        if (rv == 1)
            screenPrintSimpleDialog(apStrFileOpenError);
    }
    while (rv != OPEN_FILE_OK);

    refreshMainScreen();
    setStatus("Checking file");


    nPage = 0;
    for (;;)
    {
        BankLo = (nPage & 0x3f);
        BankHi = (nPage >> 6) & 0xff;

        nBytes = utilRead(RamPage, 0x100);
        if (!nBytes)
            break;

        nPage++;
        strcpy(utilStr, "Page ");
        utilAppendDecimal(nPage);
        strcpy(strStatus, utilStr);
        refreshStatusLine();
    }

    utilCloseFile();
    screenPrintSimpleDialog(apStrUploadComplete);
}

/******************************************************************************/
/**
 *
 */
int main(void)
{
    char key;
    uint8_t nDrive;

    screenInit();
    refreshMainScreen();

    nDrive = *(uint8_t*)0xba;
    if (nDrive < 8)
        nDrive = 8;
    fileDlgSetDriveNumber(nDrive);

    screenBing();

    for (;;)
    {
        setStatus("Ready. Press <m> for Menu.");

        key = cgetc();
        switch (key)
        {
        case 'm':
            execMenu(1, 2, aMainMenuEntries);
            break;

        case 'h':
            execMenu(7, 2, aHelpMenuEntries);
            break;
        }
    }
    return 0;
}
