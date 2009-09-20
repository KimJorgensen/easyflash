

#ifndef SPRITES_H_
#define SPRITES_H_

// size of memory used by the sprites for the startup screen
#define STARTUP_SPRITES_SIZE (7 * 64)

extern uint8_t* pSprites;
void spritesShow(void);
void spritesOn(void);
void spritesOff(void);

#endif /* SPRITES_H_ */
