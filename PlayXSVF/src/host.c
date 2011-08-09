/*
 * Copyright (C) 2010 by Thomas 'skoe' Giesel
 * modified for C64
 *
 * Copyright (C) 2004 by egnite Software GmbH. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the copyright holders nor the names of
 *    contributors may be used to endorse or promote products derived
 *    from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY EGNITE SOFTWARE GMBH AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL EGNITE
 * SOFTWARE GMBH OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
 * OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
 * AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
 * THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * For additional information see http://www.ethernut.de/
 */

#include <conio.h>
#include <string.h>

#include "util.h"
#include "screen.h"

#include "xsvf.h"
#include "tapsm.h"
#include "host.h"

/*!
 * \file host.c
 * \brief Platform dependent routines.
 */

/*!
 * \addtogroup xgHost
 */
/*@{*/

/*!
 * \brief XSVF command names.
 *
 * Used for debugging output.
 */
static char *cmd_names[] = {
    "XCOMPLETE",
    "XTDOMASK",
    "XSIR",
    "XSDR",
    "XRUNTEST",
    "UNKNOWN",
    "UNKNOWN",
    "XREPEAT",
    "XSDRSIZE",
    "XSDRTDO",
    "XSETSDRMASKS",
    "XSDRINC",
    "XSDRB",
    "XSDRC",
    "XSDRE",
    "XSDRTDOB",
    "XSDRTDOC",
    "XSDRTDOE",
    "XSTATE",
    "XENDIR",
    "XENDDR",
    "XSIR2",
    "XCOMMENT",
    "XWAIT",
    "UNKNOWN"
};

/*!
 * \brief TAP state names.
 *
 * Used for debugging output.
 */
static char *tap_names[] = {
    "Test-Logic-Reset",
    "Run-Test-Idle   ",
    "Select-DR-Scan  ",
    "Capture-DR      ",
    "Shift-DR        ",
    "Exit1-DR        ",
    "Pause-DR        ",
    "Exit2-DR        ",
    "Update-DR       ",
    "Select-IR-Scan  ",
    "Capute-IR       ",
    "Shift-IR        ",
    "Exit1-IR        ",
    "Pause-IR        ",
    "Exit2-IR        ",
    "Update-IR       ",
    "Unknown         "
};

// wenn du auf die stiftleiste guckst ist links der jumper und dann von links nach rechts:
// Pin1=GND Pin2=3,3V PIN3=TDO (PB0)  Pin4=TDI (PB4) Pin5=TMS (PB6)  Pin6=TCK (PB7)
#define TCK_BIT (1 << 7)
#define TMS_BIT (1 << 6)
#define TDI_BIT (1 << 4)
#define TDO_BIT (1 << 0)

// 1 = Pin PBx set to Output, 0 = Input
#define CIA2_DDRB (*(uint8_t*)0xDD03)

#define CIA2_DPB (*(uint8_t*)0xDD01)

/*!
 * \brief Copy of data port value.
 */
static uint8_t dpb_val;

/*!
 * \brief Number of bytes read so far.
 */
static uint32_t bytesRead;

/*!
 * \brief Last error occured in this module.
 */
static int xsvf_err;

/*!
 * \brief Last error occured in this module.
 */
static uint8_t verbose;


void set_tms(void)
{
    dpb_val &= ~TMS_BIT;
    CIA2_DPB = dpb_val;
}

void clr_tms(void)
{
    dpb_val |= TMS_BIT;
    CIA2_DPB = dpb_val;
}

void set_tdi(void)
{
    dpb_val &= ~TDI_BIT;
    CIA2_DPB = dpb_val;
}

void clr_tdi(void)
{
    dpb_val |= TDI_BIT;
    CIA2_DPB = dpb_val;
}

void set_tck(void)
{
    dpb_val &= ~TCK_BIT;
    CIA2_DPB = dpb_val;
}

void clr_tck(void)
{
    dpb_val |= TCK_BIT;
    CIA2_DPB = dpb_val;
}

uint8_t get_tdo(void)
{
    uint8_t v = !(CIA2_DPB & TDO_BIT);
    return v;
}


static void XsvfPrintBytesRead(void)
{
    gotoxy(14, 7);
    cprintf("%8ld", bytesRead);
}

/*!
 * \brief Initialize the platform dependant interface.
 *
 * All required hardware initializations should be done in this
 * routine. We may also initiate debug output.
 *
 * \return Zero on success, otherwise an error code is returned.
 */
int XsvfInit(void)
{
    /*
     * Prepare standard output and display a banner.
     */

    XsvfLog(XSVF_LOG_INFO, "Running...");

    /* initialize TCK = 1, rest = 0 to high (inverted) */
    dpb_val = (TDI_BIT | TMS_BIT);
    CIA2_DPB = dpb_val;

    /* Set the right bits to output */
    CIA2_DDRB = TDI_BIT | TMS_BIT | TCK_BIT;

    bytesRead = 0;

    return 0;
}

/*!
 * \brief Shutdown the platform dependant interface.
 *
 * On most embedded platforms this routine will never return.
 *
 * \param rc Programming result code.
 */
void XsvfExit(int rc)
{
    /* Set all bits to input */
    CIA2_DDRB = 0;

    /* Display programming result. */
    if(rc) {
        XsvfLog(XSVF_LOG_ERROR, "ERROR %d", rc);
    }
    else {
        XsvfLog(XSVF_LOG_INFO, "OK");
    }
}

void XsvfSetVerbose(uint8_t v)
{
    verbose = v;
}

/*!
 * \brief Retrieve the last error occured in this module.
 *
 * \return Error code or 0 if no error occured.
 */
int XsvfGetError(void)
{
    return xsvf_err;
}

/*!
 * \brief Get next byte from XSVF buffer.
 *
 * Call XsvfGetError() to check for errors,
 *
 * \return Byte value.
 */
uint8_t XsvfGetByte(void)
{
    uint8_t rc;

    if(utilRead(&rc, sizeof(rc)) != sizeof(rc)) {
        xsvf_err = XE_DATAUNDERFLOW;
    }

    XsvfLog(XSVF_LOG_DEBUG, "[%u]", rc);
    ++bytesRead;
    XsvfPrintBytesRead();

    return rc;
}

/*!
 * \brief Get next command byte from XSVF buffer.
 *
 * \return XSVF command or XUNKNOWN if an error occured.
 */
uint8_t XsvfGetCmd(void)
{
    uint8_t rc;

    //printf("get command\n");
    if(utilRead(&rc, sizeof(rc)) != sizeof(rc) || rc >= XUNKNOWN) {
        rc = XUNKNOWN;
    }

    XsvfLog(XSVF_LOG_DEBUG, cmd_names[rc]);
    ++bytesRead;
    XsvfPrintBytesRead();

    return rc;
}

/*!
 * \brief Get next byte from XSVF buffer and select a TAP state.
 *
 * \param state0 Returned state, if the byte value is zero.
 * \param state1 Returned state, if the byte value is one.
 * 
 * \return TAP state or UNKNOWN_STATE if an error occured.
 */
uint8_t XsvfGetState(uint8_t state0, uint8_t state1)
{
    uint8_t rc;

    if(utilRead(&rc, sizeof(rc)) != sizeof(rc) || rc > 1) {
        rc = UNKNOWN_STATE;
    }
    else if(rc) {
        rc = state1;
    }
    else {
        rc = state0;
    }

    ++bytesRead;
    XsvfPrintBytesRead();
    XsvfLog(XSVF_LOG_DEBUG, "<%d>", rc);

    return rc;
}

/*!
 * \brief Get next short value from XSVF buffer.
 *
 * Call XsvfGetError() to check for errors,
 *
 * \return Short value.
 */
short XsvfGetShort(void)
{
    uint16_t val, rc;

    if(utilRead(&val, sizeof(val)) != sizeof(val)) {
        xsvf_err = XE_DATAUNDERFLOW;
        return -1;
    }

    ((uint8_t*)&rc)[0] = ((uint8_t*)&val)[1];
    ((uint8_t*)&rc)[1] = ((uint8_t*)&val)[0];

    bytesRead += 2;
    XsvfPrintBytesRead();
    XsvfLog(XSVF_LOG_DEBUG, "[%d]", rc);

    return rc;
}

/*!
 * \brief Get next long value from XSVF buffer.
 *
 * Call XsvfGetError() to check for errors,
 *
 * \return Long value.
 */
long XsvfGetLong(void)
{
    uint32_t rc, val;

    if(utilRead(&val, sizeof(val)) != sizeof(val)) {
        xsvf_err = XE_DATAUNDERFLOW;
        rc = 0;
    }
    else {
        ((uint8_t*)&rc)[0] = ((uint8_t*)&val)[3];
        ((uint8_t*)&rc)[1] = ((uint8_t*)&val)[2];
        ((uint8_t*)&rc)[2] = ((uint8_t*)&val)[1];
        ((uint8_t*)&rc)[3] = ((uint8_t*)&val)[0];
    }

    bytesRead += 4;
    XsvfPrintBytesRead();
    XsvfLog(XSVF_LOG_DEBUG, "[%ld]", rc);

    return rc;
}

/*!
 * \brief Read a specified number of bits from XSVF buffer.
 *
 * \param buf Pointer to the buffer which receives the bit string.
 * \param num Number of bits to read.
 *
 * \return Error code or 0 if no error occured.
 */
int XsvfReadBitString(void *buf, int num)
{
    int len = (num + 7) / 8;

    if (len > MAX_BITVEC_BYTES) {
        xsvf_err = len = XE_DATAOVERFLOW;
    }
    else if(utilRead(buf, len) < len) {
        xsvf_err = len = XE_DATAUNDERFLOW;
    }

    bytesRead += len;
    XsvfPrintBytesRead();

    return len;
}

/*!
 * \brief Skip comment in the XSVF buffer.
 *
 * \return Error code or 0 if no error occured.
 */
int XsvfSkipComment(void)
{
    uint8_t ch;

    for(;;) {
        if (utilRead(&ch, sizeof(ch)) != sizeof(ch)) {
            return (xsvf_err = XE_DATAUNDERFLOW);
        }
        ++bytesRead;
        if (ch == 0) {
            break;
        }
#ifdef XSVF_DEBUG
        putchar(ch);
#endif
    }

    XsvfPrintBytesRead();
    return 0;
}

/*!
 * \brief Microsecond delay.
 *
 * \param msecs Number of milliseconds.
 */
void __fastcall__ XsvfDelay(uint16_t msecs)
{
    while (msecs)
    {
        --msecs;
        /* sleep 1 ms */
        ((void (*)(void))0xEEB3)();
    }
}

/*!
 * \brief Print a log message.
 *
 * \param level  Log level.
 * \param format Format string like printf.
 */
void XsvfLog(uint8_t level, const char* format, ...)
{
    static uint8_t line;
    va_list ap;

    if (!verbose && level == XSVF_LOG_DEBUG)
        return;

    if (line < LOG_WINDOW_H - 1)
        ++line;
    else
        XsvfLogScroll();

    gotoxy(LOG_WINDOW_X, line + LOG_WINDOW_Y);

    va_start(ap, format);
    vcprintf(format, ap);
    va_end(ap);
    cputs("\r\n");
}

/*!
 * \brief Print a single bit string to the given position.
 *
 * \param x     Screen x position.
 * \param y     Screen y position.
 * \param len   Length in bits.
 * \param val   Value to print.
 */
static void XsvfPrintBitString(uint8_t x, uint8_t y, uint8_t len,
                               uint8_t* val)
{
    uint8_t i;
    uint8_t bytes;

    utilStr[0] = '\0';

    if (val)
        bytes = (len + (uint8_t)7) / (uint8_t)8;
    else
        bytes = 0;

    for (i = 0; i < bytes; ++i)
        utilAppendHex2(val[i]);

    cputsxy(x, y, utilStr);
    cclear(2 * (MAX_BITVEC_BYTES - bytes));
}

/*!
 * \brief Print all bit strings.
 *
 * \param len       Length in bits.
 * \param tdi_val   TDI value to print.
 * \param tdo_val   TDO value to print.
 * \param tdo_exp   Expected TDO value. Set to NULL if not available.
 * \param tdo_msk   Used to mask out don't care TDO values.
 */
void XsvfPrintBitStrings(uint8_t len,
                         uint8_t* tdi_val, uint8_t* tdo_val,
                         uint8_t* tdo_exp, uint8_t* tdo_msk)
{
    if (verbose) {
        XsvfPrintBitString(6, 17, len, tdi_val);
        XsvfPrintBitString(6, 18, len, tdo_val);
        XsvfPrintBitString(6, 19, len, tdo_exp);
        XsvfPrintBitString(6, 20, len, tdo_msk);

    }
}

/*!
 * \brief Print all bit strings.
 *
 * Print the current TAP state.
 */
void XsvfShowTapState(uint8_t tapState)
{
    if (verbose) {
        cputsxy(6, 14, tap_names[tapState]);

    }
}


/*@}*/
