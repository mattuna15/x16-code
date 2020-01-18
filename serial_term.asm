;  cx16 chat client  
;   based on code from 
;  "https://github.com/jeff-1amstudios/c64-to-raspberrypi

;
;
*=$0801			; Assembled code should start at $0801
			; (where BASIC programs start)
			; The real program starts at $0810 = 2064
!byte $0C,$08		; $080C - pointer to next line of BASIC code
!byte $0A,$00		; 2-byte line number ($000A = 10)
!byte $9E		; SYS BASIC token
!byte $20		; [space]
!byte $32,$30,$36,$34	; $32="2",$30="0",$36="6",$34="4"
			; (ASCII encoded nums for dec starting addr)
!byte $00		; End of Line
!byte $00,$00		; This is address $080C containing
			; 2-byte pointer to next line of BASIC code
			; ($0000 = end of program)
			
*=$0810			; Here starts the real program

; 
; C64 Programmers Reference - http://www.zimmers.net/cbmpics/cbm/c64/c64prg.txt
;

; KERNAL function pointers
GETIN = $FFE4
CHKIN = $FFC6
CHKOUT = $FFC9
SETLFS = $FFBA
OPEN = $FFC0
SETNAM = $FFBD
CHROUT = $FFD2
CLRCHN = $FFCC

; rs232 buffer pointers
RS232_INBUF_PTR = $f7
RS232_OUTBUF_PTR = $f9

CHAR_CLS = 147                          ; clear screen control character

    ; set rs232 output buffer pointer to our .output_buffer
    ldx #<.output_buffer
    sta RS232_OUTBUF_PTR
    ldx #>.output_buffer
    sta RS232_OUTBUF_PTR+1
    
    ; set rs232 input buffer pointer to our .input_buffer
    ldx #<.input_buffer
    sta RS232_INBUF_PTR
    ldx #>.input_buffer
    sta RS232_INBUF_PTR+1

    ; setup a logical file descriptor, pointing to device 2 (user port)
    ; this is equivalent to the OPEN
    lda #3                      ; logical file #
    ldx #2                      ; 2 = rs-232 device
    ldy #0                      ; no extra command
    jsr SETLFS

    ; setup the file name pointer for the file descriptor above
    lda #0                      ; null file name (this is not a file on disk)
    jsr SETNAM

    ; setup the rs232 connection configuration
    lda #%00000110              ; select 300 baud, 8 bits per character
    sta $0293                   ; store in rs232 control register

    ; open the logical file
    jsr OPEN

    jsr screen_init
    jmp main_loop

screen_init
    lda #CHAR_CLS
    jsr CHROUT                  ; print 'Clear Screen' control character to screen

    ldx #<.banner_text
    stx $fb
    ldx #>.banner_text
    stx $fc
    jsr screen_print_str        ; print banner text to screen

    lda #0
    sta $cc                     ; enable blinking cursor
    rts
    
main_loop
    jsr rs232_try_read_byte
    cmp #0
    beq do_keyboard_read        ; if char is null, check keyboard input...
    jsr CHROUT                  ; ... otherwise, output to screen
    
do_keyboard_read
    jsr GETIN
    cmp #0
    beq main_loop          		; if char is null, go back to main loop...     
    jsr CHROUT
    jsr rs232_write_byte        ; ... otherwise, output to rs232 channel

    jmp main_loop

; ----------------------------------------------------------------------
; Reads a single byte from open file #3
; Returns: A
; If no data available, will return immediately with \0
; ----------------------------------------------------------------------
rs232_try_read_byte
    ldx #3
    jsr CHKIN       ; select file 3 as IO input stream
    jsr GETIN       ; read byte from IO input stream
    tay             ; CLRCHN uses A, so copy A -> Y
    jsr CLRCHN      ; reset IO back to default keyboard/screen
    tya             ; copy Y -> A
    rts

; ----------------------------------------------------------------------
; Writes a single byte to open file #3
; Inputs: A (byte to write)
; ----------------------------------------------------------------------
rs232_write_byte
    ldx #3
    tay             ; CHKOUT uses A, so copy A -> Y
    jsr CHKOUT      ; select file 3 as IO output stream
    tya             ; copy Y -> A
    jsr CHROUT      ; write byte to IO output
    jsr CLRCHN      ; reset IO back to default keyboard/screen
    rts

; ----------------------------------------------------------------------
; Prints a null-terminated string to the screen
; Inputs $fb, $fc: pointer to string
; ----------------------------------------------------------------------
screen_print_str
    ldy #0
.print_str_loop
    lda ($fb), y
    cmp #0
    beq .print_str_exit
    jsr CHROUT
    iny
    jmp .print_str_loop

.print_str_exit
    rts

; Variables
.entry_point
.output_buffer !fill 256, 0
.input_buffer !fill 256, 0
.banner_text 
    !byte 13
    !pet "cx16 chat client    ", 13, 13, 13
    !pet "based on code from  ", 13, 13, 13
    !pet "https://github.com/jeff-1amstudios/c64-to-raspberrypi", 13, 13, 13
    !pet "------", 13, 13, 13
    !pet "type your message to send and press enter", 13, 13, 13
    !pet "you'll see the text on your screen", 13, 13, 13
    !pet "------", 13, 13, 13