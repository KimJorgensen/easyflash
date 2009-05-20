
#include <stdio.h>
#include <fcntl.h>
#include <conio.h>

#include "cart.h"
#include "screen.h"
#include "flashcode.h"

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
    uint8_t i;

    // um zu sehen, ob schreiben in den RAM geht
    *((uint8_t*)0x8000) = 0xfe;

    screenInit();
    screenPrintFrame();
    screenPrintDialog(apStrJumperTest);
    screenWaitOKKey();

    screenInit();
    screenPrintFrame();

    gotoxy(2, 5);

    printf("Lo Chip ID: %04x\n", flashCodeReadIds((void*) 0x8000));
    printf("Hi Chip ID: %04x\n", flashCodeReadIds((void*) 0xe000));

    for (fd = 0; fd < 10000; ++fd);

    flashCodeSectorErase((void*) 0x8000);
    for (i = 0; i < 18; ++i)
        printf("0x8000: %02x\n", *((uint8_t*)0x8000));

    for (;;);

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
