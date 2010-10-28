; Matt Gray's Driller


	.export music_init
	.export music_play


	.segment "MUSICZP": zeropage

track_ptr:	.res 2
pattern_ptr:	.res 2


	.segment "MUSIC"


music_init:
	lda #1
	sta tune_ctrl
	rts

music_play:
	ldx	#0
	jsr	play_voice
	ldx	#7
	jsr	play_voice
	ldx	#14


play_voice:
	lda	tune_ctrl			; 0900
	bne	is_playing			; 0903
	sta	$D418				; 0905
	rts					; 0908

is_playing:
	cmp	#$AB				; 0909  +
	beq	continue_playing		; 090B
	jmp	change_tune			; 090D

reset_voices:
	lda	#$00				; 0910  .
	sta	$D404				; 0912
	sta	$D40B				; 0915
	sta	$D412				; 0918
	lda	#$0F				; 091B  O
	sta	$D418				; 091D
	ldy	#$00				; 0920  .
	sty	voice1_track_index		; 0922
	sty	voice2_track_index		; 0925
	sty	voice3_track_index		; 0928
	sty	voice1_ctrl2			; 092B
	sty	voice2_ctrl2			; 092E
	sty	voice3_ctrl2			; 0931
	sty	voice1_pattern_index		; 0934
	sty	voice2_pattern_index		; 0937
	sty	voice3_pattern_index		; 093A
	iny					; 093D
	sty	tempo_ctr			; 093E
	jmp	voice_done			; 0941

continue_playing:
	ldy	voice1_instrument_index,x	; 0944
	lda	possibly_instrument_a0+7,y	; 0947
	and	#$04				; 094A  D
	beq	L0964				; 094C
	lda	voice1_two_ctr,x		; 094E
	beq	L095E				; 0951
	dec	voice1_two_ctr,x		; 0953
	lda	possibly_instrument_a1+2,y	; 0956
	sta	$D404,x				; 0959
	bne	L0964				; 095C
L095E:
	lda	possibly_instrument_a0+1,y	; 095E
	sta	$D404,x				; 0961
L0964:
	lda	tempo_ctr			; 0964
	bne	L096E				; 0967
	dec	voice1_ctrl2,x			; 0969
	bmi	L09B6				; 096C
L096E:
	jmp	L0B33				; 096E

change_tune:
	ldy	tune_ctrl			; 0971
	lda	voice1_tune_trackptr_lo,y	; 0974
	sta	voice1_trackptr			; 0977
	lda	voice1_tune_trackptr_hi,y	; 097A
	sta	voice1_trackptr+1		; 097D
	lda	voice2_tune_trackptr_lo,y	; 0980
	sta	voice2_trackptr			; 0983
	lda	voice2_tune_trackptr_hi,y	; 0986
	sta	voice2_trackptr+1		; 0989
	lda	voice3_tune_trackptr_lo,y	; 098C
	sta	voice3_trackptr			; 098F
	lda	voice3_tune_trackptr_hi,y	; 0992
	sta	voice3_trackptr+1		; 0995
	lda	tune_tempo,y			; 0998
	sta	tempo				; 099B
	jmp	reset_voices			; 099E

voice_done:
	cpx	#$0E				; 09A1  N
	bne	@done				; 09A3
	dec	tempo_ctr			; 09A5
	bpl	@done				; 09A8
	lda	tempo				; 09AA
	sta	tempo_ctr			; 09AD
@done:
	lda	#$AB				; 09B0  +
	sta	tune_ctrl			; 09B2
	rts					; 09B5

L09B6:
	lda	voice1_trackptr,x		; 09B6
	sta	track_ptr			; 09B9
	lda	voice1_trackptr+1,x		; 09BB
	sta	track_ptr+1			; 09BE
	ldy	voice1_track_index,x		; 09C0
	lda	(track_ptr),y			; 09C3
	tay					; 09C5
	lda	pattern_lobytes,y		; 09C6
	sta	pattern_ptr			; 09C9
	lda	pattern_hibytes,y		; 09CB
	sta	pattern_ptr+1			; 09CE
	lda	#$FF				; 09D0  .
	sta	control3			; 09D2
	lda	#$00				; 09D5  .
	sta	voice1_whatever+2,x		; 09D7
	sta	voice1_whatever+1,x		; 09DA
	sta	voice1_whatever,x		; 09DD
read_note_or_ctrl:
	ldy	voice1_pattern_index,x		; 09E0
	lda	(pattern_ptr),y			; 09E3
	cmp	#$FD				; 09E5  }
	bcc	check_effect_fb_or_fc		; 09E7
	iny					; 09E9
	inc	voice1_pattern_index,x		; 09EA
	lda	(pattern_ptr),y			; 09ED
	sta	voice1_something+2,x		; 09EF
next_note_or_ctrl:
	inc	voice1_pattern_index,x		; 09F2
	bne	read_note_or_ctrl		; 09F5
check_effect_fb_or_fc:
	cmp	#$FB				; 09F7  {
	bcc	@check_effect_fa		; 09F9
	cmp	#$FB				; 09FB  {
	bne	@effect_fc_2			; 09FD
@effect_fb_1:
	lda	#$01				; 09FF  A
@do_effect_fb_or_fc:
	sta	voice1_whatever+2,x		; 0A01
	iny					; 0A04
	inc	voice1_pattern_index,x		; 0A05
	lda	(pattern_ptr),y			; 0A08
	sta	voice1_something,x		; 0A0A
	lda	#$00				; 0A0D  .
	sta	voice1_whatever+1,x		; 0A0F
	sta	voice1_whatever,x		; 0A12
	beq	next_note_or_ctrl		; 0A15
@effect_fc_2:
	lda	#$02				; 0A17  B
	bne	@do_effect_fb_or_fc		; 0A19
@check_effect_fa:
	cmp	#$FA				; 0A1B  z
	bcc	@plain_note			; 0A1D
	iny					; 0A1F
	inc	voice1_pattern_index,x		; 0A20
	lda	(pattern_ptr),y			; 0A23
	asl	a				; 0A25
	asl	a				; 0A26
	asl	a				; 0A27
	sta	voice1_instrument_index,x	; 0A28
	tay					; 0A2B
	lda	possibly_instrument_a0,y	; 0A2C
	pha					; 0A2F
	and	#$0F				; 0A30  O
	sta	voice1_something_else+2,x	; 0A32
	sta	voice1_ctrl0,x			; 0A35
	pla					; 0A38
	and	#$F0				; 0A39  p
	sta	voice1_something_else,x		; 0A3B
	sta	voice1_something_else+1,x	; 0A3E
	jmp	next_note_or_ctrl		; 0A41

@plain_note:
	sta	voice1_stuff+3,x		; 0A44
	lda	voice1_something+2,x		; 0A47
	sta	voice1_ctrl2,x			; 0A4A
	lda	#$00				; 0A4D  .
	sta	voice1_whatever+3,x		; 0A4F
	sta	voice1_whatever+4,x		; 0A52
	lda	#$02				; 0A55  B
	sta	voice1_two_ctr,x		; 0A57
	ldy	voice1_instrument_index,x	; 0A5A
	lda	possibly_instrument_a0+7,y	; 0A5D
	and	#$02				; 0A60  B
	beq	L0A70				; 0A62
	lda	voice1_something_else+1,x	; 0A64
	sta	voice1_something_else,x		; 0A67
	lda	voice1_ctrl0,x			; 0A6A
	sta	voice1_something_else+2,x	; 0A6D
L0A70:
	lda	voice1_stuff+3,x		; 0A70
	bne	L0A88				; 0A73
	lda	voice1_things+6,x		; 0A75
	sta	voice1_stuff+3,x		; 0A78
	lda	#$00				; 0A7B  .
	sta	voice1_things+6,x		; 0A7D
	ldy	voice1_instrument_index,x	; 0A80
	dec	control3			; 0A83
	bne	L0AAD				; 0A86
L0A88:
	sta	voice1_things+6,x		; 0A88
	tay					; 0A8B
	lda	frq_hi,y			; 0A8C
	sta	$D401,x				; 0A8F
	sta	voice1_stuff+2,x		; 0A92
	sta	voice1_stuff+4,x		; 0A95
	lda	frq_lo,y			; 0A98
	sta	$D400,x				; 0A9B
	sta	voice1_stuff+1,x		; 0A9E
	sta	voice1_stuff,x			; 0AA1
	ldy	voice1_instrument_index,x	; 0AA4
	lda	possibly_instrument_a0+6,y	; 0AA7
	sta	$D404,x				; 0AAA
L0AAD:
	lda	possibly_instrument_a0+1,y	; 0AAD
	and	control3			; 0AB0
	sta	$D404,x				; 0AB3
	lda	possibly_instrument_a0+2,y	; 0AB6
	sta	$D405,x				; 0AB9
	lda	possibly_instrument_a0+3,y	; 0ABC
	sta	$D406,x				; 0ABF
	lda	voice1_something_else,x		; 0AC2
	sta	$D402,x				; 0AC5
	lda	voice1_something_else+2,x	; 0AC8
	sta	$D403,x				; 0ACB
	inc	voice1_pattern_index,x		; 0ACE
	ldy	voice1_pattern_index,x		; 0AD1
	lda	(pattern_ptr),y			; 0AD4
	cmp	#$FF				; 0AD6  .
	bne	L0AFC				; 0AD8
	lda	#$00				; 0ADA  .
	sta	voice1_pattern_index,x		; 0ADC
	inc	voice1_track_index,x		; 0ADF
	ldy	voice1_track_index,x		; 0AE2
	lda	(track_ptr),y			; 0AE5
	cmp	#$FF				; 0AE7  .
	bne	L0AF2				; 0AE9
	lda	#$00				; 0AEB  .
	sta	voice1_track_index,x		; 0AED
	beq	L0AFC				; 0AF0
L0AF2:
	cmp	#$FE				; 0AF2  ~
	bne	L0AFC				; 0AF4
	lda	#$00				; 0AF6  .
	sta	tune_ctrl			; 0AF8
	rts					; 0AFB

L0AFC:
	lda	voice1_things+6,x		; 0AFC
	beq	L0B33				; 0AFF
	ldy	voice1_instrument_index,x	; 0B01
	lda	voice1_whatever+2,x		; 0B04
	bne	L0B17				; 0B07
	lda	possibly_instrument_a1+4,y	; 0B09
	beq	L0B1A				; 0B0C
	sta	voice1_whatever+2,x		; 0B0E
	lda	possibly_instrument_a1+3,y	; 0B11
	sta	voice1_something,x		; 0B14
L0B17:
	jmp	L0C5A				; 0B17

L0B1A:
	lda	possibly_instrument_a0+5,y	; 0B1A
	beq	L0B22				; 0B1D
	jmp	L0E67				; 0B1F

L0B22:
	sta	voice1_whatever+1,x		; 0B22
	lda	possibly_instrument_a1,y	; 0B25
	beq	L0B2D				; 0B28
	jmp	L0E89				; 0B2A

L0B2D:
	sta	voice1_whatever,x		; 0B2D
	jmp	voice_done			; 0B30

L0B33:
	lda	possibly_instrument_a0+4,y	; 0B33
	sta	control1			; 0B36
	beq	L0B82				; 0B39
	lda	voice1_whatever2,x		; 0B3B
	bne	L0B62				; 0B3E
	clc					; 0B40
	lda	voice1_something_else,x		; 0B41
	adc	control1			; 0B44
	sta	voice1_something_else,x		; 0B47
	sta	$D402,x				; 0B4A
	lda	voice1_something_else+2,x	; 0B4D
	adc	#$00				; 0B50  .
	sta	voice1_something_else+2,x	; 0B52
	sta	$D403,x				; 0B55
	clc					; 0B58
	cmp	#$0E				; 0B59  N
	bcc	L0B82				; 0B5B
	inc	voice1_whatever2,x		; 0B5D
	bne	L0B82				; 0B60
L0B62:
	lda	voice1_something_else,x		; 0B62
	sec					; 0B65
	sbc	control1			; 0B66
	sta	voice1_something_else,x		; 0B69
	sta	$D402,x				; 0B6C
	lda	voice1_something_else+2,x	; 0B6F
	sbc	#$00				; 0B72  .
	sta	voice1_something_else+2,x	; 0B74
	sta	$D403,x				; 0B77
	clc					; 0B7A
	cmp	#$08				; 0B7B  H
	bcs	L0B82				; 0B7D
	dec	voice1_whatever2,x		; 0B7F
L0B82:
	lda	voice1_whatever+1,x		; 0B82
	beq	L0BC0				; 0B85
	lda	voice1_ctrl1,x			; 0B87
	asl	a				; 0B8A
	tay					; 0B8B
	lda	arpeggio_table,y		; 0B8C
	sta	arp_ptr				; 0B8F
	lda	arpeggio_table+1,y		; 0B92
	sta	arp_ptr+1			; 0B95
	lda	voice1_stuff+6,x		; 0B98
	cmp	voice1_stuff+5,x		; 0B9B
	bne	L0BA5				; 0B9E
	lda	#$00				; 0BA0  .
	sta	voice1_stuff+6,x		; 0BA2
L0BA5:
	tay					; 0BA5
	lda	voice1_stuff+3,x		; 0BA6
	clc					; 0BA9
arp_ptr		:= * + 1
	adc	arpeggio_0,y			; 0BAA
	tay					; 0BAD
	lda	frq_lo,y			; 0BAE
	sta	$D400,x				; 0BB1
	lda	frq_hi,y			; 0BB4
	sta	$D401,x				; 0BB7
	inc	voice1_stuff+6,x		; 0BBA
	jmp	voice_done			; 0BBD

L0BC0:
	lda	voice1_whatever,x		; 0BC0
	bne	L0BC8				; 0BC3
	jmp	L0C5A				; 0BC5

L0BC8:
	lda	voice1_things,x			; 0BC8
	beq	L0C06				; 0BCB
	cmp	#$03				; 0BCD  C
	bcc	L0C2F				; 0BCF
	sec					; 0BD1
	lda	voice1_stuff,x			; 0BD2
	sbc	voice1_things+1,x		; 0BD5
	sta	voice1_stuff,x			; 0BD8
	sta	$D400,x				; 0BDB
	lda	voice1_stuff+4,x		; 0BDE
	sbc	#$00				; 0BE1  .
	sta	voice1_stuff+4,x		; 0BE3
	sta	$D401,x				; 0BE6
	dec	voice1_things+3,x		; 0BE9
	bne	L0C03				; 0BEC
	lda	voice1_things+2,x		; 0BEE
	sta	voice1_things+3,x		; 0BF1
	inc	voice1_things,x			; 0BF4
	lda	voice1_things,x			; 0BF7
	cmp	#$05				; 0BFA  E
	bcc	L0C03				; 0BFC
	lda	#$01				; 0BFE  A
	sta	voice1_things,x			; 0C00
L0C03:
	jmp	voice_done			; 0C03

L0C06:
	sec					; 0C06
	lda	voice1_stuff,x			; 0C07
	sbc	voice1_things+1,x		; 0C0A
	sta	voice1_stuff,x			; 0C0D
	sta	$D400,x				; 0C10
	lda	voice1_stuff+4,x		; 0C13
	sbc	#$00				; 0C16  .
	sta	voice1_stuff+4,x		; 0C18
	sta	$D401,x				; 0C1B
	dec	voice1_things+3,x		; 0C1E
	bne	L0C2C				; 0C21
	lda	voice1_things+2,x		; 0C23
	sta	voice1_things+3,x		; 0C26
	inc	voice1_things,x			; 0C29
L0C2C:
	jmp	voice_done			; 0C2C

L0C2F:
	clc					; 0C2F
	lda	voice1_stuff,x			; 0C30
	adc	voice1_things+1,x		; 0C33
	sta	voice1_stuff,x			; 0C36
	sta	$D400,x				; 0C39
	lda	voice1_stuff+4,x		; 0C3C
	adc	#$00				; 0C3F  .
	sta	voice1_stuff+4,x		; 0C41
	sta	$D401,x				; 0C44
	dec	voice1_things+3,x		; 0C47
	bne	L0CCB				; 0C4A
	lda	voice1_things+2,x		; 0C4C
	sta	voice1_things+3,x		; 0C4F
	inc	voice1_things,x			; 0C52
	bne	L0CCB				; 0C55
	jmp	voice_done			; 0C57

L0C5A:
	lda	voice1_whatever+2,x		; 0C5A
	beq	L0CBE				; 0C5D
	cmp	#$01				; 0C5F  A
	beq	L0C7B				; 0C61
	cmp	#$02				; 0C63  B
	beq	L0CA6				; 0C65
	cmp	#$03				; 0C67  C
	beq	L0C96				; 0C69
	clc					; 0C6B
	lda	voice1_stuff+4,x		; 0C6C
	adc	voice1_something,x		; 0C6F
	sta	voice1_stuff+4,x		; 0C72
	sta	$D401,x				; 0C75
	jmp	L0CBE				; 0C78

L0C7B:
	clc					; 0C7B
	lda	voice1_stuff,x			; 0C7C
	sbc	voice1_something,x		; 0C7F
	sta	voice1_stuff,x			; 0C82
	sta	$D400,x				; 0C85
	lda	voice1_stuff+4,x		; 0C88
	sbc	#$00				; 0C8B  .
	sta	voice1_stuff+4,x		; 0C8D
	sta	$D401,x				; 0C90
	jmp	L0CBE				; 0C93

L0C96:
	sec					; 0C96
	lda	voice1_stuff+4,x		; 0C97
	sbc	voice1_something,x		; 0C9A
	sta	voice1_stuff+4,x		; 0C9D
	sta	$D401,x				; 0CA0
	jmp	L0CBE				; 0CA3

L0CA6:
	clc					; 0CA6
	lda	voice1_stuff,x			; 0CA7
	adc	voice1_something,x		; 0CAA
	sta	voice1_stuff,x			; 0CAD
	sta	$D400,x				; 0CB0
	lda	voice1_stuff+4,x		; 0CB3
	adc	#$00				; 0CB6  .
	sta	voice1_stuff+4,x		; 0CB8
	sta	$D401,x				; 0CBB
L0CBE:
	ldy	voice1_instrument_index,x	; 0CBE
	lda	possibly_instrument_a0+7,y	; 0CC1
	and	#$01				; 0CC4  A
	beq	L0CCB				; 0CC6
	jmp	L1005				; 0CC8

L0CCB:
	jmp	voice_done			; 0CCB

voice1_whatever:
	.byte	$00,$00,$00,$00,$00		; 0CCE  .....
voice1_pattern_index:
	.byte	$06				; 0CD3  F
voice1_whatever2:
	.byte	$00				; 0CD4  .
voice2_whatever:
	.byte	$00,$00,$00,$00,$00		; 0CD5  .....
voice2_pattern_index:
	.byte	$06				; 0CDA  F
voice2_whatever2:
	.byte	$00				; 0CDB  .
voice3_whatever:
	.byte	$00,$00,$00,$00,$00		; 0CDC  .....
voice3_pattern_index:
	.byte	$00				; 0CE1  .
voice3_whatever2:
	.byte	$01				; 0CE2  A
voice1_something:
	.byte	$00,$00,$3F			; 0CE3  ..?
voice1_instrument_index:
	.byte	$08				; 0CE6  H
voice1_something_else:
	.byte	$BB,$90,$02			; 0CE7  ;PB
@voice2_something:
	.byte	$00,$00,$3F			; 0CEA  ..?
@voice2_instrument_index:
	.byte	$08				; 0CED  H
@voice2_something_else:
	.byte	$BB,$90,$02			; 0CEE  ;PB
@voice3_something:
	.byte	$00,$00,$3F			; 0CF1  ..?
@voice3_instrument_index:
	.byte	$20				; 0CF4   
@voice3_something_else:
	.byte	$F0,$90,$0C			; 0CF5  pPL
voice1_ctrl0:
	.byte	$00				; 0CF8  .
voice1_ctrl1:
	.byte	$00				; 0CF9  .

voice1_trackptr:
	.addr	voice1_track			; 0CFA

voice1_track_index:
	.byte	$00,$00				; 0CFC  ..
voice1_ctrl2:
	.byte	$3C				; 0CFE  <
voice2_ctrl0:
	.byte	$00				; 0CFF  .
voice2_ctrl1:
	.byte	$00				; 0D00  .

voice2_trackptr:
	.addr	voice2_track			; 0D01

voice2_track_index:
	.byte	$00,$00				; 0D03  ..
voice2_ctrl2:
	.byte	$3C				; 0D05  <
voice3_ctrl0:
	.byte	$06				; 0D06  F
voice3_ctrl1:
	.byte	$00				; 0D07  .

voice3_trackptr:
	.addr	voice3_track			; 0D08

voice3_track_index:
	.byte	$02,$00				; 0D0A  B.
voice3_ctrl2:
	.byte	$3C,$00,$00			; 0D0C  <..
tune_ctrl:
	.byte	$AB				; 0D0F  +
tempo:
	.byte	$03				; 0D10  C
control1:
	.byte	$A0				; 0D11   
tempo_ctr:
	.byte	$00				; 0D12  .
control3:
	.byte	$FE				; 0D13  ~
voice1_stuff:
	.byte	$47,$47,$06,$1F,$06,$00,$00	; 0D14  GGF_F..
@voice2_stuff:
	.byte	$23,$23,$03,$13,$03,$00,$00	; 0D1B  ##CSC..
@voice3_stuff:
	.byte	$00,$00,$00,$00,$00,$00,$00	; 0D22  .......
voice1_things:
	.byte	$00,$00,$00,$00,$00,$00,$1F	; 0D29  ......_
@voice2_things:
	.byte	$00,$00,$00,$00,$00,$00,$13	; 0D30  ......S
@voice3_things:
	.byte	$00,$00,$00,$00,$00,$00,$00	; 0D37  .......
voice1_two_ctr:
	.byte	$02,$00,$00,$00,$00,$00,$00	; 0D3E  B......
@voice2_two_ctr:
	.byte	$02,$00,$00,$00,$00,$00,$00	; 0D45  B......
@voice3_two_ctr:
	.byte	$02,$00,$00,$00,$00,$00,$00	; 0D4C  B......
frq_lo:
	.byte	$0C,$1C,$2D,$3E,$51,$66,$7B,$91	; 0D53  L\->Qf{Q
	.byte	$A9,$C3,$DD,$FA,$18,$38,$5A,$7D	; 0D5B  )C]zX8Z}
	.byte	$A3,$CC,$F6,$23,$53,$86,$BB,$F4	; 0D63  #Lv#SF;t
	.byte	$30,$70,$B4,$FB,$47,$98,$ED,$47	; 0D6B  0p4{GXmG
	.byte	$A7,$0C,$77,$E9,$61,$E1,$68,$F7	; 0D73  'Lwiaahw
	.byte	$8F,$30,$DA,$8F,$4E,$18,$EF,$D2	; 0D7B  O0ZONXoR
	.byte	$C3,$C3,$D1,$EF,$1F,$60,$B5,$1E	; 0D83  CCQo_`5^
	.byte	$9C,$31,$DF,$A5,$87,$86,$A2,$DF	; 0D8B  \1_%GF\"_
	.byte	$3E,$C1,$6B,$3C,$39,$63,$BE,$4B	; 0D93  >Ak<9c>K
	.byte	$0F,$0C,$45,$BF,$7D,$83,$D6,$79	; 0D9B  OLE?}CVy
	.byte	$73,$C7,$7C,$97,$1E,$18,$8B,$7E	; 0DA3  sG|W^XK~
	.byte	$FA,$06,$AC,$F3,$E6,$8F,$F8,$2E	; 0DAB  zF,sfOx.
frq_hi:
	.byte	$01,$01,$01,$01,$01,$01,$01,$01	; 0DB3  AAAAAAAA
	.byte	$01,$01,$01,$01,$02,$02,$02,$02	; 0DBB  AAAABBBB
	.byte	$02,$02,$02,$03,$03,$03,$03,$03	; 0DC3  BBBCCCCC
	.byte	$04,$04,$04,$04,$05,$05,$05,$06	; 0DCB  DDDDEEEF
	.byte	$06,$07,$07,$07,$08,$08,$09,$09	; 0DD3  FGGGHHII
	.byte	$0A,$0B,$0B,$0C,$0D,$0E,$0E,$0F	; 0DDB  JKKLMNNO
	.byte	$10,$11,$12,$13,$15,$16,$17,$19	; 0DE3  PQRSUVWY
	.byte	$1A,$1C,$1D,$1F,$21,$23,$25,$27	; 0DEB  Z\]_!#%'
	.byte	$2A,$2C,$2F,$32,$35,$38,$3B,$3F	; 0DF3  *,/258;?
	.byte	$43,$47,$4B,$4F,$54,$59,$5E,$64	; 0DFB  CGKOTY^d
	.byte	$6A,$70,$77,$7E,$86,$8E,$96,$9F	; 0E03  jpw~FNV_
	.byte	$A8,$B3,$BD,$C8,$D4,$E1,$EE,$FD	; 0E0B  (3=HTan}


L0E67:
	pha					; 0E67
	and	#$0F				; 0E68  O
	sta	voice1_ctrl1,x			; 0E6A
	pla					; 0E6D
	and	#$F0				; 0E6E  p
	lsr	a				; 0E70
	lsr	a				; 0E71
	lsr	a				; 0E72
	lsr	a				; 0E73
	sta	voice1_stuff+5,x		; 0E74
	lda	#$00				; 0E77  .
	sta	voice1_stuff+6,x		; 0E79
	lda	#$01				; 0E7C  A
	sta	voice1_whatever+1,x		; 0E7E
	lda	#$00				; 0E81  .
	sta	voice1_whatever,x		; 0E83
	jmp	voice_done			; 0E86

L0E89:
	sta	voice1_things+1,x		; 0E89
	lda	possibly_instrument_a1+1,y	; 0E8C
	sta	voice1_things+2,x		; 0E8F
	sta	voice1_things+3,x		; 0E92
	lda	#$00				; 0E95  .
	sta	voice1_whatever+1,x		; 0E97
	sta	voice1_things,x			; 0E9A
	lda	#$01				; 0E9D  A
	sta	voice1_whatever,x		; 0E9F
	jmp	voice_done			; 0EA2

possibly_instrument_a0:
	.byte	$00,$81,$0A,$00,$00,$00,$80,$01	; 0EA5  .AJ....A
@possibly_instrument_b0:
	.byte	$90,$41,$FE,$0D,$25,$00,$40,$02	; 0EAD  PA~M%.@B
@possibly_instrument_c0:
	.byte	$00,$81,$FD,$00,$00,$00,$80,$00	; 0EB5  .A}.....
@possibly_instrument_d0:
	.byte	$30,$41,$0E,$00,$30,$00,$40,$02	; 0EBD  0AN.0.@B
@possibly_instrument_e0:
	.byte	$96,$41,$0E,$00,$A0,$00,$40,$02	; 0EC5  VAN. .@B
@possibly_instrument_f0:
	.byte	$00,$00,$00,$00,$00,$00,$00,$00	; 0ECD  ........
@possibly_instrument_g0:
	.byte	$32,$41,$00,$40,$F0,$00,$40,$02	; 0ED5  2A.@p.@B
@possibly_instrument_h0:
	.byte	$00,$81,$08,$00,$00,$00,$80,$01	; 0EDD  .AH....A
@possibly_instrument_i0:
	.byte	$00,$11,$0D,$00,$00,$00,$10,$00	; 0EE5  .QM...P.
@possibly_instrument_j0:
	.byte	$90,$41,$0E,$00,$25,$00,$40,$02	; 0EED  PAN.%.@B
@possibly_instrument_k0:
	.byte	$2E,$43,$00,$60,$F5,$00,$40,$04	; 0EF5  .C.`u.@D
@possibly_instrument_l0:
	.byte	$70,$41,$0A,$00,$40,$00,$40,$02	; 0EFD  pAJ.@.@B
@possibly_instrument_m0:
	.byte	$00,$15,$03,$00,$00,$20,$14,$04	; 0F05  .UC.. TD
@possibly_instrument_n0:
	.byte	$40,$41,$00,$90,$01,$00,$40,$00	; 0F0D  @A.PA.@.
@possibly_instrument_o0:
	.byte	$00,$15,$EE,$00,$00,$00,$14,$00	; 0F15  .Un...T.
@possibly_instrument_p0:
	.byte	$98,$41,$09,$00,$00,$00,$40,$01	; 0F1D  XAI...@A
@possibly_instrument_q0:
	.byte	$21,$41,$0A,$00,$30,$00,$40,$06	; 0F25  !AJ.0.@F
@possibly_instrument_r0:
	.byte	$21,$41,$0A,$00,$30,$00,$40,$06	; 0F2D  !AJ.0.@F
@possibly_instrument_s0:
	.byte	$31,$41,$0E,$00,$10,$00,$40,$02	; 0F35  1AN.P.@B
@possibly_instrument_t0:
	.byte	$23,$41,$00,$A0,$50,$00,$40,$00	; 0F3D  #A. P.@.
@possibly_instrument_u0:
	.byte	$91,$41,$0A,$00,$30,$00,$40,$06	; 0F45  QAJ.0.@F
@possibly_instrument_v0:
	.byte	$F1,$41,$0C,$00,$40,$00,$40,$06	; 0F4D  qAL.@.@F
possibly_instrument_a1:
	.byte	$00,$00,$11,$00,$00,$03,$00,$00	; 0F55  ..Q..C..
@possibly_instrument_b1:
	.byte	$00,$00,$81,$00,$00,$00,$00,$00	; 0F5D  ..A.....
@possibly_instrument_c1:
	.byte	$06,$50,$00,$00,$00,$00,$00,$00	; 0F65  FP......
@possibly_instrument_d1:
	.byte	$30,$02,$81,$00,$00,$00,$00,$00	; 0F6D  0BA.....
@possibly_instrument_e1:
	.byte	$40,$02,$00,$00,$00,$00,$00,$00	; 0F75  @B......
@possibly_instrument_f1:
	.byte	$00,$00,$00,$00,$00,$00,$00,$00	; 0F7D  ........
@possibly_instrument_g1:
	.byte	$00,$00,$81,$00,$00,$00,$00,$00	; 0F85  ..A.....
@possibly_instrument_h1:
	.byte	$00,$00,$11,$41,$01,$01,$00,$00	; 0F8D  ..QAAA..
@possibly_instrument_i1:
	.byte	$50,$02,$00,$00,$00,$00,$00,$00	; 0F95  PB......
@possibly_instrument_j1:
	.byte	$00,$00,$81,$00,$00,$00,$00,$00	; 0F9D  ..A.....
@possibly_instrument_k1:
	.byte	$20,$02,$00,$00,$00,$00,$00,$00	; 0FA5   B......
@possibly_instrument_l1:
	.byte	$00,$00,$00,$00,$00,$00,$00,$00	; 0FAD  ........
@possibly_instrument_m1:
	.byte	$00,$00,$81,$00,$00,$00,$00,$00	; 0FB5  ..A.....
@possibly_instrument_n1:
	.byte	$40,$02,$00,$00,$00,$00,$00,$00	; 0FBD  @B......
@possibly_instrument_o1:
	.byte	$00,$00,$00,$00,$00,$00,$00,$00	; 0FC5  ........
@possibly_instrument_p1:
	.byte	$00,$00,$41,$F0,$01,$01,$00,$00	; 0FCD  ..ApAA..
@possibly_instrument_q1:
	.byte	$10,$02,$43,$00,$00,$00,$00,$00	; 0FD5  PBC.....
@possibly_instrument_r1:
	.byte	$00,$00,$00,$00,$00,$00,$00,$00	; 0FDD  ........
@possibly_instrument_s1:
	.byte	$A0,$02,$00,$00,$00,$00,$00,$00	; 0FE5   B......
@possibly_instrument_t1:
	.byte	$60,$02,$00,$00,$00,$00,$00,$00	; 0FED  `B......
@possibly_instrument_u1:
	.byte	$00,$00,$43,$00,$00,$00,$00,$00	; 0FF5  ..C.....
@possibly_instrument_v1:
	.byte	$0A,$02,$43,$00,$00,$00,$00,$00	; 0FFD  JBC.....

L1005:
	lda	voice1_stuff+2,x		; 1005
	beq	L100D				; 1008
	dec	voice1_stuff+2,x		; 100A
L100D:
	lda	voice1_whatever+3,x		; 100D
	beq	L1025				; 1010
	dec	voice1_whatever+3,x		; 1012
	lda	#$81				; 1015  A
	sta	$D404,x				; 1017
	lda	voice1_stuff+2,x		; 101A
	eor	#$23				; 101D  #
	sta	$D401,x				; 101F
	jmp	voice_done			; 1022

L1025:
	jmp	L103A				; 1025

L1028:
	lda	voice1_stuff+4,x		; 1028
	sta	$D401,x				; 102B
	sta	voice1_stuff+2,x		; 102E
	lda	possibly_instrument_a1+2,y	; 1031
	sta	$D404,x				; 1034
	jmp	voice_done			; 1037

L103A:
	lda	voice1_whatever+4,x		; 103A
	cmp	possibly_instrument_a1+5,y	; 103D
	beq	L104A				; 1040
	inc	voice1_whatever+3,x		; 1042
	inc	voice1_whatever+4,x		; 1045
	bne	L1028				; 1048
L104A:
	lda	#$00				; 104A  .
	sta	voice1_whatever+4,x		; 104C
	sta	voice1_whatever+3,x		; 104F
	beq	L1028				; 1052
tune_tempo:
	.byte	$00,$03,$03			; 1054  .CC
voice1_track:
	.byte	$01,$01,$07,$09,$09,$09,$01,$07	; 1057  AAGIIIAG
	.byte	$07,$0F,$0F,$0F,$0F,$0F,$0F,$03	; 105F  GOOOOOOC
	.byte	$03,$0F,$0F,$13,$13,$0F,$13,$0F	; 1067  COOSSOSO
	.byte	$13,$0F,$13,$0F,$13,$0F,$0F,$0F	; 106F  SOSOSOOO
	.byte	$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F	; 1077  OOOOOOOO
	.byte	$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F	; 107F  OOOOOOOO
	.byte	$0F,$0F,$0F,$0F,$0F,$0F,$1B,$1D	; 1087  OOOOOO[]
	.byte	$1E,$0F,$1B,$1D,$1E,$0F,$1B,$1D	; 108F  ^O[]^O[]
	.byte	$1E,$12,$12,$12,$12,$24,$24,$21	; 1097  ^RRRR$$!
	.byte	$21,$24,$24,$21,$21,$24,$24,$21	; 109F  !$$!!$$!
	.byte	$21,$24,$24,$21,$21,$24,$24,$21	; 10A7  !$$!!$$!
	.byte	$21,$24,$24,$21,$21,$24,$24,$21	; 10AF  !$$!!$$!
	.byte	$21,$24,$24,$21,$21,$24,$24,$21	; 10B7  !$$!!$$!
	.byte	$21,$24,$24,$21,$21,$08,$08,$28	; 10BF  !$$!!HH(
	.byte	$00,$00,$00,$00,$FF		; 10C7  .....
voice2_track:
	.byte	$03,$03,$08,$0A,$0D,$0D,$0D,$0D	; 10CC  CCHJMMMM
	.byte	$08,$07,$0E,$0E,$0E,$0E,$0E,$0E	; 10D4  HGNNNNNN
	.byte	$0E,$0E,$05,$12,$12,$12,$12,$14	; 10DC  NNERRRRT
	.byte	$15,$14,$15,$14,$15,$14,$15,$08	; 10E4  UTUTUTUH
	.byte	$17,$17,$17,$17,$17,$17,$17,$17	; 10EC  WWWWWWWW
	.byte	$17,$17,$17,$17,$07,$07,$1F,$1F	; 10F4  WWWWGG__
	.byte	$1F,$1F,$07,$07,$00,$00,$25,$25	; 10FC  __GG..%%
	.byte	$26,$25,$27,$27,$27,$27,$27,$27	; 1104  &%''''''
	.byte	$27,$27,$06,$06,$06,$06,$06,$06	; 110C  ''FFFFFF
	.byte	$06,$06,$06,$06,$28,$00,$00,$00	; 1114  FFFF(...
	.byte	$00,$FF				; 111C  ..
voice3_track:
	.byte	$00,$00,$00,$00,$04,$06,$06,$0C	; 111E  ....DFFL
	.byte	$0B,$0C,$0B,$0C,$0B,$06,$06,$06	; 1126  KLKLKFFF
	.byte	$06,$06,$06,$06,$06,$06,$06,$06	; 112E  FFFFFFFF
	.byte	$06,$06,$06,$0F,$0F,$10,$11,$0E	; 1136  FFFOOPQN
	.byte	$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E	; 113E  NNNNNNNN
	.byte	$0E,$0E,$0E,$16,$07,$07,$07,$18	; 1146  NNNVGGGX
	.byte	$19,$19,$1A,$1A,$08,$08,$1C,$08	; 114E  YYZZHH\H
	.byte	$08,$23,$23,$22,$22,$23,$23,$22	; 1156  H##\"\"##\"
	.byte	$22,$23,$23,$22,$22,$23,$23,$22	; 115E  \"##\"\"##\"
	.byte	$22,$23,$23,$22,$22,$23,$23,$22	; 1166  \"##\"\"##\"
	.byte	$22,$23,$23,$22,$22,$23,$23,$22	; 116E  \"##\"\"##\"
	.byte	$22,$23,$23,$22,$22,$23,$23,$22	; 1176  \"##\"\"##\"
	.byte	$22,$07,$07,$0F,$0F,$0F,$0F,$29	; 117E  \"GGOOOO)
	.byte	$00,$00,$00,$00,$FF		; 1186  .....
pattern_00:
	.byte	$FD,$3F,$FA,$04,$00,$FF		; 118B  }?zD..
pattern_01:
	.byte	$FA,$01,$FD,$3F,$23,$1F,$22,$1E	; 1191  zA}?#_\"^
	.byte	$FF				; 1199  .
pattern_03:
	.byte	$FA,$01,$FD,$3F,$17,$13,$16,$12	; 119A  zA}?WSVR
	.byte	$FF				; 11A2  .
pattern_02:
	.byte	$FD,$0F,$FA,$04,$00,$FF		; 11A3  }OzD..
pattern_04:
	.byte	$FA,$02,$FD,$7F,$25,$25,$FF	; 11A9  zB}.%%.
pattern_05:
	.byte	$FA,$0E,$FD,$3F,$2F,$2B,$2E,$FC	; 11B0  zN}?/+.|
	.byte	$20,$2A,$FF			; 11B8   *.
pattern_06:
	.byte	$FA,$06,$FD,$01,$42,$3B,$3B,$42	; 11BB  zF}AB;;B
	.byte	$3B,$3B,$43,$3B,$42,$3B,$3B,$42	; 11C3  ;;C;B;;B
	.byte	$3B,$3B,$43,$3B,$42,$3B,$3B,$42	; 11CB  ;;C;B;;B
	.byte	$3B,$3B,$43,$3B,$42,$3B,$3B,$42	; 11D3  ;;C;B;;B
	.byte	$3B,$3B,$43,$3B,$FF		; 11DB  ;;C;.
pattern_07:
	.byte	$FA,$01,$FD,$7F,$23,$FF		; 11E0  zA}.#.
pattern_08:
	.byte	$FA,$01,$FD,$7F,$17,$00,$FF	; 11E6  zA}.W..
pattern_09:
	.byte	$FA,$09,$FD,$1F,$17,$13,$12,$0F	; 11ED  zI}_WSRO
	.byte	$FF				; 11F5  .
pattern_10:
	.byte	$FA,$08,$FD,$0F,$3E,$39,$FD,$1F	; 11F6  zH}O>9}_
	.byte	$3B,$FD,$0F,$3D,$3B,$FD,$1F,$3A	; 11FE  ;}O=;}_:
	.byte	$FD,$7F,$FB,$01,$2F,$FF		; 1206  }.{A/.
pattern_11:
	.byte	$FA,$06,$FD,$01,$3D,$36,$36,$3D	; 120C  zF}A=66=
	.byte	$36,$36,$3E,$36,$3D,$36,$36,$3D	; 1214  66>6=66=
	.byte	$36,$36,$3E,$36,$3A,$33,$33,$3A	; 121C  66>6:33:
	.byte	$33,$33,$3B,$33,$3A,$33,$33,$3A	; 1224  33;3:33:
	.byte	$33,$33,$3B,$33,$FF		; 122C  33;3.
pattern_12:
	.byte	$FA,$06,$FD,$01,$42,$3B,$3B,$42	; 1231  zF}AB;;B
	.byte	$3B,$3B,$43,$3B,$42,$3B,$3B,$42	; 1239  ;;C;B;;B
	.byte	$3B,$3B,$43,$3B,$3E,$37,$37,$3E	; 1241  ;;C;>77>
	.byte	$37,$37,$3F,$37,$3E,$37,$37,$3E	; 1249  77?7>77>
	.byte	$37,$37,$3F,$37,$FF		; 1251  77?7.
pattern_13:
	.byte	$FA,$0A,$FD,$01,$3B,$3A,$39,$38	; 1256  zJ}A;:98
	.byte	$39,$3A,$3B,$3A,$39,$38,$39,$3A	; 125E  9:;:989:
	.byte	$3B,$3A,$39,$38,$39,$3A,$3B,$3A	; 1266  ;:989:;:
	.byte	$39,$38,$39,$3A,$3B,$3A,$39,$38	; 126E  989:;:98
	.byte	$39,$3A,$3B,$3A,$FF		; 1276  9:;:.
pattern_14:
	.byte	$FA,$07,$FD,$01,$2D,$FD,$03,$2D	; 127B  zG}A-}C-
	.byte	$FD,$0D,$2D,$FD,$03,$2D,$FD,$07	; 1283  }M-}C-}G
	.byte	$FA,$00,$2D,$FA,$07,$FD,$01,$2D	; 128B  z.-zG}A-
	.byte	$FD,$03,$2D,$FD,$0D,$2D,$FD,$03	; 1293  }C-}M-}C
	.byte	$2D,$FD,$07,$FA,$00,$2D,$FF	; 129B  -}Gz.-.
pattern_15:
	.byte	$FA,$0B,$FD,$01,$23,$23,$23,$23	; 12A2  zK}A####
	.byte	$23,$23,$23,$23,$23,$23,$23,$23	; 12AA  ########
	.byte	$23,$23,$23,$23,$23,$23,$23,$23	; 12B2  ########
	.byte	$23,$23,$23,$23,$23,$23,$23,$23	; 12BA  ########
	.byte	$23,$23,$23,$23,$FF		; 12C2  ####.
pattern_16:
	.byte	$FA,$0B,$FD,$01,$22,$22,$22,$22	; 12C7  zK}A\"\"\"\"
	.byte	$22,$22,$22,$22,$22,$22,$22,$22	; 12CF  \"\"\"\"\"\"\"\"
	.byte	$22,$22,$22,$22,$22,$22,$22,$22	; 12D7  \"\"\"\"\"\"\"\"
	.byte	$22,$22,$22,$22,$22,$22,$22,$22	; 12DF  \"\"\"\"\"\"\"\"
	.byte	$22,$22,$22,$22,$FF		; 12E7  \"\"\"\".
pattern_17:
	.byte	$FA,$0B,$FD,$01,$25,$25,$25,$25	; 12EC  zK}A%%%%
	.byte	$25,$25,$25,$25,$25,$25,$25,$25	; 12F4  %%%%%%%%
	.byte	$25,$25,$25,$25,$25,$25,$25,$25	; 12FC  %%%%%%%%
	.byte	$25,$25,$25,$25,$25,$25,$25,$25	; 1304  %%%%%%%%
	.byte	$25,$25,$25,$25,$FF		; 130C  %%%%.
pattern_18:
	.byte	$FA,$0A,$FD,$01,$3B,$37,$36,$34	; 1311  zJ}A;764
	.byte	$3B,$37,$36,$34,$3B,$37,$36,$34	; 1319  ;764;764
	.byte	$3B,$37,$36,$34,$3B,$37,$36,$34	; 1321  ;764;764
	.byte	$3B,$37,$36,$34,$3B,$37,$36,$34	; 1329  ;764;764
	.byte	$3B,$37,$36,$34,$FF		; 1331  ;764.
pattern_19:
	.byte	$FA,$0B,$FD,$01,$1F,$1F,$1F,$1F	; 1336  zK}A____
	.byte	$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F	; 133E  ________
	.byte	$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F	; 1346  ________
	.byte	$1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F	; 134E  ________
	.byte	$1F,$1F,$1F,$1F,$FF		; 1356  ____.
pattern_20:
	.byte	$FA,$06,$FD,$01,$3F,$3B,$36,$3F	; 135B  zF}A?;6?
	.byte	$3B,$36,$3F,$3B,$3F,$3B,$36,$3F	; 1363  ;6?;?;6?
	.byte	$3B,$36,$3F,$3B,$3F,$3B,$36,$3F	; 136B  ;6?;?;6?
	.byte	$3B,$36,$3F,$3B,$3F,$3B,$36,$3F	; 1373  ;6?;?;6?
	.byte	$3B,$36,$3F,$3B,$FF		; 137B  ;6?;.
pattern_21:
	.byte	$FA,$06,$FD,$01,$3E,$3B,$37,$3E	; 1380  zF}A>;7>
	.byte	$3B,$37,$3E,$3B,$3E,$3B,$37,$3E	; 1388  ;7>;>;7>
	.byte	$3B,$37,$3E,$3B,$3E,$3B,$37,$3E	; 1390  ;7>;>;7>
	.byte	$3B,$37,$3E,$3B,$3E,$3B,$37,$3E	; 1398  ;7>;>;7>
	.byte	$3B,$37,$3E,$3B,$FF		; 13A0  ;7>;.
pattern_22:
	.byte	$FA,$0D,$FD,$1F,$37,$36,$39,$37	; 13A5  zM}_7697
	.byte	$36,$2F,$2F,$32,$FF		; 13AD  6//2.
pattern_23:
	.byte	$FA,$10,$FD,$01,$23,$23,$2A,$2A	; 13B2  zP}A##**
	.byte	$28,$28,$2A,$2A,$26,$26,$2A,$2A	; 13BA  ((**&&**
	.byte	$28,$28,$2A,$2A,$23,$23,$2A,$2A	; 13C2  ((**##**
	.byte	$28,$28,$2A,$2A,$26,$26,$2A,$2A	; 13CA  ((**&&**
	.byte	$28,$28,$2A,$2A,$FF		; 13D2  ((**.
pattern_24:
	.byte	$FA,$13,$FD,$07,$FC,$37,$45,$FD	; 13D7  zS}G|7E}
	.byte	$2F,$47,$FD,$07,$FB,$7F,$47,$FD	; 13DF  /G}G{.G}
	.byte	$37,$42,$FD,$07,$FB,$80,$42,$FF	; 13E7  7B}G{.B.
pattern_25:
	.byte	$FA,$13,$FD,$1F,$3B,$FD,$0F,$39	; 13EF  zS}_;}O9
	.byte	$37,$FD,$3F,$36,$FF		; 13F7  7}?6.
pattern_26:
	.byte	$FA,$13,$FD,$1F,$34,$FD,$0F,$32	; 13FC  zS}_4}O2
	.byte	$31,$FD,$3F,$2F,$FF		; 1404  1}?/.
pattern_27:
	.byte	$FA,$0B,$FD,$01,$1B,$1B,$1B,$1B	; 1409  zK}A[[[[
	.byte	$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1B	; 1411  [[[[[[[[
	.byte	$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1B	; 1419  [[[[[[[[
	.byte	$1B,$1B,$1B,$1B,$1B,$1B,$1B,$1B	; 1421  [[[[[[[[
	.byte	$1B,$1B,$1B,$1B,$FF		; 1429  [[[[.
pattern_28:
	.byte	$FA,$01,$FD,$1F,$3B,$FD,$0F,$3A	; 142E  zA}_;}O:
	.byte	$36,$FD,$2F,$36,$FD,$0F,$38,$FD	; 1436  6}/6}O8}
	.byte	$1F,$38,$2F,$31,$FD,$0F,$33,$34	; 143E  _8/1}O34
	.byte	$FD,$7F,$36,$36,$FF		; 1446  }.66.
pattern_29:
	.byte	$FA,$0B,$FD,$01,$1C,$1C,$1C,$1C	; 144B  zK}A\\\\
	.byte	$1C,$1C,$1C,$1C,$1C,$1C,$1C,$1C	; 1453  \\\\\\\\
	.byte	$1C,$1C,$1C,$1C,$1C,$1C,$1C,$1C	; 145B  \\\\\\\\
	.byte	$1C,$1C,$1C,$1C,$1C,$1C,$1C,$1C	; 1463  \\\\\\\\
	.byte	$1C,$1C,$1C,$1C,$FF		; 146B  \\\\.
pattern_30:
	.byte	$FA,$0B,$FD,$01,$1E,$1E,$1E,$1E	; 1470  zK}A^^^^
	.byte	$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E	; 1478  ^^^^^^^^
	.byte	$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E	; 1480  ^^^^^^^^
	.byte	$1E,$1E,$1E,$1E,$1E,$1E,$1E,$1E	; 1488  ^^^^^^^^
	.byte	$1E,$1E,$1E,$1E,$FF		; 1490  ^^^^.
pattern_31:
	.byte	$FA,$09,$FD,$3F,$23,$1B,$1C,$1E	; 1495  zI}?#[\^
	.byte	$FF				; 149D  .
pattern_32:
	.byte	$FA,$01,$FD,$7F,$17,$17,$FF,$21	; 149E  zA}.WW.!
	.byte	$26,$FD,$11,$28,$FF		; 14A6  &}Q(.
pattern_33:
	.byte	$FA,$15,$FD,$01,$1F,$1F,$FD,$03	; 14AB  zU}A__}C
	.byte	$1F,$FA,$0F,$FD,$01,$2E,$27,$FA	; 14B3  _zO}A.'z
	.byte	$15,$1F,$FD,$03,$1F,$FD,$01,$1F	; 14BB  U_}C_}A_
	.byte	$FD,$03,$1F,$FD,$01,$FA,$0F,$2F	; 14C3  }C_}AzO/
	.byte	$FA,$15,$1A,$1D,$1F,$FF		; 14CB  zUZ]_.
pattern_34:
	.byte	$FA,$09,$FD,$01,$13,$13,$FD,$03	; 14D1  zI}ASS}C
	.byte	$13,$FD,$01,$FA,$00,$2E,$27,$FA	; 14D9  S}Az..'z
	.byte	$09,$13,$FD,$03,$13,$FD,$01,$13	; 14E1  IS}CS}AS
	.byte	$FD,$03,$13,$FD,$01,$13,$10,$11	; 14E9  }CS}ASPQ
	.byte	$13,$FF				; 14F1  S.
pattern_35:
	.byte	$FA,$09,$FD,$01,$17,$17,$FD,$03	; 14F3  zI}AWW}C
	.byte	$17,$FD,$01,$FA,$00,$2E,$27,$FA	; 14FB  W}Az..'z
	.byte	$09,$17,$FD,$03,$17,$FD,$01,$17	; 1503  IW}CW}AW
	.byte	$FD,$03,$17,$FD,$01,$17,$12,$15	; 150B  }CW}AWRU
	.byte	$17,$FF				; 1513  W.
pattern_36:
	.byte	$FA,$15,$FD,$01,$23,$23,$FD,$03	; 1515  zU}A##}C
	.byte	$23,$FA,$0F,$FD,$01,$2E,$27,$FA	; 151D  #zO}A.'z
	.byte	$15,$23,$FD,$03,$23,$FD,$01,$23	; 1525  U#}C#}A#
	.byte	$FD,$03,$23,$FD,$01,$FA,$0F,$2F	; 152D  }C#}AzO/
	.byte	$FA,$15,$1E,$21,$23,$FF		; 1535  zU^!#.
pattern_37:
	.byte	$FA,$0A,$FD,$39,$47,$FD,$01,$46	; 153B  zJ}9G}AF
	.byte	$45,$44,$FD,$39,$43,$FD,$01,$44	; 1543  ED}9C}AD
	.byte	$45,$46,$FF			; 154B  EF.
pattern_38:
	.byte	$FA,$12,$FD,$3F,$3B,$43,$42,$3E	; 154E  zR}?;CB>
	.byte	$3B,$37,$36,$2F,$FF		; 1556  ;76/.
pattern_39:
	.byte	$FA,$0C,$FD,$01,$31,$3D,$49,$3D	; 155B  zL}A1=I=
	.byte	$31,$3D,$49,$3D,$FF		; 1563  1=I=.
pattern_40:
	.byte	$FA,$01,$FD,$7F,$17,$00,$00,$00	; 1568  zA}.W...
	.byte	$FF				; 1570  .
pattern_41:
	.byte	$FA,$01,$FD,$7F,$23,$00,$00,$00	; 1571  zA}.#...
	.byte	$FF				; 1579  .

arpeggio_table:
	.addr	arpeggio_0			; 157A

arpeggio_0:
	.byte	$00,$0C,$18			; 157C  .LX
pattern_lobytes:
	.byte <pattern_00
	.byte <pattern_01
	.byte <pattern_03
	.byte <pattern_02
	.byte <pattern_04
	.byte <pattern_05
	.byte <pattern_06
	.byte <pattern_07
	.byte <pattern_08
	.byte <pattern_09
	.byte <pattern_10
	.byte <pattern_11
	.byte <pattern_12
	.byte <pattern_13
	.byte <pattern_14
	.byte <pattern_15
	.byte <pattern_16
	.byte <pattern_17
	.byte <pattern_18
	.byte <pattern_19
	.byte <pattern_20
	.byte <pattern_21
	.byte <pattern_22
	.byte <pattern_23
	.byte <pattern_24
	.byte <pattern_25
	.byte <pattern_26
	.byte <pattern_27
	.byte <pattern_28
	.byte <pattern_29
	.byte <pattern_30
	.byte <pattern_31
	.byte <pattern_32
	.byte <pattern_33
	.byte <pattern_34
	.byte <pattern_35
	.byte <pattern_36
	.byte <pattern_37
	.byte <pattern_38
	.byte <pattern_39
	.byte <pattern_40
	.byte <pattern_41
pattern_hibytes:
	.byte >pattern_00
	.byte >pattern_01
	.byte >pattern_03
	.byte >pattern_02
	.byte >pattern_04
	.byte >pattern_05
	.byte >pattern_06
	.byte >pattern_07
	.byte >pattern_08
	.byte >pattern_09
	.byte >pattern_10
	.byte >pattern_11
	.byte >pattern_12
	.byte >pattern_13
	.byte >pattern_14
	.byte >pattern_15
	.byte >pattern_16
	.byte >pattern_17
	.byte >pattern_18
	.byte >pattern_19
	.byte >pattern_20
	.byte >pattern_21
	.byte >pattern_22
	.byte >pattern_23
	.byte >pattern_24
	.byte >pattern_25
	.byte >pattern_26
	.byte >pattern_27
	.byte >pattern_28
	.byte >pattern_29
	.byte >pattern_30
	.byte >pattern_31
	.byte >pattern_32
	.byte >pattern_33
	.byte >pattern_34
	.byte >pattern_35
	.byte >pattern_36
	.byte >pattern_37
	.byte >pattern_38
	.byte >pattern_39
	.byte >pattern_40
	.byte >pattern_41
voice1_tune_trackptr_lo:
	.byte	$00
	.byte <voice1_track
voice1_tune_trackptr_hi:
	.byte	$00
	.byte >voice1_track
voice2_tune_trackptr_lo:
	.byte	$00
	.byte <voice2_track
voice2_tune_trackptr_hi:
	.byte	$00
	.byte >voice2_track
voice3_tune_trackptr_lo:
	.byte	$00
	.byte <voice3_track
voice3_tune_trackptr_hi:
	.byte	$00
	.byte >voice3_track
