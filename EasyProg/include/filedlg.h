
#ifndef FILEDLG_H
#define FILEDLG_H

#include <stdint.h>

void fileDlgSetDriveNumber(uint8_t n);
uint8_t fileDlgGetDriveNumber(void);
uint8_t __fastcall__ fileDlg(char* pStrName, const char* pStrType);

#endif // FILEDLG_H
