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
#include <wx/slider.h>
#include <wx/filepicker.h>

#include "EasySplitApp.h"
#include "EasySplitMainFrame.h"
#include "WorkerThread.h"

#define FILE_SIZE_1_1541    140
#define FILE_SIZE_N_1541    164
#define FILE_SIZE_1_1581    760
#define FILE_SIZE_N_1581    783

DEFINE_EVENT_TYPE(wxEVT_EASY_SPLIT_LOG)

/*****************************************************************************/
EasySplitMainFrame::EasySplitMainFrame(wxFrame* parent, const wxString& title) :
    wxFrame(parent, wxID_ANY, title, wxDefaultPosition, wxSize(800, 600),
            wxDEFAULT_FRAME_STYLE & ~(wxRESIZE_BORDER | wxRESIZE_BOX | wxMAXIMIZE_BOX))
{
    wxStaticText*       pText;
    wxBoxSizer*         pOuterSizer;
    wxFlexGridSizer*    pMainSizer;
    wxBoxSizer*         pButtonSizer;

    pOuterSizer = new wxBoxSizer(wxVERTICAL);
    pOuterSizer->AddSpacer(20);

    pMainSizer = new wxFlexGridSizer(2, 5, 10);
    pOuterSizer->Add(pMainSizer);

    // Input file
    pText = new wxStaticText(this, wxID_ANY, _("Input File"));
    pMainSizer->Add(pText, 0, wxALIGN_CENTER_VERTICAL | wxALIGN_RIGHT);
    m_pInputFilePicker = new wxFilePickerCtrl(this, wxID_ANY, wxEmptyString,
            _("Select a file"), _("*"), wxDefaultPosition, wxDefaultSize,
            wxFLP_USE_TEXTCTRL | wxFLP_OPEN | wxFLP_FILE_MUST_EXIST);
    m_pInputFilePicker->SetMinSize(wxSize(300, m_pInputFilePicker->GetMinSize().GetHeight()));
    pMainSizer->Add(m_pInputFilePicker, wxEXPAND);
    pMainSizer->AddSpacer(10);
    pMainSizer->AddSpacer(10);

    // Buttons for default sizes
    pText = new wxStaticText(this, wxID_ANY, _("Default sizes"));
    pMainSizer->Add(pText, 0, wxALIGN_CENTER_VERTICAL | wxALIGN_RIGHT);
    pButtonSizer = new wxBoxSizer(wxHORIZONTAL);
    pMainSizer->Add(pButtonSizer);
    m_pButtonSize170k = new wxButton(this, wxID_ANY, _("170 KiB (1541)"));
    pButtonSizer->Add(m_pButtonSize170k);
    m_pButtonSize800k = new wxButton(this, wxID_ANY, _("800 KiB (1581)"));
    pButtonSizer->Add(m_pButtonSize800k);

    // Size of first file
    pText = new wxStaticText(this, wxID_ANY, _("First file [KiB]"));
    pMainSizer->Add(pText, 0, wxALIGN_CENTER_VERTICAL | wxALIGN_RIGHT);
    m_pSliderSize1 = new wxSlider(this, wxID_ANY, FILE_SIZE_1_1541, 50, 1024,
            wxDefaultPosition, wxDefaultSize, wxSL_LABELS);
    m_pSliderSize1->SetMinSize(wxSize(300, m_pSliderSize1->GetMinSize().GetHeight()));
    pMainSizer->Add(m_pSliderSize1, wxEXPAND);

    // Size of subsequent files
    pText = new wxStaticText(this, wxID_ANY, _("Subsequent files [KiB]"));
    pMainSizer->Add(pText, 0, wxALIGN_CENTER_VERTICAL | wxALIGN_RIGHT);
    m_pSliderSizeN = new wxSlider(this, wxID_ANY, FILE_SIZE_N_1541, 50, 1024,
            wxDefaultPosition, wxDefaultSize, wxSL_LABELS);
    m_pSliderSizeN->SetMinSize(wxSize(300, m_pSliderSizeN->GetMinSize().GetHeight()));
    pMainSizer->Add(m_pSliderSizeN, wxEXPAND);

    // Output file
    pMainSizer->AddSpacer(10);
    pMainSizer->AddSpacer(10);
    pText = new wxStaticText(this, wxID_ANY, _("Output Files (+.01, .02,...)"));
    pMainSizer->Add(pText, 0, wxALIGN_CENTER_VERTICAL | wxALIGN_RIGHT);
    m_pOutputFilePicker = new wxFilePickerCtrl(this, wxID_ANY, wxEmptyString,
            _("Select a file"), _("*"), wxDefaultPosition, wxDefaultSize,
            wxFLP_USE_TEXTCTRL | wxFLP_SAVE);
    m_pOutputFilePicker->SetMinSize(wxSize(300, m_pInputFilePicker->GetMinSize().GetHeight()));
    pMainSizer->Add(m_pOutputFilePicker, wxEXPAND);

    // Start Button
    pOuterSizer->AddSpacer(10);
    m_pButtonStart = new wxButton(this, wxID_ANY, _("Go!"));
    pOuterSizer->Add(m_pButtonStart, 0, wxALIGN_CENTER_HORIZONTAL);

    // Text Control for Log
    pOuterSizer->AddSpacer(10);
    m_pTextCtrlLog = new wxTextCtrl(this, wxID_ANY, _(""), wxDefaultPosition, wxDefaultSize, wxTE_MULTILINE | wxTE_READONLY);
    m_pTextCtrlLog->SetMinSize(wxSize(500, 100));
    pOuterSizer->Add(m_pTextCtrlLog, 0, wxALIGN_CENTER_VERTICAL | wxALIGN_CENTER_HORIZONTAL);

    SetSizer(pOuterSizer);
    pOuterSizer->SetSizeHints(this);

    Connect(wxEVT_COMMAND_BUTTON_CLICKED, wxCommandEventHandler(EasySplitMainFrame::OnButton));
    Connect(wxEVT_COMMAND_FILEPICKER_CHANGED, wxFileDirPickerEventHandler(EasySplitMainFrame::OnFilePickerChanged));
    Connect(wxEVT_EASY_SPLIT_LOG, wxCommandEventHandler(EasySplitMainFrame::OnLog));
}


/*****************************************************************************/
void EasySplitMainFrame::OnButton(wxCommandEvent& event)
{
    if (event.GetEventObject() == m_pButtonSize170k)
    {
        m_pSliderSize1->SetValue(FILE_SIZE_1_1541);
        m_pSliderSizeN->SetValue(FILE_SIZE_N_1541);
    }
    else if (event.GetEventObject() == m_pButtonSize800k)
    {
        m_pSliderSize1->SetValue(FILE_SIZE_1_1581);
        m_pSliderSizeN->SetValue(FILE_SIZE_N_1581);
    }
    else if (event.GetEventObject() == m_pButtonStart)
    {
        DoIt();
    }
}


/*****************************************************************************/
void EasySplitMainFrame::OnFilePickerChanged(wxFileDirPickerEvent& event)
{
    if (event.GetEventObject() == m_pInputFilePicker)
        m_pOutputFilePicker->SetPath(m_pInputFilePicker->GetPath());
}


/*****************************************************************************/
void EasySplitMainFrame::OnLog(wxCommandEvent& event)
{
    m_pTextCtrlLog->AppendText(event.GetString());
}


/*****************************************************************************/
void EasySplitMainFrame::DoIt()
{
    //Enable(false);

    m_pTextCtrlLog->SetValue(_(""));
    m_pWorkerThread = new WorkerThread(
            this,
            m_pInputFilePicker->GetPath(),
            m_pOutputFilePicker->GetPath(),
            m_pSliderSize1->GetValue() * 1024,
            m_pSliderSizeN->GetValue() * 1024);
    m_pWorkerThread->Create();
    m_pWorkerThread->Run();
}

