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

#include "app.h"
#include "screen.h"
#include "texts.h"
#include "filedlg.h"
#include "util.h"

/* XSVF-Player */
#include "xsvfexec.h"
#include "host.h"

#define RamPage ((unsigned char *)0xde00)
#define BankLo  (*(unsigned char *)0xdffe)
#define BankHi  (*(unsigned char *)0xdfff)

/******************************************************************************/
static void showAbout(void);
static uint8_t returnTrue(void);
static void playFileFast(void);
static void playFileVerbose(void);
static void playFile(uint8_t bVerbose);

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
        "XSVF playback completed.",
        NULL
};

static const char* apStrUploadError[] =
{
        "Bad news,",
        "XSVF playback failed.",
        NULL
};

/******************************************************************************/

ScreenMenuEntry aMainMenuEntries[] =
{
        {
            "1 Play XSVF file (fast)",
            playFileFast,
            returnTrue
        },
        {
            "2 Play XSVF file (verbose)",
            playFileVerbose,
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
 * Show or refresh the screen.
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

    cputsxy(1, 4, "File name:");
    screenPrintBox(12, 3, 27, 3);
    cputsxy(13, 4, strFileName);

    cputsxy(1, 7, "Bytes read:");
    screenPrintBox(12, 6, 11, 3);

    cputsxy(1, 17, "TDI:");
    cputsxy(1, 18, "TDO:");
    cputsxy(1, 19, "EXP:");
    cputsxy(1, 20, "MSK:");
    screenPrintBox(5, 16, 34, 6);

    screenPrintBox(LOG_WINDOW_X - 1, LOG_WINDOW_Y - 3,
                   LOG_WINDOW_W + 2, 3);
    screenPrintBox(LOG_WINDOW_X - 1, LOG_WINDOW_Y - 1,
                   LOG_WINDOW_W + 2, LOG_WINDOW_H + 2);
    screenPrintSepLine(LOG_WINDOW_X - 1, LOG_WINDOW_X + LOG_WINDOW_W,
                       LOG_WINDOW_Y - 1);
    cputsxy(LOG_WINDOW_X, LOG_WINDOW_Y - 2, "Messages");


    cputsxy(2, 14, "SM:");
    screenPrintBox(5, 13, 18, 3);

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
 * Play an XSVF file.
 */
static void playFileFast(void)
{
    playFile(0);
}

/******************************************************************************/
/**
 * Play an XSVF file.
 */
static void playFileVerbose(void)
{
    playFile(1);
}

/******************************************************************************/
/**
 * Play an XSVF file.
 */
static void playFile(uint8_t bVerbose)
{
    uint8_t  rv;
    int      rc;

    do
    {
        rv = fileDlg(strFileName, "XSVF");
        if (!rv)
            return;

        rv = utilOpenFile(fileDlgGetDriveNumber(), strFileName);
        if (rv == 1)
            screenPrintSimpleDialog(apStrFileOpenError);
    }
    while (rv != OPEN_FILE_OK);

    refreshMainScreen();
    setStatus("Checking file");

    /* Platform dependent initialization. */
    rc = XsvfInit();
    XsvfSetVerbose(bVerbose);

    if (rc == 0) {
        /* Execute XSVF commands. */
        rc = Execute();
    }

    /* Platform dependent clean up. */
    XsvfExit(rc);

    utilCloseFile();

    screenPrintSimpleDialog(rc ? apStrUploadError : apStrUploadComplete);
}

/******************************************************************************/
/**
 *
 */
int main(void)
{
    char key;
    uint8_t nDrive;
    const ScreenMenuEntry* pSeletedEntry;

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

        pSeletedEntry = NULL;
        key = cgetc();
        switch (key)
        {
        case 'm':
            pSeletedEntry = screenDoMenu(1, 2, aMainMenuEntries);
            refreshMainScreen();
            break;

        case 'h':
            pSeletedEntry = screenDoMenu(7, 2, aHelpMenuEntries);
            refreshMainScreen();
            break;
        }

        if (pSeletedEntry)
            pSeletedEntry->pFunction();
    }
    return 0;
}
