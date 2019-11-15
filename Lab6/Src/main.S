#main.S
#Daniel Kaehn
#CE2801
#Lab6
#Description: Lock program requiring user to enter 4-digit PIN
#to unlock. Allows password to be reset.

.syntax unified
.cpu cortex-m4
.thumb

.section .text

		#250 Hz buzzer tick amt
		.equ FAIL_BUZZER_TICKS, 31250
		#1000 Hz buzzer tick amt
		.equ SUCCESS_BUZZER_TICKS, 8000

		.global main

main:
		#Initialize Keypad, LCD, LED, & Pizeo Spkr
 		bl KeyInit
		bl LcdInit
		bl NumToLedInit
		bl PiezoInit

		#Print intro message
		ldr r0, =intro
		bl LcdPrintString


		mov r0, #1
		bl DelayS

		#Trials before lockout
		mov r7, #3

		#Print prompt
		bl LcdClear
		ldr r0, =locked
		bl LcdPrintString

		mov r0, #500
		bl DelayMs


	s:	bl LcdClear

		mov r0, #0
		mov r1, #0
		bl LcdSetPosition

		ldr r0, =prompt
		bl LcdPrintString

		#Prepare for input
		mov r0, #1
		mov r1, #0
		bl LcdSetPosition

		#Get four chars from keypad (blocking)
		#input of 'C'r
		bl KeyGetchar
		cmp r0, 'C'
		itt eq
		moveq r5, #0
		beq s
		mov r5, r0
		mov r0, #'*'
		bl LcdPrintChar

		bl KeyGetchar
		cmp r0, 'C'
		itt eq
		moveq r5, #0
		beq s
		bfi r5, r0, #8, #8
		mov r0, #'*'
		bl LcdPrintChar

		bl KeyGetchar
		cmp r0, 'C'
		itt eq
		moveq r5, #0
		beq s
		bfi r5, r0, #16, #8
		mov r0, #'*'
		bl LcdPrintChar

		bl KeyGetchar
		cmp r0, 'C'
		itt eq
		moveq r5, #0
		beq s
		bfi r5, r0, #24, #8
		mov r0, #'*'
		bl LcdPrintChar

		#Check if correct password was enterred
		ldr r1, =password
		ldr r2, [r1]
		cmp r2, r5
		beq done

		#*****************Code for if fail...************

		bl LcdClear
		ldr r0, =fail
		bl LcdPrintString

		#Fail buzz
		mov r0, #FAIL_BUZZER_TICKS
		bl PiezoStartBuzz

		mov r0, #1
		bl DelayS

		bl PiezoStopBuzz

		#Print num of attempts before lockout
		mov r0, #0
		mov r1, #0
		bl LcdSetPosition
		ldr r0, =attempts
		bl LcdPrintString
		sub r0, r7, #1
		bl LcdPrintNum

		mov r0, #2
		bl DelayS

		#Decrement attempts before lockout
		subs r7, #1

		bne s

		#Code for Lockout

		bl LcdClear

		ldr r0, =lockout
		bl LcdPrintString

		mov r2, #20

	1:	mov r0, #FAIL_BUZZER_TICKS
		bl PiezoStartBuzz
		mov r0, #500
		bl DelayMs

		mov r0, #SUCCESS_BUZZER_TICKS
		bl PiezoStartBuzz
		mov r0, #500
		bl DelayMs

		subs r2, #1
		bne 1b


		bl PiezoStopBuzz
		#End loop, end lockout and return to start loop

		mov r7, #3

		b s


		#************Success**************
done:	bl LcdClear
		ldr r0, =success
		bl LcdPrintString

		mov r0, #500
		bl DelayMs

		#Print unlocking message
		mov r0, #0
		mov r1, #0
		bl LcdSetPosition
		ldr r0, =unlocking
		bl LcdPrintString

		#Turn on LEDs
		mov r0, #0b11111111111
		bl NumToLed

		#Success buzzer
		mov r0, #SUCCESS_BUZZER_TICKS
		bl PiezoStartBuzz

		mov r0, #1
		bl DelayS

		bl PiezoStopBuzz

		#Turn off LEDs
		mov r0, #0
		bl NumToLed

		#Print end message

		bl LcdClear
		ldr r0, =unlocked
		bl LcdPrintString

		mov r0, #500
		bl DelayMs

		#Unlocked state
	e:	bl LcdClear

		ldr r0, =doSomething
		bl LcdPrintString

		#Check for # and *
	1:	bl KeyGetchar
		#Change password if #
		cmp r0, #'#'
		beq pwdSet
		#Lock if *
		cmp r0, #'*'
		bne 1b

		#End loop, * was pressed

		#Print prompt
		bl LcdClear
		ldr r0, =locked
		bl LcdPrintString

		mov r0, #300
		bl DelayMs

		mov r7, #3
		b s

#Set PIN
pwdSet:
		bl LcdClear
		ldr r0, =setPrompt
		bl LcdPrintString

		mov r0, #1
		mov r1, #0
		bl LcdSetPosition


		bl KeyGetchar
		cmp r0, 'C'
		itt eq
		moveq r5, #0
		beq pwdSet
		mov r5, r0
		mov r0, #'*'
		bl LcdPrintChar

		bl KeyGetchar
		cmp r0, 'C'
		itt eq
		moveq r5, #0
		beq pwdSet
		bfi r5, r0, #8, #8
		mov r0, #'*'
		bl LcdPrintChar

		bl KeyGetchar
		cmp r0, 'C'
		itt eq
		moveq r5, #0
		beq pwdSet
		bfi r5, r0, #16, #8
		mov r0, #'*'
		bl LcdPrintChar

		bl KeyGetchar
		cmp r0, 'C'
		itt eq
		moveq r5, #0
		beq pwdSet
		bfi r5, r0, #24, #8
		mov r0, #'*'
		bl LcdPrintChar

		ldr r1, =password
		str r5, [r1]

		bl LcdClear
		ldr r0, =setSuccess
		bl LcdPrintString

		mov r0, #1
		bl DelayS

		b e

end:	b end

.section .rodata

	intro:
		.asciz "STM Lock"

	locked:
		.asciz "Locked"

	prompt:
		.asciz "PIN: (C to clr)"

	success:
		.asciz "Success!"

	unlocking:
		.asciz "Unlocking..."

	unlocked:
		.asciz "Unlocked."

	doSomething:
		.asciz "Press * to Lock,# to set PIN"

	fail:
		.asciz "Incorrect PIN"

	attempts:
		.asciz "Attempts Left: "

	lockout:
		.asciz "Locked Out!"

	setPrompt:
		.asciz "Enter new PIN:"

	setSuccess:
		.asciz "PIN Changed     Successfully"

.section .data

	password:
		.ascii "9788"
