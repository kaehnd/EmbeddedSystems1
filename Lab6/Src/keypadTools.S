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
		.byte '1', '2', '3', 'A', '4', '5', '6', 'B', '7', '8', '9', 'C', '*', '0', '#', 'D'

.section .text

	.equ RCC_BASE,    0x40023800
	.equ RCC_AHB1ENR, 0x30
    .equ RCC_GPIOCEN, 1<<2

    .equ GPIOC_BASE, 0x40020800
    .equ GPIO_MODER, 0x00
    .equ GPIO_IDR, 0x10
    .equ GPIO_ODR, 0x14
    .equ GPIO_BSRR, 0x18
    .equ GPIO_PUPDR, 0x0C


    .equ COL_IN_ROW_OUT, 0b0101010100000000
    .equ COL_OUT_ROW_IN, 0b0000000001010101

    .equ PULL_UP_PINS, 0b0101010101010101

	#BSRR Commands
	.equ DRIVE_COLS, 0b1111<<(16)
	.equ DRIVE_ROWS, 0b1111<<(16+4)

	.global KeyInit
	.global KeyGetkeyNoblock
	.global KeyGetkey
	.global KeyGetchar

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

#Gets number for current key pressed
#No Args
#RETURN: r0: 0, no key pressed, 1-16 key press
KeyGetkeyNoblock:

		push {r1-r4, r6-r7, lr}

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

		#Read rows IDR
		ldrb r2, [r7, GPIO_IDR]
		#Store row value in r6
		ubfx r3, r2, #4, #4

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
		push {r1, r4, lr}

		bl KeyGetkey

		cmp r0, #0
		beq ret

		sub r1, r0, #1

		ldr r4, =keyPadkeys
		ldrb r0, [r4, r1]

	ret:pop {r1, r4, pc}
