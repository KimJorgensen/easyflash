
#include <stdio.h>
#include <fcntl.h>
#include <conio.h>

#include "cart.h"
#include "screen.h"

static const char* apStrJumperTest[] =
{
        "Make sure the jumpers are set to",
        "\"auto\". Otherwise set them now",
        "and press <Enter>.",
        NULL
};

int main(void)
{
	char strFileName[40];
    int fd;

    screenInit();
    screenPrintFrame();
    screenPrintDialog(apStrJumperTest);
    screenWaitOKKey();

    gotoxy(2, 5);

	printf("Cartridge file name:");
    scanf("%s", strFileName);

    printf("Checking %s...\n", strFileName);

    fd = open(strFileName, O_RDONLY);

    if (fd == -1)
    {
        printf("Cannot open input file\n");
        return 1;
    }

    if (!readCartHeader(fd))
        return 1;

    eraseFlash();

    while (readNextChipHeader(fd));
    printCartInfo();
    return 0;
}
