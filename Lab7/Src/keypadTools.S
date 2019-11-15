#keypadTools.S
#Daniel Kaehn
#CE2801
#Lab5
#Description: API for keypad

.syntax unified
.cpu cortex-m4
.thumb

.section .rodata

	keyPadkeys:
		.byte 0x1, 0x2, 0x3, 0xA, 0x4, 0x5, 0x6, 0xB, 0x7, 0x8, 0x9, 0xC, 0xF, 0x0, 0xE, 0xD

.section .text

	.equ RCC_BASE,    0x40023800
	.equ RCC_AHB1ENR, 0x30
    .equ RCC_GPIOCEN, 1<<2

	.equ RCC_APB2ENR, 0x44
	.equ RCC_AHB1ENR, 0x30
	.equ RCC_GPIOBEN, 1<<1


    .equ GPIOC_BASE, 0x40020800
    .equ GPIO_MODER, 0x00
    .equ GPIO_IDR, 0x10
    .equ GPIO_ODR, 0x14
    .equ GPIO_BSRR, 0x18
    .equ GPIO_PUPDR, 0x0C


    .equ COL_IN_ROW_OUT, 0b0101010100000000
    .equ COL_OUT_ROW_IN, 0b0000000001010101

    .equ PULL_UP_PINS, 0b0101010101010101



	#External interrupt values
	.equ EXTI_BASE, 0x40013C00
	.equ EXTI_PR, 0x14
	.equ EXTI_IMR, 0x00
	.equ EXTI_FTSR, 0x0C

	#Sytem config values
	.equ SYSCFG_BASE, 0x40013800
	.equ SYSCFG_EXTICR2, 0x0C

	#NVIC values
	.equ NVIC_BASE, 0xE000E100
	.equ NVIC_ISER0, 0x000
	.equ NVIC_ISER2, 0x008
	.equ NVIC_ICER0, 0x080

	.equ KEYPAD_INT_MOD, 0x00800400

	#BSRR Commands
	.equ DRIVE_COLS, 0b1111<<(16)
	.equ DRIVE_ROWS, 0b1111<<(16+4)

	.global KeyInit
	.global KeyGetkeyNoblock
	.global KeyGetkey
	.global KeyGetchar
	.global KeyPrepRow
	.global KeyGetColFromRow
	.global KeyGetCharFromKey

	.global KeyIntInit
	.global KeyStartInt
	.global KeyStopInt

KeyInit:

		push {r1-r2, r7}
		#Turn on port A in RCC
		ldr r7, =RCC_BASE
	    ldr r1, [r7, RCC_AHB1ENR]
	    orr r1, RCC_GPIOCEN
	    str r1, [r7, RCC_AHB1ENR]

	    ldr r7, =GPIOC_BASE

	    #Set pull up
	    ldr r1, [r7, GPIO_PUPDR]
	    ldr r2, =PULL_UP_PINS
	    bfi r1, r2, #0, #16
	    str r1, [r7, GPIO_PUPDR]

	    pop {r1-r2, r7}

	    bx lr



KeyIntInit:
		push {r4-r5}
		ldr r4, =RCC_BASE
		ldr r5, [r4, #RCC_APB2ENR]
		orr r5, r5, #(1<<14)
		str r5, [r4, RCC_APB2ENR]

		#Set mux for pins 4-7 to PC
		ldr r4, =SYSCFG_BASE
		mov r5, 0x2222
		str r5, [r4, #SYSCFG_EXTICR2]

		#Unmask EXTI4-EXTI7 in EXTI
		ldr r4, =EXTI_BASE

		ldr r5, [r4, #EXTI_IMR]
		orr r5, #(0b1111<<4)
		str r5, [r4, #EXTI_IMR]

		pop {r4-r5}
		bx lr



#Handles key pressed in row 1
.global EXTI4_IRQHandler
.thumb_func
EXTI4_IRQHandler:

			push {lr}

			#record time since timer was started
			bl TakeTime

			#Clear pending interrupt
			ldr r0, =EXTI_BASE
			mov r1, #1<<4
			str r1, [r0, #EXTI_PR]

			#Determine which pin changed
			mov r0, #0b1110
			bl getKey

			pop {lr}

			bx lr

#Handles key pressed in rows 2-4
.global EXTI9_5_IRQHandler
.thumb_func
EXTI9_5_IRQHandler:

			push {lr}

			#record time since timer was started
			bl TakeTime

			#obtain which pin changed
			ldr r0, =EXTI_BASE
			ldr r1, [r0, #EXTI_PR]
			ubfx r2, r1, #4, #4

			#Clear pending interrrupt
			mov r1, #111<<5
			str r1, [r0, #EXTI_PR]

			#move key to r0
			mov r3, #0b1111
			eor r0, r3, r2
			bl getKey

			pop {lr}
			bx lr


#Helper function turns on Keypad interrupt
KeyStartInt:
			push {r4-r5}
			ldr r4, =EXTI_BASE
			#Set for falling edge
			ldr r5, [r4, #EXTI_FTSR]
			orr r5, #(0b1111<<4)
			str r5, [r4, #EXTI_FTSR]

			ldr r4, =NVIC_BASE
			ldr r5, =KEYPAD_INT_MOD
			str r5, [r4, #NVIC_ISER0]

			pop {r4-r5}
			bx lr





#Helper function turns off Keypad interrupt
KeyStopInt:

			push {r4-r5}
			ldr r4, =EXTI_BASE
			#Set for falling edge
			ldr r5, [r4, #EXTI_FTSR]
			bic r5, #(0b1111<<4)
			str r5, [r4, #EXTI_FTSR]

			ldr r4, =NVIC_BASE
			ldr r5, =KEYPAD_INT_MOD
			str r5, [r4, #NVIC_ICER0]

			pop {r4-r5}
			bx lr


#helper function for interrupts,
#takes r0, row code, stores at KeyPressed
getKey:
			push {r0-r1, lr}

			bl KeyGetColFromRow
			bl KeyGetCharFromKey

			ldr r1, =KeyPressed
			strb r0, [r1]

			pop {r0-r1, pc}

#Gets number for current key pressed
#No Args
#RETURN: r0: 0, no key pressed, 1-16 key press
KeyGetkeyNoblock:

		push {r2, r7, lr}

		ldr r7, =GPIOC_BASE
		bl KeyPrepRow



		#Read rows IDR
		ldrb r2, [r7, GPIO_IDR]
		#Store row value in r6
		ubfx r0, r2, #4, #4

		bl KeyGetColFromRow

		pop {r2, r7, pc}

#Waits for key press from keypad and returns value 1-16
#Blocks
#No Args
#RETURNS: r0, value 1-16 for key press
KeyGetkey:

			push {r1, lr}

		1:	bl KeyGetkeyNoblock
			cmp r0, #0
			beq 1b

			mov r1, r0

		2:	bl KeyGetkeyNoblock
			cmp r0, #0
			bne 2b

			mov r0, r1
			pop {r1, pc}



#Waits for key press from keypad and returns ASCII code
#Blocks
#No Args
#RETURNS: r0, ASCII code for char pressed
KeyGetchar:
			push {lr}

			bl KeyGetkey

			cmp r0, #0
			beq ret

			bl KeyGetCharFromKey

			ret:pop {pc}







#Takes r0 1-16 key pressed
KeyGetCharFromKey:
		push {r1-r2}

		sub r1, r0, #1

		ldr r2, =keyPadkeys
		ldrb r0, [r2, r1]
		pop {r1-r2}

		bx lr


#Drives cols and preps row for input
KeyPrepRow:
		push {r0-r2, r7, lr}
		#Set cols out and rows in
	    ldr r7, =GPIOC_BASE
	    ldr r1, [r7, GPIO_MODER]
	    ldr r2, =COL_OUT_ROW_IN
	    bfi r1, r2, #0, #16
	    str r1, [r7, GPIO_MODER]

		#Set cols to "0000"
		ldr r1, =DRIVE_COLS
		str r1, [r7, GPIO_BSRR]

		mov r0, #1
		bl DelayUs

		pop {r0-r2, r7, pc}

#Takes r0, row input and drives rows to find col and 1-16 val
KeyGetColFromRow:
		push {r1-r4, r6-r7, lr}

		ldr r7, =GPIOC_BASE

		mov r3, r0

		#End if all '1's
		cmp r3, #0b1111
		it eq
		moveq r0, #0
		beq r

		#Copy row IDR to ODR
		lsl r1, r3, #4
		strb r1, [r7, GPIO_ODR]

		#Set rows output and cols input

		ldr r1, [r7, GPIO_MODER]
	    ldr r2, =COL_IN_ROW_OUT
	    bfi r1, r2, #0, #16
	    str r1, [r7, GPIO_MODER]

	    #Wait for memory
		mov r0, #1
		bl DelayUs

	    ldrb r1, [r7, GPIO_IDR]
	    #Store column value in r4
	    ubfx r4, r1, #0, #4

	    #row r3 col r4

		#find row
		mov r0, #0
	1:	add r0, #1
		ubfx r1, r3, #0, #1
		lsr r3, r3, #1
		cmp r1, #0
		bne 1b

		sub r0, #1
		#Store val in r1: should be 0, 4, 8, 12
		lsl r3, r0, #2

		#Find col
		mov r0, #0
	2:	add r0, #1
		ubfx r1, r4, #0, #1
		lsr r4, r4, #1
		cmp r1, #0
		bne 2b

		#Value in r0 should be 1, 2, 3, 4

		add r0, r3


	r:	pop {r1-r4, r6-r7, pc}
