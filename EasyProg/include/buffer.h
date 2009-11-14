/*
 * EasyProg - buffer.h - Workaround for heap problems
 *
 * (c) 2009 Thomas Giesel
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

#ifndef BUFFER_H_
#define BUFFER_H_

/* Buffer for exomizer (4k), see utilasm.s: buffer_start_hi */
#define BUFFER_EXOMIZER_ADDR ((void*) 0x6800)
#define BUFFER_EXOMIZER_SIZE ((void*) 0x1000)

/* Buffer for Flash write memory block */
#define BUFFER_WRITE_ADDR ((void*) 0x7800)
#define BUFFER_WRITE_SIZE ((void*) 0x0100)

/* Backup of ZP addresses, used in utilasm: get_crunched_byte */
#define BUFFER_ZP_BACKUP_ADDR ((void*) 0x7900)
#define BUFFER_ZP_BACKUP_SIZE ((void*) 0x1a)

/* Buffer for directory (below ROM) */
#define BUFFER_DIR_ADDR ((void*) 0x8000)
#define BUFFER_DIR_SIZE ((void*) 0x4000)

void bufferHideROM(void);
void bufferShowROM(void);

#endif /* BUFFER_H_ */
