

int main(void)
{
    for (;;)
        ++*(unsigned char*)0xd020;
}
