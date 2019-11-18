#delay_ms.s
#Daniel Kaehn
#CE2801
#Lab3
#Description: Implements busy delay with r0 int milliseconds to delay
			.syntax unified
			.cpu cortex-m4
			.thumb
			.section .text

				.equ SYSTICK_BASE, 0xE000E010
				.equ STK_CTRL, 0x00
				.equ STK_LOAD, 0x04
				.equ STK_VAL, 0x08
				.equ STK_CALIB, 0x0C


				.equ COUNTFLAG, 1<<16
				.equ CLKSOURCE, 1<<2
				.equ TICKINT, 1<<1
				.equ ENABLE, 1<<0


				.equ TICKS_PER_S, 16000000
				.equ TICKS_PER_MS, 16000

		.global DelayMs
		.global DelayUs
		.global DelayS
		.global DelayIntS
		.global SystickRst

#Delay specified amount of microseconds
#Args: r0, microseconds to delay
#No return
DelayUs:
		push {r0-r1, lr}

		bl SystickRst

		lsl r0, #4
		ldr r1, =SYSTICK_BASE
		str r0, [r1, STK_LOAD]

		mov r0, #(ENABLE|CLKSOURCE)
		str r0, [r1, #STK_CTRL]

	1:
		ldr r0, [r1, #STK_CTRL]
		ands r0, r0, #COUNTFLAG
		beq 1b

		pop {r0-r1, pc}


#Repeats millisecond delay for specified milliseconds
#Args: r0 amount of millisconds
#No returns
DelayMs:

		push {r0-r1, lr}

		bl SystickRst

	1:	bl msDelay
		subs r0, #1
		bne 1b

		pop {r0-r1, pc}


#Delay specified amount of seconds
#Args: r0, seconds to delay
#No return
DelayS:
		push {r0-r1, lr}


		bl SystickRst

	1:	bl sDelay
		subs r0, #1
		bne 1b

		pop {r0-r1, pc}

#Helper function to delay one millisecond using SYSTEK Timer
msDelay:

		push {r1-r2}

		ldr r1, =SYSTICK_BASE
		ldr r2, =TICKS_PER_MS
		str r2, [r1, #STK_LOAD]

		mov r2, #(ENABLE|CLKSOURCE)
		str r2, [r1, #STK_CTRL]

		ldr r2, [r1, #STK_CTRL]

	1:
		ldr r2, [r1, #STK_CTRL]
		ands r2, r2, #COUNTFLAG
		beq 1b

		pop {r1-r2}
		bx lr


#Helper function delays one second using SYSTEK Timer
sDelay:
		push {r1-r2}

		ldr r1, =SYSTICK_BASE

		ldr r2, =TICKS_PER_S
		str r2, [r1, #STK_LOAD]

		mov r2, #(ENABLE|CLKSOURCE)
		str r2, [r1, STK_CTRL]

	1:
		ldr r2, [r1, #STK_CTRL]
		ands r2, r2, #COUNTFLAG
		beq 1b

		pop {r1-r2}
		bx lr

#Resets Systick values
#No args
#no return
SystickRst:
		push {r1-r2}

		ldr r1, =SYSTICK_BASE
		mov r2, #0
		str r2, [r1, #STK_CTRL]
		str r2, [r1, #STK_LOAD]
		str r2, [r1, #STK_VAL]

		pop {r1-r2}

		bx lr

#Delays 1 second using Systick interrupt, busy check DelayBool
#No args
#No return
DelayIntS:
		push {r1-r3, lr}

		bl SystickRst

		ldr r1, =SYSTICK_BASE

		ldr r2, =TICKS_PER_S
		str r2, [r1, #STK_LOAD]

		mov r2, #(ENABLE|TICKINT|CLKSOURCE)
		str r2, [r1, #STK_CTRL]

		ldr r3, =DelayBool

	1:	ldrb r2, [r3]
		subs r2, 0xFF
		bne 1b

		mov r2, #0
		strb r2, [r3]
		str r2, [r1, #STK_CTRL]

		pop {r1-r3, pc}

#Handler for Systick timer, sets DelayBool
.global SysTick_Handler
.thumb_func
SysTick_Handler:

			ldr r1, =DelayBool
			mov r0, #0xFF
			strb r0, [r1]

			bx lr

.section .data
DelayBool:	.byte 0x00
