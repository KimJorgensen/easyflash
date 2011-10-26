/*
 * EasyProg - texts.c - Texts
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

#include "texts.h"


const char* apStrLowHigh[] =
{
        "Low",
        "High"
};

const char* apStrAbout[] =
{
        "Version " EFVERSION,
        "",
        "(compiled: " __DATE__ " " __TIME__ ")",
        "",
        "(C) 2009 Thomas 'skoe' Giesel",
        "under zlib license",
        NULL
};

const char* apStrBadRAM[] =
{
        "The cartridge RAM at $DF00",
        "doesn't work correctly.",
        NULL
};

const char* pStrTestFailed = "Test failed";


const char* apStrTestEndless[] =
{
        "This test runs endlessly.",
        "It will show a message",
        "if a problem occurs.",
        NULL
};

