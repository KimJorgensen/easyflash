; load A/X
	.macro ldax arg
	.if (.match (.left (1, arg), #))	; immediate mode
	lda #<(.right (.tcount (arg)-1, arg))
	ldx #>(.right (.tcount (arg)-1, arg))
	.else					; assume absolute or zero page
	lda arg
	ldx 1+(arg)
	.endif
	.endmacro

; store A/X
	.macro stax arg
	sta arg
	stx 1+(arg)
	.endmacro	

; convert ascii to screencodes
	.macro screencode str
	.repeat .strlen(str), I
		.if ((.strat(str, I) & $60) = $20)
			.byte .strat(str, I)
		.endif
		.if ((.strat(str, I) & $60) = $40)
			.byte .strat(str, I)
		.endif
		.if ((.strat(str, I) & $60) = $60)
			.byte .strat(str, I) & $1f
		.endif
	.endrepeat
	.endmacro
