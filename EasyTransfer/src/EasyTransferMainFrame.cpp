/*
 *
 * (c) 2003-2008 Thomas Giesel
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
#include <wx/button.h>
#include <wx/slider.h>
#include <wx/filepicker.h>
#include <wx/radiobox.h>
#include <wx/radiobut.h>
#include <wx/gauge.h>

#include "EasyTransferApp.h"
#include "EasyTransferMainFrame.h"
#include "WorkerThread.h"


typedef enum easytransfer_action_e
{
        ACTION_WRITE_CRT,
        ACTION_START_PRG_EF,
        ACTION_START_PRG_KILL,
        ACTION_WRITE_D64,
        ACTION_COUNT // <= number of actions
} easytransfer_action_t;

static const wxString aStrActions[] =
{
    _("Write CRT to cartridge"),
    _("Start program (enable EasyFlash)"),
    _("Start program (disable cartridge)"),
    _("Write disk image to disk"),
};


DEFINE_EVENT_TYPE(wxEVT_EASY_TRANSFER_LOG)
DEFINE_EVENT_TYPE(wxEVT_EASY_TRANSFER_PROGRESS)
DEFINE_EVENT_TYPE(wxEVT_EASY_TRANSFER_COMPLETE)

/*****************************************************************************/
/*
 * -pOuterSizer---------------------------------------------------
 * |                                                             |
 * | -pMainSizer------------------------------------------------ |
 * | |                            |                            | |
 * | --------------------------------------------------------- | |
 * | |                            |                            | |
 * | ----------------------------------------------------------- |
 * | |                            |                            | |
 * | ----------------------------------------------------------- |
 * | |                            |                            | |
 * | ----------------------------------------------------------- |
 * | |                            |                            | |
 * | ----------------------------------------------------------- |
 * |                                                             |
 * | -pButtonSizer---------------------------------------------- |
 * | | m_pButtonQuit              | m_pButtonStart             | |
 * | ----------------------------------------------------------- |
 * |                                                             |
 * |                        m_pTextCtrlLog                       |
 * ---------------------------------------------------------------
 */
EasyTransferMainFrame::EasyTransferMainFrame(wxFrame* parent, const wxString& title) :
    wxFrame(parent, wxID_ANY, title, wxDefaultPosition, wxSize(800, 700),
            wxDEFAULT_FRAME_STYLE),
    m_pWorkerThread(NULL)
{
    wxStaticText*       pText;
    wxBoxSizer*         pOuterSizer;
    wxFlexGridSizer*    pMainSizer;
    wxBoxSizer*         pButtonSizer;
    wxRadioBox*         pBoxAction;

    wxPanel *pPanel = new wxPanel(this, wxID_ANY, wxDefaultPosition,
            wxDefaultSize, wxTAB_TRAVERSAL);

    pOuterSizer = new wxBoxSizer(wxVERTICAL);

    pMainSizer = new wxFlexGridSizer(5, 2, 8, 8);
    pMainSizer->AddGrowableCol(1);
    pOuterSizer->Add(pMainSizer, 0, wxEXPAND | wxALL, 20);

    // Input file
    pText = new wxStaticText(pPanel, wxID_ANY, _("Input File"));
    pMainSizer->Add(pText, 0, wxALIGN_CENTER_VERTICAL | wxALIGN_RIGHT);
    m_pInputFilePicker = new wxFilePickerCtrl(pPanel, wxID_ANY, wxEmptyString,
            _("Select a file"), _("*"), wxDefaultPosition, wxDefaultSize,
            wxFLP_USE_TEXTCTRL | wxFLP_OPEN | wxFLP_FILE_MUST_EXIST);
    m_pInputFilePicker->SetMinSize(wxSize(300, m_pInputFilePicker->GetMinSize().GetHeight()));
    pMainSizer->Add(m_pInputFilePicker, 1, wxEXPAND);

    // Action Radio Box
    pText = new wxStaticText(pPanel, wxID_ANY, _("Action"));
    pMainSizer->Add(pText, 0, wxALIGN_CENTER_VERTICAL | wxALIGN_RIGHT);
    pBoxAction = new wxRadioBox(pPanel, wxID_ANY, _("Action"),
            wxDefaultPosition, wxDefaultSize,
            ACTION_COUNT, aStrActions, 1);
    pMainSizer->Add(pBoxAction, 1, wxEXPAND);
    pBoxAction->Enable(ACTION_START_PRG_EF, false);
    pBoxAction->Enable(ACTION_START_PRG_KILL, false);
    pBoxAction->Enable(ACTION_WRITE_D64, false);

    // Progress
    pText = new wxStaticText(pPanel, wxID_ANY, _("Progress"));
    pMainSizer->Add(pText, 0, wxALIGN_CENTER_VERTICAL | wxALIGN_RIGHT);
    m_pProgress = new wxGauge(pPanel, wxID_ANY, 100);
    pMainSizer->Add(m_pProgress, 1, wxEXPAND);

    pMainSizer->AddSpacer(10);
    pMainSizer->AddSpacer(10);

    // Start Button etc.
    pButtonSizer = new wxBoxSizer(wxHORIZONTAL);
    pOuterSizer->Add(pButtonSizer, 0, wxALIGN_CENTER_HORIZONTAL);
    m_pButtonQuit = new wxButton(pPanel, wxID_ANY, _("Quit"));
    pButtonSizer->Add(m_pButtonQuit, 0, wxALIGN_CENTER_HORIZONTAL);
    pButtonSizer->AddSpacer(20);
    m_pButtonStart = new wxButton(pPanel, wxID_ANY, _("Go!"));
    pButtonSizer->Add(m_pButtonStart, 0, wxALIGN_CENTER_HORIZONTAL);

    // Text Control for Log
    pOuterSizer->AddSpacer(10);
    m_pTextCtrlLog = new wxTextCtrl(pPanel, wxID_ANY, _(""), wxDefaultPosition, wxDefaultSize, wxTE_MULTILINE | wxTE_READONLY);
    m_pTextCtrlLog->SetMinSize(wxSize(500, 200));
    //m_pTextCtrlLog->
    pOuterSizer->Add(m_pTextCtrlLog, 1, wxEXPAND | wxALL);

    pPanel->SetSizer(pOuterSizer);
    pOuterSizer->SetSizeHints(this);

    Connect(wxEVT_COMMAND_BUTTON_CLICKED, wxCommandEventHandler(EasyTransferMainFrame::OnButton));
    Connect(wxEVT_COMMAND_FILEPICKER_CHANGED, wxFileDirPickerEventHandler(EasyTransferMainFrame::OnFilePickerChanged));

    Connect(wxEVT_EASY_TRANSFER_LOG,      wxCommandEventHandler(EasyTransferMainFrame::OnLog));
    Connect(wxEVT_EASY_TRANSFER_PROGRESS, wxCommandEventHandler(EasyTransferMainFrame::OnProgress));
    Connect(wxEVT_EASY_TRANSFER_COMPLETE, wxCommandEventHandler(EasyTransferMainFrame::OnComplete));
}


/*****************************************************************************/
void EasyTransferMainFrame::OnButton(wxCommandEvent& event)
{
    if (event.GetEventObject() == m_pButtonStart)
    {
        if (m_pInputFilePicker->GetPath().size())
            DoIt();
    }
    else if (event.GetEventObject() == m_pButtonQuit)
    {
        if (m_pWorkerThread)
        {
            m_pWorkerThread->Kill();
            delete m_pWorkerThread;
            m_pWorkerThread = NULL;
        }
        Close();
    }
}


/*****************************************************************************/
void EasyTransferMainFrame::OnFilePickerChanged(wxFileDirPickerEvent& event)
{
}


/*****************************************************************************/
void EasyTransferMainFrame::OnLog(wxCommandEvent& event)
{
    m_pTextCtrlLog->AppendText(event.GetString());
}


/*****************************************************************************/
void EasyTransferMainFrame::OnProgress(wxCommandEvent& event)
{
    int i = event.GetInt();

    if (i >= 0 && i <= 100)
    {
        m_pProgress->SetValue(i);
    }
}


/*****************************************************************************/
void EasyTransferMainFrame::OnComplete(wxCommandEvent& event)
{
    if (m_pWorkerThread)
    {
        m_pWorkerThread->Wait();
        delete m_pWorkerThread;
        m_pWorkerThread = NULL;
    }
}


/*****************************************************************************/
void EasyTransferMainFrame::EnableMyControls(bool bEnable)
{
    m_pInputFilePicker->Enable(bEnable);
    m_pButtonStart->Enable(bEnable);
}


/*****************************************************************************/
void EasyTransferMainFrame::DoIt()
{
    if (m_pWorkerThread && m_pWorkerThread->IsRunning())
    {
        return;
    }
    else
    {
        EnableMyControls(false);

        m_pTextCtrlLog->SetValue(_(""));
        m_pWorkerThread = new WorkerThread(
                this,
                m_pInputFilePicker->GetPath());
        m_pWorkerThread->Create();
        m_pWorkerThread->Run();
    }
}

