/*
 * texts.c
 *
 *  Created on: 25.05.2009
 *      Author: skoe
 */

#include <stdio.h>

#include "texts.h"


const char* apStrLowHigh[] =
{
        "Low",
        "High"
};

const char* apStrAbout[] =
{
        "EasyProg Version 1.2++",
        "",
        "(C) 2009 Thomas 'skoe' Giesel",
        NULL
};

const char* apStrUnsupportedCRTType[] =
{
        "Sorry, this CRT file type",
        "is not supported.",
        NULL
};

const char* apStrUnsupportedCRTData[] =
{
        "Sorry, this CRT file contains",
        "unsupported chip data.",
        NULL
};

const char* apStrWriteCRTFailed[] =
{
        "Failed to write the CRT image",
        "to flash.",
        NULL
};

const char* apStrFileTooShort[] =
{
        "This file seems to be",
        "too short.",
        NULL
};

const char* apStrWrongFlash[] =
{
        "A flash chip does not work",
        "or is not supported by the",
        "EasyAPI flash driver.",
        NULL
};

const char* apStrBadRAM[] =
{
        "The cartridge RAM at $DF00",
        "doesn't work correctly.",
        NULL
};

const char* apStrAskErase[] =
{
        "This will erase the current",
        "flash content! Are you sure?",
        "Press <Stop> to cancel,",
        "<Enter> to continue.",
        NULL
};

const char* apStrEraseFailed[] =
{
        "Flash erase failed,",
        "check your hardware.",
        NULL
};

const char* apStrFlashWriteFailed[] =
{
        "Write to flash failed,",
        "check your hardware.",
        NULL
};

const char* apStrFileOpenError[] =
{
        "Cannot open cartridge image file.",
        NULL
};

const char* apStrHeaderReadError[] =
{
        "Failed to read the cartridge",
        "header. The file seems to",
        "have a wrong type or may",
        "be damaged.",
        NULL
};

const char* apStrChipReadError[] =
{
        "Failed to read cartridge",
        "data. The file seems to",
        "have a wrong type or may",
        "be damaged.",
        NULL
};

const char* apStrWriteComplete[] =
{
        "Congratulations!",
        "Writing to flash completed.",
        NULL
};

const char* apStrEAPINotFound[] =
{
        "Failed to load EasyAPI driver",
        "(\"eapi-????????-??\").",
        "Using internal flash driver.",
        NULL
};

const char* apStrEAPIInvalid[] =
{
        "The EasyAPI driver on",
        "disk is invalid.",
        NULL
};

const char* pStrTestFailed = "Test failed";
