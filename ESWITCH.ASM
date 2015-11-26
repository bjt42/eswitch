; ESWITCH.ASM
;
; EGA/Tandy video switch utility, command-line portion.
;

	JMP	START

;
; Data.
;
MAGIC1		EQU	191Fh		; magic numbers for entry
MAGIC2		EQU	0EF9Ch
MAGIC3		EQU	493Ch		; magic numbers for exit
MAGIC4		EQU	97BAh
FAILMSG         DB      "Video switch failed, ESRES not installed."
		DB	0Dh,0Ah,"$"

;
; Main program.
;
; Do the switch.
;
START:
	MOV	BX,MAGIC1
	MOV	CX,MAGIC2
	INT	2Fh
	;
	; Display message in case of failure.  No message if successful.
	;
	CMP	BX,MAGIC3
	JNE	FAILED
	CMP	CX,MAGIC4
	JE	SUCCEEDED
FAILED:
	MOV	DX,OFFSET FAILMSG
	MOV	AH,9
	INT	21h
SUCCEEDED:
	INT	20h
