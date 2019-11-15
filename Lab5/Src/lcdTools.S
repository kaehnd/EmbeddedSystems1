#lcdTools.s
#Daniel Kaehn
#CE2801
#Lab4
#Description: API for LCD peripheral for writing strings and numbers to screen

.syntax unified
.cpu cortex-m4
.thumb
.section .text

#Mem addresses
	.equ RCC_BASE,    0x40023800
	.equ RCC_AHB1ENR, 0x30
    .equ RCC_GPIOAEN, 1
    .equ RCC_GPIOCEN, 1<<2

    .equ GPIOA_BASE, 0x40020000
    .equ GPIOC_BASE, 0x40020800
    .equ GPIO_MODER, 0x00
    .equ GPIO_IDR, 0x10
    .equ GPIO_ODR, 0x14
    .equ GPIO_BSRR, 0x18

#Pin numbers
	.equ RS, 8
	.equ RW, 9
	.equ E, 10

#Commands for BSRR
	.equ RS_SET, 1<<RS
	.equ RS_CLR, 1<<(RS+16)
	.equ RW_SET, 1<<RW
	.equ RW_CLR, 1<<(RW+16)
	.equ E_SET, 1<<E
	.equ E_CLR, 1<<(E+16)

#Globally exposed functions
	.global LcdInit
	.global LcdHome
	.global LcdClear
	.global LcdSetPosition
	.global LcdPrintString
	.global LcdPrintNum
	.global LcdPrintChar

#Local helper function to set up ports
portSetup:
	    push {r1-r3}

	    #Turn on Ports in RCC
	    ldr r1, =RCC_BASE
	    ldr r2, [r1, RCC_AHB1ENR]
	    orr r2, RCC_GPIOAEN
	    orr r2, RCC_GPIOCEN
	    str r2, [r1, RCC_AHB1ENR]

	    #Set DB Pins to Outputs
	    ldr r1, =GPIOA_BASE
	    ldr r2, [r1, #GPIO_MODER]
	    movw r3, #0b0101010101010101
	    bfi r2, r3, #8, #16
	    str r2, [r1, GPIO_MODER]

	    #Set RS RW E Pins to Outputs

		ldr r1, =GPIOC_BASE
	    ldr r2, [r1, #GPIO_MODER]
		mov r3, #0b010101

	    bfi r2, r3, #16, #6
	    str r2, [r1, #GPIO_MODER]

		#return
		pop {r1-r3}
	    bx lr

#Local helper function to write instruction
#Args r0 = 8-bit instruction for LCD right-aligned
#No returns
writeInstruction:
		push {r1-r4, lr}

		#Set RS=0,RW=0,E=0

		ldr r1, =GPIOC_BASE
		ldr r2, =(RS_CLR|RW_CLR|E_CLR)
		str r2, [r1, GPIO_BSRR]

		#Set E=1
		ldr r2, =(E_SET)
		str r2, [r1, GPIO_BSRR]

		#Set R0 -> DataBus

		ldr r3, =GPIOA_BASE
		ldr r4, [r3, GPIO_ODR]
		bfi r4, r0, #4, #8
		str r4, [r3, GPIO_ODR]

		#Set E=0
		ldr r2, =(E_CLR)
		str r2, [r1, GPIO_BSRR]

		#Poll busy flag until LCD is ready

		bl pollBusy

		#return
		pop {r1-r4, pc}



#Local helper function to write char
#Args: r0=ASCII code to print to LCD
#No returns
writeData:
		push {r0-r4, lr}

		#Set RS=1,RW=0,E=0
		ldr r1, =GPIOC_BASE
		ldr r2, =(RS_SET|RW_CLR|E_CLR)
		str r2, [r1, GPIO_BSRR]
		#Set E=1
		ldr r2, =(E_SET)
		str r2, [r1, GPIO_BSRR]
		#Set R0 -> DataBus

		ldr r3, =GPIOA_BASE
		ldr r4, [r3, GPIO_ODR]
		bfi r4, r0, #4, #8
		str r4, [r3, GPIO_ODR]

		#Set E=0
		ldr r2, =(E_CLR)
		str r2, [r1, GPIO_BSRR]

		#Poll busy flag until LCD is ready
		bl pollBusy

		#return
		pop {r0-r4, pc}

#Code to intialize the lcd
#**Must be called before any other public subroutine in this file**
#No arguments
#No returns
LcdInit:
		push {r0, lr}

	    #Set up Ports
	    bl portSetup


	    #Wait 40ms
	    mov r0, #40
	    bl DelayMs

	    #Write Function Set (0x38)
	    mov r0, #0x38
	    bl writeInstruction

	    #Write Function Set (0x38)
	    mov r0, #0x38
	    bl writeInstruction

	    #Write Display On/Off(0x0F)
	    mov r0, #0x0F
	    bl writeInstruction

	    #Write Display Clear (0x01)
	    mov r0, #0x01
	    bl writeInstruction

	    #Write Entry Mode Set (0x06)
	    mov r0, #0x06
	    bl writeInstruction

		pop {r0, pc}


#Clears the display
#No arguments
#No return
LcdClear:
		push {r0, lr}

		#Write Display Clear (0x01)
	    mov r0, #0x01
	    bl writeInstruction

		#return
	    pop {r0, pc}


#Moves cursor to home position
#No arguments
#No return
LcdHome:
		push {r0, lr}

		#Write Home (0x02)
		mov r0, #0x02
		bl writeInstruction

		#return
		pop {r0, pc}





#Moves cursor to position indicated
#Args: r0 zero-based row; r1 zero-based column
#No return
LcdSetPosition:
		push {r0-r2, lr}


		#Initial DRAM address
		mov r2, #0b10000000

		cmp r0, #0
		beq 1f
		#Add 0x40 if moving to second row
		add r2, #0x40

		#Add row offset
	1:	add r0, r2, r1

		#Write cursor position to DRAM
		bl writeInstruction

		#return
		pop {r0-r2, pc}


#Prints a null terminated string to the display
#Args: r0 address of null-terminated string
#RETURN: r0 number of characters written to the display (OVERWRITES VALUE)
LcdPrintString:

		push {r1-r2, lr}
		mov r1, r0
		mov r2, r0

		#Load next char of string
	1:	ldrb r0, [r1]

		#Check for null terminator
		cmp r0, #0
		beq 2f
		#Write char
		bl writeData
		add r1, #1
		b 1b

		#Subtract end address from start address to determine
		#number of chars printed
	2:	sub r0, r1, r2

		#return
		pop {r1-r2, pc}


#Prints a decimal number to the diplay between 0 and 9999
#***SKIPS LEADING 0s***
#Args: r0 number between 0 and 9999
#No return
LcdPrintNum:

		push {r0-r1, lr}
		#Convert arg to 4 ASCII Characters
		bl NumToAscii
		mov r1, r0

		#Extract each ASCII character and print to LCD

		ubfx r0, r1, #24, #8
		#Check if 0, if so, skip char
		cmp r0, #0x30
		beq 1f
		bl writeData

	1:	ubfx r0, r1, #16, #8
		cmp r0, #0x30
		beq 2f
		bl writeData

	2:	ubfx r0, r1, #8, #8
		cmp r0, #0x30
		beq 3f
		bl writeData

	3:	ubfx r0, r1, #0, #8
		bl writeData

		#return
		pop {r0-r1, pc}

LcdPrintChar:
		push {lr}
		bl writeData
		pop {pc}



#Local helper function reads the Busy flag of the LCD until
#it is '0' and it is ready to take new instructions
#No arguments
#No returns
pollBusy:

		push {r1-r5, lr}

		#Set D0-D7 to be inputs
		ldr r1, =GPIOA_BASE
	    ldr r2, [r1, #GPIO_MODER]
	    movw r3, #0b0000000000000000
	    bfi r2, r3, #8, #16
	    str r2, [r1, GPIO_MODER]

	    ldr r3, =GPIOC_BASE
		ldr r2, =(RS_CLR|RW_SET|E_CLR)
		str r2, [r3, GPIO_BSRR]

		#Set E high
	1:	ldr r2, =(E_SET)
		str r2, [r3, GPIO_BSRR]

		#Clr E low
		ldr r2, =(E_CLR)
		str r2, [r3, GPIO_BSRR]

		#Read busy flag
		ldr r5, [r1, GPIO_IDR]
		ubfx r4, r5, #11, #1

		#Loop if busy (D7) = '1'
		cmp r4, #0
		bne 1b

		#set D0-D7 to be outputs
		ldr r1, =GPIOA_BASE
	    ldr r2, [r1, #GPIO_MODER]
	    movw r3, #0b0101010101010101
	    bfi r2, r3, #8, #16
	    str r2, [r1, GPIO_MODER]

		# return
		pop {r1-r5, pc}
