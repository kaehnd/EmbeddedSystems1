#main.S
#Daniel Kaehn
#CE2801
#Lab5
#Description: Test program for keypadTools.S
#Outputs keypad input to LCD

.syntax unified
.cpu cortex-m4
.thumb

.section .text

		.global main

main:
		#Initialize
		bl KeyInit
		bl LcdInit

		#Get first row key presses
		mov r2, #16
	1:	bl KeyGetchar
		bl LcdPrintChar
		subs r2, #1
		bne 1b

		#Move to second row
		mov r0, #1
		mov r1, #0
		bl LcdSetPosition

		#Get second row key presses
		mov r2, #16
	2:	bl KeyGetchar
		bl LcdPrintChar
		subs r2, #1
		bne 2b

		#Edge case wait for 16th press to move to clear and
		#move to first row

		bl KeyGetchar
		bl LcdClear
		bl LcdPrintChar

		#Start from 15 to account for first char printed
		mov r2, #15

		#Inf loop
		b 1b
end:	b end
