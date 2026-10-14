    GLOBAL __main
    AREA main, CODE, READONLY
    EXPORT __main
    EXPORT __use_two_region_memory
__use_two_region_memory EQU 0

RCC_AHB2ENR EQU 0x4002104C
GPIOA_MODER EQU 0x48000000
GPIOA_ODR EQU 0x48000014
ADC2_ISR EQU 0x50000100
ADC2_CR EQU 0x50000108
ADC2_CFGR EQU 0x5000010C
ADC2_SQR1 EQU 0x50000130
ADC2_DR EQU 0x50000140
ADC12_CCR EQU 0x50000308

	

__main
	bl adc_config
	bl led_config
loop
	bl adc_read
	bl led_write
	b  loop

adc_config
	push {lr}
	;Senales de reloj para ADC y GPIOA
	ldr r0, =RCC_AHB2ENR
	ldr r1,[r0]
	orr r1,#(1<<0) ; Habilitar reloj GPIOA
	orr r1,#(1<<13) ; Habilitar reloj ADC
	str r1,[r0]

	;PA1 como entrada analógica
	ldr r0, =GPIOA_MODER
	ldr r1,[r0]
	orr r1,#(3<<2) ;PA1 como entrada analógica
	str r1,[r0]

	;Overrun y resolucion de 10 bits
	ldr r0, =ADC2_CFGR
	ldr r1,[r0]
	orr r1,#(1<<12) 
	orr r1,#(1<<3) ; RES=01
	str r1,[r0]

	; Conversion en el canal 2
	ldr r0, =ADC2_SQR1
	ldr r1,[r0]
	orr r1,#(2<<6) ; canal 2, L=0, SQ1=2
	str r1,[r0]

	; reloj del ADC = HCLK/4
	ldr r0,=ADC12_CCR
	ldr r1,[r0]
	orr r1,#(3<<16) ; CKMODE=11
	str r1,[r0]

	; salir del deep power mode
	ldr r0,=ADC2_CR
	ldr r1,[r0]
	bic r1,#(1<<29) ; DEEPWD =0
	str r1,[r0]

	; habilitar el regulador de voltaje
	ldr r1,[r0]
	orr r1,#(1<<28) ; ADVREGEN=1
	str r1,[r0]

	;esperar a que el regulador se estabilice
	ldr r2,=2000
adc_delay
	subs r2,#1
	bne adc_delay

	; habilitar el ADC
	ldr r1,[r0]
	orr r1,#(1<<0) ; ADEN=1
	str r1,[r0]

	;esperar a que el ADC este listo
	ldr r0,=ADC2_ISR
adc_wait_ready
	ldr r1,[r0]
	tst r1,#(1<<0) ; ADRDY=1?
	beq adc_wait_ready

	pop {pc}

led_config
	push {lr}
	ldr r0,=GPIOA_MODER
	ldr r1,[r0]
	bic r1,#(3<<4) ; limpiar PA2
	orr r1,#(1<<4) ; PA2 como salida
	bic r1,#(3<<0) ; limpiar PA0
	orr r1,#(1<<0) ; PA0 como salida
	bic r1,#(3<<8) ; limpiar PA4
	orr r1,#(1<<8) ; PA4 como salida
	bic r1,#(3<<14) ; limpiar PA7
	orr r1,#(1<<14) ; PA7 como salida
	str r1,[r0]
	
	pop {pc}

adc_read
	push {lr}
	ldr r1,=ADC2_CR
	ldr r2,[r1]
	orr r2,#(1<<2) ; ADSTART=1
	str r2,[r1]

	;esperar a que la conversion termine
	ldr r1,=ADC2_ISR
adc_wait_eoc
	ldr r2,[r1]
	tst r2,#(1<<2) ; EOC=1?
	beq adc_wait_eoc
	
	;leer el resultado
	ldr r1, =ADC2_DR
	ldr r0,[r1] ;se devuelve el valor de la conversion en r0
	pop {pc}
	
led_write
	push {lr}
	mov r2,#0 ; r2 = LEDs a encender empieza en 0

	ldr r3,=205
	cmp r0,r3 ; comparar el valor de la conversion con 1/5 del maximo (1023)
	blo led_output ; menos de 1/5 ningun LED
	orr r2,#(1<<0) ; LED4 (PA0)

	ldr r3, =409
	cmp r0,r3
	blo led_output ; menos de 2/5 
	orr r2,#(1<<4) ; LED3 (PA4)

	ldr r3, =614
	cmp r0,r3
	blo led_output ; menos de 3/5
	orr r2,#(1<<7) ; LED2 (PA7)

	ldr r3, =818
	cmp r0,r3
	blo led_output ; menos de 4/5
	orr r2,#(1<<2) ; LED1 (PA2)
led_output
	ldr r1,=GPIOA_ODR
	ldr r3,[r1]
	bic r3,#0x95 ; limpiar bits de los LEDs
	orr r3,r2 ; encender los LEDs correspondientes
	str r3,[r1]
	pop {pc}


	end