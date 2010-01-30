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

#ifdef _MSC_VER
#include <winsock2.h>
#endif

#include "xsvf.h"   /* Error codes. */
#include "host.h"   /* Hardware access. */

#include "tapsm.h"

/*!
 * \file tapsm.c
 * \brief TAP controller state handler.
 */

/*!
 * \addtogroup xgTAP
 */
/*@{*/

/*!
 * \brief Current state of the TAP controller.
 */
static uint8_t tapState;

/*!
 * \brief TAP controller initialization.
 *
 * Must be called prior any other routine in this module.
 */
void TapStateInit(void)
{
    uint8_t i;

    tapState = TEST_LOGIC_RESET;

    SET_TMS();
    for (i = 0; i < 5; ++i) {
        CLR_TCK();
        SET_TCK();
    }
    XsvfShowTapState(tapState);
}

/*!
 * \brief State transition with TMS set to high.
 */
static void TmsHighTransition(void)
{
    SET_TMS();
    CLR_TCK();
    SET_TCK();
}

/*!
 * \brief State transition with TMS set to low.
 */
static void TmsLowTransition(void)
{
    CLR_TMS();
    CLR_TCK();
    SET_TCK();
}


/*!
 * \brief Change TAP state.
 *
 * Moves the TAP (Test Access Port) controller of the target to the
 * specified state.
 *
 * Trying to enter Exit2-DR or Exit2-IR from any other state except
 * Pause-DR or Pause-IR resp. will result in an error.
 *
 * \param state Requested TAP controller state.
 *
 * \return Zero on success, otherwise an error code is returned.
 */
uint8_t TapStateChange(uint8_t state)
{
    uint8_t i;
    uint8_t rc = 0;

    /*
     * No state change. However, XSVF expects us to terminate a Pause state.
     */
    if (state == tapState) {
        if (state == PAUSE_DR) {
            TmsHighTransition();
            tapState = EXIT2_DR;
        } else if (state == PAUSE_IR) {
            TmsHighTransition();
            tapState = EXIT2_IR;
        }
    }

    /*
     * Keeping TMS high for 5 or more consecutive state transition will put 
     * the TAP controller in Test-Logic-Reset state.
     */
    else if (state == TEST_LOGIC_RESET) {
        for (i = 0; i < 5; ++i) {
            TmsHighTransition();
        }
        tapState = TEST_LOGIC_RESET;
    }

    /*
     * Check for illegal state transisiton.
     */
    else if ((state == EXIT2_DR && tapState != PAUSE_DR) || (state == EXIT2_IR && tapState != PAUSE_IR) ) {
        rc = XE_ILLEGALSTATE;
    }

    else {
        /*
         * Walk through the state tree until we reach the requested state.
         */
        while (rc == 0 && state != tapState) {
            switch (tapState) {
            case TEST_LOGIC_RESET:
                TmsLowTransition();
                tapState = RUN_TEST_IDLE;
                break;
            case RUN_TEST_IDLE:
                TmsHighTransition();
                tapState = SELECT_DR_SCAN;
                break;
            case SELECT_DR_SCAN:
                if (state >= SELECT_IR_SCAN) {
                    TmsHighTransition();
                    tapState = SELECT_IR_SCAN;
                } else {
                    TmsLowTransition();
                    tapState = CAPTURE_DR;
                }
                break;
            case CAPTURE_DR:
                if (state == SHIFT_DR) {
                    TmsLowTransition();
                    tapState = SHIFT_DR;
                } else {
                    TmsHighTransition();
                    tapState = EXIT1_DR;
                }
                break;
            case SHIFT_DR:
                TmsHighTransition();
                tapState = EXIT1_DR;
                break;
            case EXIT1_DR:
                if (state == PAUSE_DR) {
                    TmsLowTransition();
                    tapState = PAUSE_DR;
                } else {
                    TmsHighTransition();
                    tapState = UPDATE_DR;
                }
                break;
            case PAUSE_DR:
                TmsHighTransition();
                tapState = EXIT2_DR;
                break;
            case EXIT2_DR:
                if (state == SHIFT_DR) {
                    TmsLowTransition();
                    tapState = SHIFT_DR;
                } else {
                    TmsHighTransition();
                    tapState = UPDATE_DR;
                }
                break;
            case UPDATE_DR:
                if (state == RUN_TEST_IDLE) {
                    TmsLowTransition();
                    tapState = RUN_TEST_IDLE;
                } else {
                    TmsHighTransition();
                    tapState = SELECT_DR_SCAN;
                }
                break;
            case SELECT_IR_SCAN:
                TmsLowTransition();
                tapState = CAPTURE_IR;
                break;
            case CAPTURE_IR:
                if (state == SHIFT_IR) {
                    TmsLowTransition();
                    tapState = SHIFT_IR;
                } else {
                    TmsHighTransition();
                    tapState = EXIT1_IR;
                }
                break;
            case SHIFT_IR:
                TmsHighTransition();
                tapState = EXIT1_IR;
                break;
            case EXIT1_IR:
                if (state == PAUSE_IR) {
                    TmsLowTransition();
                    tapState = PAUSE_IR;
                } else {
                    TmsHighTransition();
                    tapState = UPDATE_IR;
                }
                break;
            case PAUSE_IR:
                TmsHighTransition();
                tapState = EXIT2_IR;
                break;
            case EXIT2_IR:
                if (state == SHIFT_IR) {
                    TmsLowTransition();
                    tapState = SHIFT_IR;
                } else {
                    TmsHighTransition();
                    tapState = UPDATE_IR;
                }
                break;
            case UPDATE_IR:
                if (state == RUN_TEST_IDLE) {
                    TmsLowTransition();
                    tapState = RUN_TEST_IDLE;
                } else {
                    TmsHighTransition();
                    tapState = SELECT_DR_SCAN;
                }
                break;
            default:
                rc = XE_ILLEGALSTATE;
                break;
            }
        }
    }
    XsvfShowTapState(tapState);
    return rc;
}

/*!
 * \brief Increment the TAP state.
 *
 * This routine will be used by the caller to update the
 * current TAP state, if the last shift included a state
 * transition.
 */
void TapStateInc(void)
{
    tapState++;
    XsvfShowTapState(tapState);
}

/*@}*/
