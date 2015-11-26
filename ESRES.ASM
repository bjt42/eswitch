; ESRES.ASM
;
; EGA/Tandy video switch utility, resident portion.
;

	JMP	START

;
; Resident data.
;
INT2FOLD	DD	0		; default Int 2Fh vector
MAGIC1		EQU	191Fh		; magic numbers for entry
MAGIC2		EQU	0EF9Ch
MAGIC3		EQU	493Ch		; magic numbers for exit
MAGIC4		EQU	97BAh
EGAON           DB      1               ; 1 if EGA is active, 0 if not
MONO		DB	0		; 1 if onboard video is mono TTL
VIDDATASIZE	EQU	57
ONBOARDDATA	DB	VIDDATASIZE DUP (0)	; BIOS data for onboard video
EGADATA         DB      VIDDATASIZE DUP (0)     ; BIOS data for EGA
                ; low byte of the BIOS equipment list, when EGA is active
EGAEQUIP        DB      0

;
; Multiplex interrupt handler.  This is the entry point for the resident
; portion.  To toggle video types, ESWITCH will issue Int 2Fh with BX equal
; to MAGIC1 and CX equal to MAGIC2.  ESRES will switch video types and
; return with BX equal to MAGIC3 and CX equal to MAGIC4.  This will allow
; ESWITCH to determine if ESRES was installed.
;
INT2FHDLR:
	CMP	BX,MAGIC1	; is it our interrupt?
	JNE	NOT_OURS
	CMP	CX,MAGIC2
	JE	SWITCHOK
NOT_OURS:
	JMP	DWORD PTR CS:INT2FOLD
	;
	; It's our interrupt.  Enable hardware interrupts, save
	; registers, and let DS address local data.
	;
SWITCHOK:
	STI
	PUSH	AX
	PUSH	DX
	PUSH	SI
	PUSH	DI
	PUSH	BP
	PUSH	DS
	PUSH	ES
	MOV	AX,CS
	MOV	DS,AX
	CLD			; DF set for incrementing
        CMP     EGAON,1
	JE	TOTANDY
        JMP     TOEGA
	;
        ; Switching from EGA to onboard video.
	;
TOTANDY:
        MOV     ES,AX           ; ES:DI -> EGADATA
        MOV     DI,OFFSET EGADATA
        MOV     DX,3C2h         ; EGA misc output register
        MOV     AL,30h          ; Mono emulation, disable vram, disable video
        OUT     DX,AL
	XOR	AX,AX		; DS -> interrupt vector table
	MOV	DS,AX
	CLI
	MOV	SI,14h		; save Int 5 vector
	MOVSW
	MOVSW
	MOV	SI,40h		; save Int 10h vector
	MOVSW
	MOVSW
	MOV	SI,74h		; save Int 1Dh vector
	MOVSW
	MOVSW
	MOV	SI,7Ch		; save Int 1Fh vector
	MOVSW
	MOVSW
	MOV	SI,10Ch		; save Int 43h vector
	MOVSW
	MOVSW
	STI
	MOV	AX,40h		; DS -> BIOS data
	MOV	DS,AX
	MOV	SI,49h		; save first BIOS video data area
	MOV	CX,30
	REP	MOVSB
	MOV	SI,84h		; save second BIOS video data area
	MOV	CX,7
	REP	MOVSB
	MOV	AX,CS		; DS:SI -> ONBOARDDATA
	MOV	DS,AX
	MOV	SI,OFFSET ONBOARDDATA
	XOR	AX,AX		; ES -> interrupt vector table
	MOV	ES,AX
	CLI
	MOV	DI,14h		; set Int 5 vector
	MOVSW
	MOVSW
	MOV	DI,40h		; set Int 10h vector
	MOVSW
	MOVSW
	MOV	DI,74h		; set Int 1Dh vector
	MOVSW
	MOVSW
	MOV	DI,7Ch		; set Int 1Fh vector
	MOVSW
	MOVSW
	MOV	DI,10Ch		; set Int 43h vector
	MOVSW
	MOVSW
	STI
	MOV	AX,40h		; ES -> BIOS data
	MOV	ES,AX
	MOV	DI,49h		; set first BIOS video data area
	MOV	CX,30
	REP	MOVSB
	MOV	DI,84h		; set second BIOS video data area
	MOV	CX,7
	REP	MOVSB
	AND	BYTE PTR ES:[0B5h],0EFh	; clear "external video" bit
	MOV	AL,ES:[10h]	; save low byte of BIOS equipment list
        MOV     EGAEQUIP,AL
	CMP	MONO,1		; is the onboard monitor mono?
	JE	TOTANDY_MONO
	AND	AL,0CFh		; not mono - set initial video mode for color
	OR	AL,20h
	MOV	ES:[10h],AL
	MOV	AL,0FFh		; enable the onboard video
	OUT	65h,AL
	MOV	AX,2		; set video mode 2
	INT	10h
	JMP	DONE
TOTANDY_MONO:
	OR	AL,30h		; set initial video mode for mono
	MOV	ES:[10h],AL
	MOV	AL,0FFh		; enable the onboard video
	OUT	65h,AL
	MOV	AX,7		; set video mode 7
	INT	10h
	JMP	DONE
	;
        ; Switching from onboard video to EGA.
	;
TOEGA:
	MOV	AL,0FBh		; disable the onboard video
	OUT	65h,AL
        MOV     SI,OFFSET EGADATA       ; DS:SI -> EGADATA
	XOR	AX,AX		; ES -> interrupt vector table
	MOV	ES,AX
	CLI
	MOV	DI,14h		; set Int 5 vector
	MOVSW
	MOVSW
	MOV	DI,40h		; set Int 10h vector
	MOVSW
	MOVSW
	MOV	DI,74h		; set Int 1Dh vector
	MOVSW
	MOVSW
	MOV	DI,7Ch		; set Int 1Fh vector
	MOVSW
	MOVSW
	MOV	DI,10Ch		; set Int 43h vector
	MOVSW
	MOVSW
	STI
	MOV	AX,40h		; ES -> BIOS data
	MOV	ES,AX
	MOV	DI,49h		; set first BIOS video data area
	MOV	CX,30
	REP	MOVSB
	MOV	DI,84h		; set second BIOS video data area
	MOV	CX,7
	REP	MOVSB
	OR	BYTE PTR ES:[0B5h],10h	; set "external video" bit
        MOV     AL,EGAEQUIP     ; restore initial video mode bits
	MOV	ES:[10h],AL
        MOV     DX,3C2h         ; EGA misc output register
        MOV     AL,23h          ; Colour emulation, enable vram, enable video
        OUT     DX,AL
	;
	; Return the magic number, restore registers, and exit.
	;
DONE:
        XOR     EGAON,1
	MOV	BX,MAGIC3
	MOV	CX,MAGIC4
	POP	ES
	POP	DS
	POP	BP
	POP	DI
	POP	SI
	POP	DX
	POP	AX
	IRET

;
; End of resident code and data.
;
RES_END		EQU	$+1

;
; Temporary (nonresident) data for installation.
;
NOEGAMSG        DB      "EGA not detected, resident part of video "
		DB	"switch utility not installed.",0Dh,0Ah,"$"
NOTANDYMSG	DB	"Tandy 1000-series not detected, resident "
		DB	"part of video switch utility",0Dh,0Ah
		DB	"not installed.",0Dh,0Ah,"$"
INSTALLMSG	DB	"Resident part of video switch utility installed -"
		DB	0Dh,0Ah,"$"
MONOMSG		DB	"  onboard video monitor is monochrome TTL."
		DB	0Dh,0Ah,"$"
CGAMSG		DB	"  onboard video monitor is CGA."
		DB	0Dh,0Ah,"$"
		;
		; BIOS data for CGA.  Omitted:  BIOS equipment list at
		; 40:10h (word), extra video data at 40:B5h (byte).
		;
CGADATA		LABEL	BYTE
		DB	54h,0FFh,00h,0F0h	; Int 5 (print screen) vector
		DW	0F065h,0F000h		; Int 10h vector
		DB	00h,0E0h,00h,0F0h	; Int 1Dh vector
		DB	0ADh,0C0h,00h,0F0h	; Int 1Fh vector
		DB	00h,00h,00h,00h		; Int 43h vector
			; first BIOS video data area, 40:49h to 66h
		DB	03h,50h,00h,00h,10h,00h,00h
		DB	00h,18h,00h,00h,00h,00h,00h,00h
		DB	00h,00h,00h,00h,00h,00h,00h,00h
		DB	07h,06h,00h,0D4h,03h,29h,20h
			; second BIOS video data area, 40:84h to 8Ah
		DB	00h,00h,00h,00h,00h,00h,3Fh
		;
		; BIOS data for monochrome.
		;
MONODATA	LABEL	BYTE
		DB	54h,0FFh,00h,0F0h	; Int 5 (print screen) vector
		DW	0F065h,0F000h		; Int 10h vector
		DB	00h,0E0h,00h,0F0h	; Int 1Dh vector
		DB	0ADh,0C0h,00h,0F0h	; Int 1Fh vector
		DB	00h,00h,00h,00h		; Int 43h vector
			; first BIOS video data area, 40:49h to 66h
		DB	07h,50h,00h,00h,40h,00h,00h
		DB	00h,18h,00h,00h,00h,00h,00h,00h
		DB	00h,00h,00h,00h,00h,00h,00h,00h
		DB	0Ch,0Bh,00h,0B4h,03h,29h,20h
			; second BIOS video data area, 40:84h to 8Ah
		DB	00h,00h,00h,00h,00h,00h,3Fh

;
; Nonresident installation code.
;
; Subroutine, takes pointer to string in DS:SI and length of string in CX,
; skips over blanks and tabs, returns pointer to first nonblank character
; in the string in DS:SI, length of remaining string in CX.  If end of
; string is reached, return pointer to end of string in DS:SI, zero in CX.
;
SKIPBLANKS:
	PUSH	AX
SKIPBLANKS_LOOP:
	JCXZ	SKIPBLANKS_END
	LODSB
	DEC	CX
	CMP	AL,9
	JE	SKIPBLANKS_LOOP
	CMP	AL,20h
	JE	SKIPBLANKS_LOOP
	DEC	SI
	INC	CX
SKIPBLANKS_END:
	POP	AX
	RET

;
; Main program.
;
; First check for VGA and do not install if found.
; Then check for EGA and do not install if not found.
;
START:
        MOV     AX,1A00h        ; read display combination code
        MOV     BX,0EEEEh       ; unused display code
        INT     10h
        CMP     BL,7            ; BL = 7 for mono VGA
        JE      NOT_EGA
        CMP     BL,8            ; BL = 8 for color VGA
        JE      NOT_EGA
        MOV     AH,12h          ; get EGA info
        MOV     BX,0FF10h
        INT     10h
        CMP     BH,0FFh         ; unused state code
        JNE     CHK_TANDY
	;
        ; EGA not detected - display error message and exit.
	;
NOT_EGA:
        MOV     DX,OFFSET NOEGAMSG
	MOV	AH,9
	INT	21h
	INT	20h
	;
	; Check for a Tandy 1000-series.  Do not install if not found.
	;
CHK_TANDY:
	MOV	AX,0FFFFh
	MOV	ES,AX
	CMP	BYTE PTR ES:[0Eh],0FFh
	JNE	NOT_TANDY
	MOV	AX,0FC00h
	MOV	ES,AX
	CMP	BYTE PTR ES:[0],21h
	JE	INSTALL
	;
	; Tandy 1000-series not detected - display error message and exit.
	;
NOT_TANDY:
	MOV	DX,OFFSET NOTANDYMSG
	MOV	AH,9
	INT	21h
	INT	20h
	;
	; Installation OK - check for a command-line parameter.  Only one
	; is allowed:  "M" or "MONO", which indicates that the monitor for
	; the onboard video is monochrome TTL rather than CGA.
	;
INSTALL:
	MOV	CL,[80h]	; CX = length of command line
	MOV	CH,0
	MOV	SI,81h		; SI -> command line
	CLD			; DF set for incrementing
	CALL	SKIPBLANKS	; skip over blanks and tabs
	JCXZ	INSTALL_CGA
	LODSB			; get first character of the parameter
	CMP	AL,'M'		; if "M" or "m", mono
	JE	INSTALL_MONO
	CMP	AL,'m'
	JNE	INSTALL_CGA
	;
	; Onboard video is monochrome TTL.
	;
INSTALL_MONO:
	MOV	MONO,1
	MOV	SI,OFFSET MONODATA
	MOV	AX,DS
	MOV	ES,AX
	MOV	DI,OFFSET ONBOARDDATA
	MOV	CX,VIDDATASIZE
	REP	MOVSB
	JMP	HOOKINT2F
	;
	; Onboard video is CGA.
	;
INSTALL_CGA:
	MOV	MONO,0
	MOV	SI,OFFSET CGADATA
	MOV	AX,DS
	MOV	ES,AX
	MOV	DI,OFFSET ONBOARDDATA
	MOV	CX,VIDDATASIZE
	REP	MOVSB
	;
	; Hook Int 2Fh.
	;
HOOKINT2F:
	MOV	AX,352Fh	; get default Int 2Fh vector and save
	INT	21h
	MOV	WORD PTR INT2FOLD,BX
	MOV	WORD PTR INT2FOLD+2,ES
	MOV	AX,252Fh	; hook Int 2Fh
	MOV	DX,OFFSET INT2FHDLR
	INT	21h
	;
	; Display "installed" message.
	;
	MOV	DX,OFFSET INSTALLMSG
	MOV	AH,9
	INT	21h
	MOV	DX,OFFSET CGAMSG
	CMP	MONO,1
	JNE	SHOWVIDTYPE
	MOV	DX,OFFSET MONOMSG
SHOWVIDTYPE:
	MOV	AH,9
	INT	21h
	;
	; Terminate and stay resident.
	;
	MOV	DX,RES_END
	INT	27h
