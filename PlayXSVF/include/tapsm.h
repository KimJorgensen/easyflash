#ifndef _TAPSM_H_
#define _TAPSM_H_

/*
 * Copyright (C) 2010 by Thomas 'skoe' Giesel
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

#include <stdint.h>

/*!
 * \file tapsm.h
 * \brief TAP state header file.
 */

/*!
 * \addtogroup xgTAP
 */
/*@{*/

/*! TAP state. */
#define TEST_LOGIC_RESET    0x00
/*! TAP state. */
#define RUN_TEST_IDLE       0x01
/*! TAP state. */
#define SELECT_DR_SCAN      0x02
/*! TAP state. */
#define CAPTURE_DR          0x03
/*! TAP state. */
#define SHIFT_DR            0x04
/*! TAP state. */
#define EXIT1_DR            0x05
/*! TAP state. */
#define PAUSE_DR            0x06
/*! TAP state. */
#define EXIT2_DR            0x07
/*! TAP state. */
#define UPDATE_DR           0x08
/*! TAP state. */
#define SELECT_IR_SCAN      0x09
/*! TAP state. */
#define CAPTURE_IR          0x0A
/*! TAP state. */
#define SHIFT_IR            0x0B
/*! TAP state. */
#define EXIT1_IR            0x0C
/*! TAP state. */
#define PAUSE_IR            0x0D
/*! TAP state. */
#define EXIT2_IR            0x0E
/*! TAP state. */
#define UPDATE_IR           0x0F
/*! Unknown TAP state, indicates an error. */
#define UNKNOWN_STATE       0x10


extern void TapStateInit(void);
extern uint8_t TapStateChange(uint8_t state);
extern void TapStateInc(void);

/*@}*/

#endif
