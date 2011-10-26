/*
 *
 * (c) 2003-2009 Thomas Giesel
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

#include <wx/wx.h>
#include <wx/file.h>
#include <wx/thread.h>
#include <stdarg.h>
#include <stdlib.h>
#include <stdint.h>

#include "WorkerThread.h"
#include "EasyTransferMainFrame.h"
#include "EasyTransferApp.h"

/*****************************************************************************/

WorkerThread* WorkerThread::m_pTheWorkerThread;

/*****************************************************************************/
WorkerThread::WorkerThread(wxEvtHandler* pEventHandler,
        const wxString& stringInputFileName,
        const wxString& stringOutputFileName, unsigned nSize1, unsigned nSizeN) :
    wxThread(wxTHREAD_JOINABLE), m_pEventHandler(pEventHandler),
            m_stringInputFileName(stringInputFileName), m_stringOutputFileName(
                    stringOutputFileName), m_nSize1(nSize1), m_nSizeN(nSizeN)
{
    m_pTheWorkerThread = this;
}

/*****************************************************************************/
WorkerThread::~WorkerThread()
{
    m_pTheWorkerThread = NULL;
}

/*****************************************************************************/
void WorkerThread::LogText(const wxString& str)
{
    wxCommandEvent event(wxEVT_EASY_SPLIT_LOG);
    event.SetString(str);
    event.SetInt(0);
    m_pEventHandler->AddPendingEvent(event);
}


/*****************************************************************************/
/*
 * Tell the main thread that we're done.
 */
void WorkerThread::LogComplete(void)
{
    wxCommandEvent event(wxEVT_EASY_SPLIT_LOG);

    event.SetInt(1); // done!

    m_pEventHandler->AddPendingEvent(event);
}


/*****************************************************************************/
void* WorkerThread::Entry()
{
    uint16_t      crc;
    size_t        i, size;
    uint8_t*      p;

    WorkerThread_Log("Input:  %s\n",
            (const char*) m_stringInputFileName.mb_str());
    WorkerThread_Log("Output: %s.xx\n",
            (const char*) m_stringOutputFileName.mb_str());

    WorkerThread_Log("\n");
    WorkerThread_Log("\n\\o/\nREADY.\n\n");

    LogComplete();

    return NULL;
}


/*****************************************************************************/
/**
 *
 */
void WorkerThread::Log(const char* pStrFormat, va_list args)
{
    char str[200];
    vsnprintf(str, sizeof(str) - 1, pStrFormat, args);
    str[sizeof(str) - 1] = '\0';

    LogText(wxString(str, wxConvUTF8));
}

/*****************************************************************************/
/**
 *
 */
extern "C" void WorkerThread_Log(const char* pStrFormat, ...)
{
    va_list args;

    if (WorkerThread::m_pTheWorkerThread)
    {
        va_start(args, pStrFormat);
        WorkerThread::m_pTheWorkerThread->Log(pStrFormat, args);
        va_end(args);
    }
}

