#ifndef _HOST_H_
#define _HOST_H_

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

/*
 * Changes by tgiesel:
 * - Replaced non-standard types with stdint-style
 */

/*!
 * \file host.h
 * \brief Platform header file.
 */

/*!
 * \addtogroup xgXEDefs
 */
/*@{*/


/*@}*/

/*!
 * \addtogroup xgHost
 */
/*@{*/

#include <stdint.h>


#define SET_TMS() set_tms()
#define CLR_TMS() clr_tms()
#define SET_TDI() set_tdi()
#define CLR_TDI() clr_tdi()
#define SET_TCK() set_tck()
#define CLR_TCK() clr_tck()

#define GET_TDO() get_tdo()


/*! \brief Set TMS high and toggle TCK. */
#define SET_TMS_TCK()   { SET_TMS(); CLR_TCK(); SET_TCK(); }

/*! \brief Set TMS low and toggle TCK. */
#define CLR_TMS_TCK()   { CLR_TMS(); CLR_TCK(); SET_TCK(); }


/*! \brief Log level: Debug information */
#define XSVF_LOG_DEBUG 0

/*! \brief Log level: Information */
#define XSVF_LOG_INFO  1

/*! \brief Log level: Error */
#define XSVF_LOG_ERROR 2

/*! \brief First display column for log output. */
#define LOG_WINDOW_X 24

/*! \brief First display line for log output. */
#define LOG_WINDOW_Y 9

/*! \brief Width of log output. */
#define LOG_WINDOW_W 14

/*! \brief Height log output. */
#define LOG_WINDOW_H 6

void set_tms(void);
void clr_tms(void);
void set_tdi(void);
void clr_tdi(void);
void set_tck(void);
void clr_tck(void);
uint8_t get_tdo(void);

extern int XsvfInit(void);
extern void XsvfExit(int rc);
extern void XsvfSetVerbose(uint8_t v);

extern int XsvfGetError(void);
extern uint8_t XsvfGetCmd(void);
extern uint8_t XsvfGetState(uint8_t state0, uint8_t state1);
extern uint8_t XsvfGetByte(void);
extern short XsvfGetShort(void);
extern long XsvfGetLong(void);
extern int XsvfReadBitString(void *buf, int num);
extern int XsvfSkipComment(void);

extern void __fastcall__ XsvfDelay(uint16_t msecs);
extern void XsvfLog(uint8_t level, const char* format, ...);

void XsvfPrintBitStrings(uint8_t len,
                         uint8_t* tdi_val, uint8_t* tdo_val,
                         uint8_t* tdo_exp, uint8_t* tdo_msk);
void XsvfShowTapState(uint8_t tapState);

void XsvfLogScroll(void);

/*@}*/


#endif
