#main.S
#Daniel Kaehn
#CE2801
#Lab8
#Description: Implements temperature datalogger making use of
#primarily adcTools.S API and keypadTools.S
#Uses interrupts to drive timing and ADC EOC
#Uses timer to drive ADC

.syntax unified
.cpu cortex-m4
.thumb

.section .text

		.global main

			.equ RCC_BASE, 0x40023800
			.equ RCC_APB1ENR, 0x40
			.equ RCC_APB2ENR, 0x44
			.equ RCC_AHB1ENR, 0x30
			.equ RCC_GPIOBEN, 1<<1
			.equ RCC_TIM2EN, 1<<0

			.equ GPIOB_BASE, 0x40020400
			.equ GPIO_MODER, 0x00
			.equ GPIO_ODR, 0x14

			.equ ADC1_BASE, 0x40012000

			.equ ADC_SR, 0x00
			.equ ADC_CR1, 0x04
			.equ ADC_CR2, 0x08
			.equ ADC_SQR3, 0x34
			.equ ADC_DR, 0x4C

			#Flag for ADC conversion used for cont mode
			.equ ADC_EOCSET, 0b1<<1

main:
			#initialize peripherals
			bl PiezoInit
			bl LcdInit
			bl KeyInit

			#Temp sensor init
			ldr r4, =RCC_BASE
			ldr r3, [r4, #RCC_AHB1ENR]
			orr r3, #RCC_GPIOBEN
			str r3, [r4, #RCC_AHB1ENR]

			ldr r4, =GPIOB_BASE
			ldr r3, [r4, #GPIO_MODER]
			orr r3, #0b11
			str r3, [r4, #GPIO_MODER]

			ldr r0, =intro
			bl LcdPrintString
			bl DelayIntS

			bl LcdClear

			bl ADC1Init
			bl KeyIntInit

			bl sRateChange
			bl bSizeChange

			mov r0, #1
			mov r1, #0
			bl LcdSetPosition

			ldr r0, =bufferingS
			bl LcdPrintString
			mov r0, #0
			bl LcdPrintNum

#Main program loop, checks for key press and checks for buffered temps
#Prints and/or stores buffered temps in circular array of specified size
mnloop:		bl checkKeyPress

			#Check for cont mode
			cmp r0, #1
			beq cont

			#Check if temp var is modified
			ldr r4, =PrevTemp
			#Store current temp in r2
			ldr r2, [r4]
			cmp r2, #0
			beq mnloop

			#Clear temp var
			mov r1, #0
			str r1, [r4]

			bl LcdClear

			mov r0, #1
			mov r1, #0
			bl LcdSetPosition

			ldr r4, =buffering
			ldrb r7, [r4]
			cmp r7, 0x01

			beq 1f

			#iif not buffering
			ldr r0, =notBufferingS
			bl LcdPrintString

			b 2f

		1:	ldr r3, =buffer
			ldr r6, =bufferPos
			ldr r7, =bufferSize

			ldr r0, =bufOverflow
			ldrb r1, [r0]
			cbnz r1, 3f

			ldr r0, =bufferingS
			bl LcdPrintString

			ldrb r0, [r6]
			add r0, #1
			bl LcdPrintNum
			b 4f

		3:	ldr r0, =bufferFull
			bl LcdPrintString

		4:	ldrb r0, [r6]
			ldrb r1, [r7]

			mov r5, #0x01

			#Check if buffer position is at the size
			cmp r0, r1
			it eq
			moveq r0, #0

			sub r1, #1
			cmp r0, r1
			itt eq
			ldreq r7, =bufOverflow
			strbeq r5, [r7]

			add r4, r0, #1
			strb r4, [r6]

			#Mul offset by 2 for hword
			add r0, r0

			#Store in buffer
			strh r2, [r3, r0]

			#Print currently buffering value if enabled
		2:	ldr r4, =dispBuffer
			ldrb r3, [r4]
			cmp r3, #0
			beq mnloop

			bl LcdHome
			mov r0, r2
			bl printTemp

			b mnloop

#loop for continuous mode
#Continuous mode does not log to the buffer
#Values are printed to the lcd as fast as possible
cont:		bl checkKeyPress

			cmp r0, #1
			beq mnloop

			mov r0, #10
			bl DelayMs

			ldr r1, =ADC1_BASE
			ldr r2, [r1, #ADC_SR]
			ands r2, #ADC_EOCSET
			beq cont

			ldr r2, [r1, #ADC_DR]

			mov r0, #0
			str r0, [r1, #ADC_SR]

			mov r0, #0
			mov r1, #0
			bl LcdSetPosition

			mov r0, r2

			bl printTemp
			b cont

#Prints temperature to LCD taking into account
#currently selected unit
printTemp:
			push {r0-r3, lr}

			ldr r3, =TempCorF
			ldrb r2, [r3]
			cmp r2, #1
			beq 1f

			#celsius
			bl TempVToC
			bl LcdPrintNumDec
			mov r0, #0xDF
			bl LcdPrintChar
			mov r0, 'C'
			bl LcdPrintChar

			b 2f

			#farenheight
	1:		bl TempVToF
			bl LcdPrintNumDec
			mov r0, #0xDF
			bl LcdPrintChar
			mov r0, 'F'
			bl LcdPrintChar

	2:		pop {r0-r3, pc}

#returns r0 state to move to
checkKeyPress:
			push {r2-r4, lr}

			ldr r4, =KeyPressed
			ldrb r3, [r4]

			mov r0, #0

			#CLR pending byte
			mov r2, #0
			strb r2, [r4]

			bl KeyPrepRow

			#Change temp unit
			cmp r3, #'D'
			bne 1f
			bl changeTemp
			b 2f

			#Toggle cont mode
		1:	cmp r3, #'C'
			bne 1f
			bl ToggleCont
			mov r0, #1

		1:	cmp r3, #'#'
			bne 1f
			bl sRateChange

		1:	cmp r3, #'B'
			bne 1f
			bl bSizeChange

		1:	cmp r3, #'*'
			bne 1f
			#todo toggle buffer
			bl toggleBuffer

		1:	cmp r3, #'A'
			bne 2f
			bl toggleDispBuffer
			#todo display buffer results

		2:	pop {r2-r4, pc}

#Change sample rate
#Blocks program
#Clears buffer
sRateChange:
			push {r0-r4, lr}
		3:	bl LcdClear
			bl KeyPrepRow

			ldr r0, =newTime
			bl LcdPrintString

			bl LcdEnableBlink

		1:	ldr r4, =KeyPressed
			ldrb r3, [r4]
			cmp r3, #0
			beq 1b

			mov r0, #0
			strb r0, [r4]

			mov r0, r3
			bl LcdPrintChar

			bl LcdDisableBlink

			sub r0, #0x30

			cmp r0, #9
			ble 2f

			#Code for invalid number
			ldr r0, =invalid
			bl LcdClear
			bl LcdPrintString
			bl DelayIntS
			b 3b

		2:	bl rstBuffer
			bl SetSampleRate
			bl LcdClear

			pop {r0-r4, pc}

#Change buffer size
#Blocks program
#Clears buffer
bSizeChange:

			push {r0-r4, lr}

		3:	bl LcdClear
			bl KeyPrepRow

			ldr r0, =newBuff
			bl LcdPrintString

			bl LcdEnableBlink

			#get first num
			ldr r4, =KeyPressed
		1:	ldrb r3, [r4]
			cmp r3, #0
			beq 1b

			#Clr key buffer
			mov r0, #0
			strb r0, [r4]

			mov r0, r3
			bl LcdPrintChar
			sub r3, #0x30
			mov r2, #10
			mul r2, r3

			bl KeyPrepRow

			#get second num
		1:	ldrb r3, [r4]
			cmp r3, #0
			beq 1b

			#Clr key buffer
			mov r0, #0
			strb r0, [r4]

			mov r0, r3
			bl LcdPrintChar

			sub r3, #0x30
			add r2, r3

			cmp r2, #99
			ble 2f

			#Code for invalid number
			ldr r0, =invalid
			bl LcdClear
			bl LcdPrintString
			bl DelayIntS
			b 3b

		2:	bl rstBuffer
			ldr r4, =bufferSize
			strb r2, [r4]

			bl LcdDisableBlink
			bl LcdClear
			pop {r0-r4, pc}

#Toggles storing to buffer functionality
toggleBuffer:
			push {r3-r4, lr}
			ldr r4, =buffering
			ldrb r3, [r4]
			eor r3, #0x01
			strb r3, [r4]

			cmp r3, #0x01
			beq 1f

			bl displayBuffer

		1:	pop {r3-r4, pc}

#Displays all currently buffered values, oldest to newest
displayBuffer:
			push {r0-r7, lr}
			#buffer end index
			ldr r4, =bufferPos
			ldrb r6, [r4]
			sub r6, #1

			#Store buffer size in r3
			ldr r4, =bufferSize
			ldrb r3, [r4]

			#buffer beginning index
			ldr r5, =0xFFFFFFFF

			ldr r4, =bufOverflow
			ldrb r7, [r4]
			ldr r4, =buffer
			cbz r7, 2f

			mov r5, r6

		2:	mov r0, #1
			mov r1, #0
			bl LcdSetPosition

			ldr r0, =bufferedResults
			bl LcdPrintString

			#Count
			mov r2, #0

		1:	bl LcdHome

			#Print index of value
			add r2, #1
			mov r0, #'('
			bl LcdPrintChar
			mov r0, r2
			bl LcdPrintNum
			mov r0, #')'
			bl LcdPrintChar

			mov r0, #' '
			bl LcdPrintChar

			add r5, #1

			#Set index equal to 0 if equals size
			cmp r5, r3
			it eq
			moveq r5, #0

			#r1 branch ofset from multiplying index by 2
			add r1, r5, r5
			ldrh r0, [r4, r1]

			bl printTemp

			mov r0, #500
			bl DelayMs

			cmp r5, r6
			bne 1b

		2:	bl rstBuffer

			pop {r0-r7, pc}

#Toggles display of currently buffering value
toggleDispBuffer:

			push {r3-r4}

			ldr r4, =dispBuffer
			ldr r3, [r4]
			eor r3, #0x01
			str r3, [r4]

			pop {r3-r4}
			bx lr

#Toggles temperature unit to be printed in (C or F)
changeTemp:
			push {r3-r4}
			ldr r4, =TempCorF
			ldrb r3, [r4]
			cbz r3, 1f

			mov r3, #0
			strb r3, [r4]
			b 2f

		1:	mov r3, #1
			strb r3, [r4]

		2:	pop {r3-r4}
			bx lr

#resets all values in buffer to 0 and all
#buffer attributes to 0
rstBuffer:
			push {r2-r4}
			ldr r4, =bufferPos
			mov r3, #0
			strb r3, [r4]

			ldr r4, =bufOverflow
			strb r3, [r4]

			ldr r4, =buffer
			mov r2, #99

		1:	strb r3, [r4, r2]
			subs r2, #1
			bne 1b

			pop {r2-r4}
			bx lr

.section .data
	#Buffer values
	bufferSize: .byte 5
	bufferPos: .byte 0
	buffer: .skip 2 * 99

	#Booleans
	TempCorF:	.byte 0x00
	buffering: .byte 0x01
	bufOverflow: .byte 0x00
	dispBuffer: .byte 0x01


.section .rodata

	#Strings for UI
	newBuff: .asciz "Entr buffer size(01-99): "
	newTime: .asciz "Entr sample rate(1-9): "
	invalid: .asciz "Invalid number"
	bufferingS: .asciz "buffering,pos:"
	bufferFull: .asciz "buffer full"
	notBufferingS: .asciz "Buffer Disabled"
	bufferedResults: .asciz "Buffered results"
	intro: .asciz "Temp Datalogger"
