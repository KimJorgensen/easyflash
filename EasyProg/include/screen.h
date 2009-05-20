
#ifndef SCREEN_H_
#define SCREEN_H_

void screenInit(void);
void screenPrintFrame(void);
void screenPrintDialog(const char* apStrLines[]);
void screenWaitOKKey(void);

#endif /* SCREEN_H_ */
