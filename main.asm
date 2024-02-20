//encabezdo

.include "M328PDEF.inc"
.cseg
.org 0x00
	JMP MAIN
.org 0x0006
	JMP ISR_PCINT0
.org 0x0020
	JMP ISR_TIMER0_OVF

MAIN:

// STACK


	LDI R16, LOW(RAMEND)
	OUT SPL, R16
	LDI R17, HIGH(RAMEND)
	OUT SPH, R17
	LDI R18, HIGH(RAMEND)
	OUT SPH, R18
	LDI R19, HIGH(RAMEND)
	OUT SPH, R19
	LDI R20, HIGH(RAMEND)
	OUT SPH, R20
	LDI R21, HIGH(RAMEND)
	OUT SPH, R21
;******************************************************************************
; TABLA
;******************************************************************************

	TABLA7SEG: .DB 0x00, 0x3F, 0x05, 0x5B, 0x4F, 0x65, 0x6E, 0x7E, 0x07, 0x7F, 0x6F, 0x3F, 0X05, 0x5B, 0x4F, 0x65, 0x6E, 0x7E
	;Tabla para el 7 segmentos

// CONFIGURACIÓN

Setup:
	LDI R16, (1 << CLKPCE)
	STS CLKPR, R16			;Habilita prescaler
	LDI R16, 0b0000_0011	;2MHz
	STS CLKPR, R16	

	LDI R16, (1 << CS02) | (1 <<CS00)
	OUT TCCR0B, R16			;Configuración del timer0

	LDI R19, 230			;Valor de desbordamiento para contar 10ms
	OUT TCNT0, R19	

	LDI R16, (1 <<TOIE0)
	STS TIMSK0, R16

	LDI R16, 0xFF			;PORTD Salidas (7Segmentos)
	OUT DDRD, R16
	
	LDI R21, 1

	LDI R20, 0

	LDI R16, (1 << PC3)|(1 << PC2)|(1 << PC1)|(1 << PC0)
	OUT DDRC, R16			;PORTC PC3, PC2, PC1 y PC0 Entradas (Contador manual)

	LDI R16, 0
	OUT PORTC, R16			;Valores iniciales PORTC

	SBI PORTB, PB0
	SBI PORTB, PB1

	LDI R16, 0b_0000_1100
	OUT DDRB, R16



	LDI R16, (1 << PCINT1)|(1 << PCINT0)
	STS PCMSK0, R16

	LDI R16, (1 << PCIE0)
	STS PCICR, R16

	SEI			;Interrupciones

	LDI R17, 0
	
	
	MOV R16, R21	;7 segmentos unidad
	LDI ZH, HIGH(TABLA7SEG<<1)
	LDI ZL, LOW(TABLA7SEG<<1)
	ADD ZL, R16
	LPM R16, Z
	OUT PORTD, R16

	LDI R24, 11		;7 segmentos decena

	MOV R25, R24
	LDI ZH, HIGH(TABLA7SEG<<1)
	LDI ZL, LOW(TABLA7SEG<<1)
	ADD ZL, R25
	LPM R25, Z
	OUT PORTD, R25


Loop:
	CALL DELAY1MS	;Llamar funcion para contar 10ms
	SBI PORTB, PB2	;Pin para activar unidad en 7 seg
	OUT PORTD, R16	
	CBI PORTB, PB2
	CALL DELAY1MS	;Llamar funcion para contar 10ms
	SBI PORTB, PB3	;Pin para activar decena en 7seg
	OUT PORTD, R25
	CBI PORTB, PB3

	CPI R20, 100	;Contara 100 veces 10 ms para que sea 1 seg
	BRNE Loop
	CLR R20			;Cuando pase 1 segundo
	INC R21			;Subimos la unidad
	CPI R21, 11		;Limite superior de la unidad
	BREQ LIMSUP		;Regresamos el valor de la unidad a 0 

	MOV R16, R21	;Lo desplegamos en el 7 segmentos
	LDI ZH, HIGH(TABLA7SEG<<1)
	LDI ZL, LOW(TABLA7SEG<<1)
	ADD ZL, R16
	LPM R16, Z
	RJMP Loop

DELAY1MS:			;Delay de 10ms
	LDI R26, 0
	OUT PORTD, R26
	DELAAY:
		INC R26
		CPI R26,250
		BRNE DELAAY
		RETI

LIMSUP:			;Limite superior unidad
	LDI R21, 1	;Regresamos el valor de unidad a 0
	MOV R16, R21
	LDI ZH, HIGH(TABLA7SEG<<1)
	LDI ZL, LOW(TABLA7SEG<<1)
	ADD ZL, R16
	LPM R16, Z
	
	INC R24			;Subimos uno la decena
	CPI R24, 17		;Limite superior decena (no debe ser 6)
	BREQ LIMSUP2
	MOV R25, R24	;Lo desplegamos en el 7 seg
	LDI ZH, HIGH(TABLA7SEG<<1)
	LDI ZL, LOW(TABLA7SEG<<1)
	ADD ZL, R25
	LPM R25, Z

	RJMP Loop

LIMSUP2:			;Regresamos al valor inicial para la decena
	LDI R24, 11
	RJMP MAIN


ISR_TIMER0_OVF:		;Timer0 contando a 10ms
	
	PUSH R16
	IN R16, SREG
	PUSH R16

	LDI R19, 230
	OUT TCNT0, R19
	SBI TIFR0, TOV0
	INC R20

	POP R16
	OUT SREG, R16
	POP R16
	RETI

ISR_PCINT0:			;Funcion de interrupcion para portb
	
	PUSH R16
	IN R16, SREG
	PUSH R16

	IN R18, PINB
	LDI R16, 0
	CALL ANTIRREBOTE	;Esperamos 100 ms
	IN R16, PINB
	CP R18, R16			;Si tiene el mismo estado despues de 10ms, regresamos
	BRNE Salir
	SBRS R18, PB0		;Si no, sumaremos si PB0 esta presionado
	RJMP SUMA

	SBRS R18, PB1		;Restaremos si PB1 esta presionado
	RJMP RESTA

	CPI R22, 1			;Flag de suma
	BREQ SUMATORIA

	CPI R23, 1			;Flag de resta
	BREQ RESTATORIA

	RJMP Salir
	
SUMA:
	LDI R22, 1		;Flag para suma
	RJMP Salir

RESTA:
	LDI R23, 1		;Flag para resta
	RJMP Salir

SUMATORIA:
	LDI R22, 0		;Regresamos la flag de suma a 0
	INC R17			;Sumamos 1 en el contador
	CPI R17, 16		;Limite superior 15
	BRNE Salir
	LDI R17, 15
	RJMP Salir

RESTATORIA:
	LDI R23, 0		;Regresamos flag de resta a 0
	DEC R17
	CPI R17, -1		;Limite inferior 0
	BRNE Salir
	LDI R17, 0
	RJMP Salir


Salir:
	OUT PORTC, R17	;Desplegamos el valor del contador en portc.
	CBI PINB, PB0
	SBI PCIFR, PCIF0
	POP R16
	OUT SREG, R16
	POP R16
	RETI

ANTIRREBOTE:
	
	LDI R19, 230
	OUT TCNT0, R19
	SBI TIFR0, TOV0
	INC R16
	CPI R16, 10
	BRNE ANTIRREBOTE
	RETI
