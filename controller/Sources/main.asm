;***********************************************************************
; ECE 362 - Joystick Sampling - Spring 2012                         
;***********************************************************************
;	 	  	     		       	 		
; Completed by: < Kyle Brown >
;               < 7187-B >
;               < 7 >
;
;
; Academic Honesty Statement:  In entering my name above, I hereby certify
; that I am the individual who created this HC(S)12 source file and that I 
; have not copied the work of any other student (past or present) while 
; completing it. I understand that if I fail to honor this agreement, I will 
; receive a grade of ZERO and be subject to possible disciplinary action.
;                             
;***********************************************************************
;
; This code samples the horizontal and vertical analog values for player
; 0 and player 1's joystick inputs.  These range from 0 - 5 volts with 
; a nuetral joystick reading a 2.5 volts.  These values are converted to 
; 8 bit values ranging from 0-255 with a nuetral joystick reading 127.
; Currently this is sampled 60 times a second, currently triggered RTI,
; it will actually be triggered by the vertical sync pulse.
;
; -Kyle Brown 3/24/2012
;========================================================================
;
; 9S12C32 REGISTER MAP (include file is not necessary)

INITRM   EQU   $0010   ; INITRM - INTERNAL RAM POSITION REGISTER
INITRG   EQU   $0011   ; INITRG - INTERNAL REGISTER POSITION REGISTER
	 	  	     		       	 		
; ==== CRG - Clock and Reset Generator

SYNR     EQU   $0034   ; CRG synthesizer register
REFDV    EQU   $0035   ; CRG reference divider register
CRGFLG   EQU   $0037   ; CRG flags register
CRGINT   EQU   $0038
CLKSEL   EQU   $0039   ; CRG clock select register
PLLCTL   EQU   $003A   ; CRG PLL control register
RTICTL   EQU   $003B
COPCTL   EQU   $003C


; ==== ATD (analog to Digital) Converter / Pushbutton Digital Inputs

ATDCTL2  EQU   $0082   ; ATDCTL2 control register
ATDCTL3  EQU   $0083   ; ATDCTL3 control register
ATDCTL4  EQU   $0084   ; ATDCTL4 control register
ATDCTL5  EQU   $0085   ; ATDCTL5 control register
ATDSTAT  EQU   $0086   ; ATDSTAT0 status register

ATDDIEN  EQU   $008D   ; Port AD digital input enable
                       ; (programs Port AD bit positions as digital inputs)
PTADI    EQU   $008F   ; Port AD data input register 
                       ; (for reading digital input bits)
	 	  	     		       	 		
ATDDR0   EQU   $0090   ; result register array (16-bit values)
ATDDR1   EQU   $0092
ATDDR2   EQU   $0094
ATDDR3   EQU   $0096
ATDDR4   EQU   $0098
ATDDR5   EQU   $009A
ATDDR6   EQU   $009C
ATDDR7   EQU   $009E

; ==== Direct Port Pin Access/Control - Port T

PTT      EQU   $0240   ; Port T data register
DDRT     EQU   $0242   ; Port T data direction register

; ==== SCI Register Definitions

SCIBDH   EQU   $00C8   ; SCI0BDH - SCI BAUD RATE CONTROL REGISTER
SCIBDL   EQU   $00C9   ; SCI0BDL - SCI BAUD RATE CONTROL REGISTER
SCICR1   EQU   $00CA   ; SCI0CR1 - SCI CONTROL REGISTER
SCICR2   EQU   $00CB   ; SCI0CR2 - SCI CONTROL REGISTER
SCISR1   EQU   $00CC   ; SCI0SR1 - SCI STATUS REGISTER
SCISR2   EQU   $00CD   ; SCI0SR2 - SCI STATUS REGISTER
SCIDRH   EQU   $00CE   ; SCI0DRH - SCI DATA REGISTER
SCIDRL   EQU   $00CF   ; SCI0DRL - SCI DATA REGISTER
PORTB    EQU   $0001   ; PORTB - DATA REGISTER
DDRB     EQU   $0003   ; PORTB - DATA DIRECTION REGISTER

;***********************************************************************
;
; ASCII character definitions
;

;                         
CR	equ	$D	; RETURN
LF	equ	$A	; LINE FEED
NULL	equ	$0	; NULL                         
DASH	equ	'-'	; DASH (MINUS SIGN)
PERIOD	equ	'.'	; PERIOD

; ======================================================================
;
;  Variable declarations (SRAM)
;  Others may be added if deemed necessary
	 	  	     		       	 		
         		org   	$3800
onesixtieth  	rmb   	1	; half second flag
rticnt   		rmb   	1	; RTICNT (variable)
joy0hor			rmb		1	; Joystick 0 horizontal ATD value  
joy0vert		rmb		1	; Joystick 0 vertical ATD value  
joy1hor			rmb		1	; Joystick 1 horizontal ATD value  
joy1vert		rmb		1	; Joystick 1 vertical ATD value  

;***********************************************************************
;  BOOT-UP ENTRY POINT (Flash at location $8000 out of reset)
;***********************************************************************
	 	  	     		       	 		
         org   $8000
Entry
         sei                    ; Disable interrupts
         movb    #$00,INITRG    ; set registers to $0000
         movb    #$39,INITRM    ; map RAM ($3800 - $3FFF)
         lds     #$3FCE         ; initialize stack pointer
;
; Set the PLL speed (bus clock = 24 MHz)
;
         bclr    CLKSEL,$80     ; disengage PLL from system
         bset    PLLCTL,$40     ; turn on PLL
         movb    #$2,SYNR       ; set PLL multiplier
         movb    #$0,REFDV      ; set PLL divider
         nop
         nop
plp      brclr   CRGFLG,$08,plp ; while (!(crg.crgflg.bit.lock==1))
         bset    CLKSEL,$80     ; engage PLL 
	 	  	     		       	 		
;                         
; Disable watchdog timer (COPCTL register)
;
         movb    #$40,COPCTL    ; COP off; RTI and COP stopped in BDM-mode

;
; Initialize asynchronous serial port (SCI) for 9600 baud, no interrupts
;
         movb    #$00,SCIBDH    ; set baud rate to 9600
         movb    #$9C,SCIBDL    ; 24,000,000 / 16 / 156 = 9600 (approx)
         movb    #$00,SCICR1    ; $9C = 156
         movb    #$0C,SCICR2    ; initialize SCI for program-driven operation

         movb    #$10,DDRB      ; set PB4 for output mode
         movb    #$10,PORTB     ; assert DTR pin on COM port


;***********************************************************************
;  START OF CODE FOR EXPERIMENT
;***********************************************************************
;                         
;  Flag and variable initialization (others may be added)
;
         clr    onesixtieth
         clr    rticnt

;
;  Add additional port pin initializations here
;                         

		movb	#$FF, DDRT ;Output LED's
    	clr PTT

	 	  	     		       	 		
;
; Initialize the ATD to sample a D.C. input voltage (range: 0 to 5V)
; on Channels 0, 1, 2, and 3 for the joysticks (unsigned, 8-bit).  The ATD should be operated in 
; a program-driven (i.e., non-interrupt driven) fashion, sampling across 
; multiple channels with normal flag clear mode using nominal sample time 
; and clock prescaler values.
;                         
; Note: Vrh (the ATD reference high voltage) is connected to 5 VDC and
;       Vrl (the reference low voltage) is connected to GND on your kit.
;
	 	  	     		       	 		
atd_ini	movb	#$80, ATDCTL2

		movb 	#$08, ATDCTL3

		movb	#$85, ATDCTL4


;
;  Add RTI/interrupt initializations here
;                         

		movb	#$4B,	RTICTL
		bset	CRGINT, $80
		cli


;***********************************************************************
;
; Main program loop 
;
;
; Checks to see if 1/60th of a second has passed, if so, sample the joysticks
	 	  	     		       	 		
main        
	 	  	     		       	 		
; < place your code for main here >
	 	  	     		       	 		
sixtieth	brclr	onesixtieth, #$FF, endofit
			clr onesixtieth
			jsr	getjoy
	 	  	     		       	 		

endofit
			jmp    main	;                          jump to main
	 	  	     		       	 		

;***********************************************************************
;
; ATD device driver routine: getjoy
;
; This routine will initiate an ATD conversion on input Channels 0, 1, 2, 3
; (by writing to register ATDCTL5), wait for the conversion of both to
; complete (by monitoring the SCF in register ATDSTAT), read the corresponding
; ATD result registers once the conversion completes, and store the
; converted analog sample for Channel 0 in joy0hor,
; converted analog sample for Channel 1 in joy0vert,
; converted analog sample for Channel 2 in joy1hor,
; converted analog sample for Channel 3 in joy1vert.
;
; The joysticks will be sampled 60 times a second based on the vertical sync
; pulse triggering the irq.  The atd values will be sampled at 8bits.
;

getjoy	movb	#$01, ATDCTL5
await	brclr	ATDSTAT,$80,await
		movb	ATDDR0, joy0hor

		movb	#$02, ATDCTL5
await1	brclr	ATDSTAT,$80,await1
		movb	ATDDR0, joy0vert

		movb	#$04, ATDCTL5
await2	brclr	ATDSTAT,$80,await2
		movb	ATDDR0, joy1hor

		movb	#$08, ATDCTL5
await3	brclr	ATDSTAT,$80,await3
		movb	ATDDR0, joy1vert
    rts


;***********************************************************************
;                         
; RTI interrupt service routine: rti_isr
;
; This routine keeps track of when 1/60 seconds worth of
; RTI interrupts has passed and sets the "sixtieth" flag
;
;                         
	 	  	     		       	 		
; < place your code for the RTI interrupt service routine here >
	 	  	     		       	 		
rti_isr
		bset	CRGFLG, $80


		;increment counter
		inc		rticnt
		ldaa	rticnt
		cmpa	#$62
		blt		notonesixtieth
			bset	onesixtieth ,	$01
			clr		rticnt

notonesixtieth

        rti ;                         return from interrupt


;***********************************************************************
; Character I/O Library Routines for 9S12C32
;***********************************************************************

rxdrf    equ   $20    ; receive buffer full mask pattern
txdre    equ   $80    ; transmit buffer empty mask pattern

;***********************************************************************
; Name:         inchar
; Description:  inputs ASCII character from SCI serial port
;                  and returns it in the A register
; Returns:      ASCII character in A register
; Modifies:     A register
;***********************************************************************

inchar  brclr  SCISR1,rxdrf,inchar
        ldaa   SCIDRL ; return ASCII character in A register
        rts

;***********************************************************************
; Name:         outchar
; Description:  outputs ASCII character passed in the A register
;                  to the SCI serial port
;***********************************************************************

outchar brclr  SCISR1,txdre,outchar
        staa   SCIDRL ; output ASCII character to SCI
        rts

;***********************************************************************
; pmsg -- Print string following call to routine.  Note that subroutine
;         return address points to string, and is adjusted to point to
;         next valid instruction after call as string is printed.
;***********************************************************************
	 	  	     		       	 		

pmsg    pulx            ; Get pointer to string (return addr).
        psha
ploop   ldaa    1,x+    ; Get next character of string.
        beq     pexit   ; Exit if ASCII null encountered.
        jsr     outchar ; Print character on terminal screen.
        bra     ploop   ; Process next string character.
pexit   pula
        pshx            ; Place corrected return address on stack.
        rts             ; Exit routine.

;
;***********************************************************************
;	 	  	     		       	 		
; Define 'where you want to go today' (reset and interrupt vectors)
;
; If get a "bad" interrupt, just return from it

BadInt    rti

; ------------------ VECTOR TABLE --------------------

    org    $FF8A
    fdb    BadInt    ;$FF8A: VREG LVI
    fdb    BadInt    ;$FF8C: PWM emergency shutdown
    fdb    BadInt    ;$FF8E: PortP
    fdb    BadInt    ;$FF90: Reserved
    fdb    BadInt    ;$FF92: Reserved
    fdb    BadInt    ;$FF94: Reserved
    fdb    BadInt    ;$FF96: Reserved
    fdb    BadInt    ;$FF98: Reserved
    fdb    BadInt    ;$FF9A: Reserved
    fdb    BadInt    ;$FF9C: Reserved
    fdb    BadInt    ;$FF9E: Reserved
    fdb    BadInt    ;$FFA0: Reserved
    fdb    BadInt    ;$FFA2: Reserved
    fdb    BadInt    ;$FFA4: Reserved
    fdb    BadInt    ;$FFA6: Reserved
    fdb    BadInt    ;$FFA8: Reserved
    fdb    BadInt    ;$FFAA: Reserved
    fdb    BadInt    ;$FFAC: Reserved
    fdb    BadInt    ;$FFAE: Reserved
    fdb    BadInt    ;$FFB0: CAN transmit
    fdb    BadInt    ;$FFB2: CAN receive
    fdb    BadInt    ;$FFB4: CAN errors
    fdb    BadInt    ;$FFB6: CAN wake-up
    fdb    BadInt    ;$FFB8: FLASH
    fdb    BadInt    ;$FFBA: Reserved
    fdb    BadInt    ;$FFBC: Reserved
    fdb    BadInt    ;$FFBE: Reserved
    fdb    BadInt    ;$FFC0: Reserved
    fdb    BadInt    ;$FFC2: Reserved
    fdb    BadInt    ;$FFC4: CRG self-clock-mode
    fdb    BadInt    ;$FFC6: CRG PLL Lock
    fdb    BadInt    ;$FFC8: Reserved
    fdb    BadInt    ;$FFCA: Reserved
    fdb    BadInt    ;$FFCC: Reserved
    fdb    BadInt    ;$FFCE: PORTJ
    fdb    BadInt    ;$FFD0: Reserved
    fdb    BadInt    ;$FFD2: ATD
    fdb    BadInt    ;$FFD4: Reserved
    fdb    BadInt    ;$FFD6: SCI Serial System
    fdb    BadInt    ;$FFD8: SPI Serial Transfer Complete
    fdb    BadInt    ;$FFDA: Pulse Accumulator Input Edge
    fdb    BadInt    ;$FFDC: Pulse Accumulator Overflow
    fdb    BadInt    ;$FFDE: Timer Overflow
    fdb    BadInt    ;$FFE0: Standard Timer Channel 7
    fdb    BadInt    ;$FFE2: Standard Timer Channel 6
    fdb    BadInt    ;$FFE4: Standard Timer Channel 5
    fdb    BadInt    ;$FFE6: Standard Timer Channel 4
    fdb    BadInt    ;$FFE8: Standard Timer Channel 3
    fdb    BadInt    ;$FFEA: Standard Timer Channel 2
    fdb    BadInt    ;$FFEC: Standard Timer Channel 1
    fdb    BadInt    ;$FFEE: Standard Timer Channel 0
    fdb    rti_isr   ;$FFF0: Real Time Interrupt (RTI)
    fdb    BadInt    ;$FFF2: IRQ (External Pin or Parallel I/O) (IRQ)
    fdb    BadInt    ;$FFF4: XIRQ (Pseudo Non-Maskable Interrupt) (XIRQ)
    fdb    BadInt    ;$FFF6: Software Interrupt (SWI)
    fdb    BadInt    ;$FFF8: Illegal Opcode Trap
    fdb    Entry     ;$FFFA: COP Failure (Reset)
    fdb    BadInt    ;$FFFC: Clock Monitor Fail (Reset)
    fdb    Entry     ;$FFFE: /RESET
    end





