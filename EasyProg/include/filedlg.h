
#ifndef FILEDLG_H
#define FILEDLG_H

#include <stdint.h>

void fileDlgSetDriveNumber(uint8_t n);
uint8_t fileDlgGetDriveNumber(void);
uint8_t fileDlg(char* pStrName);

#endif // FILEDLG_H
