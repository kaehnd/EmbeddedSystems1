#delay_ms.s
#Daniel Kaehn
#CE2801
#Lab3
#Description: Implements busy delay with r0 int milliseconds to delay
			.syntax unified
			.cpu cortex-m4
			.thumb
			.section .text

				.equ LOOPS_PER_MS, 8000

			.global Delayms
			.global Delayus

#Implements busy delay
#Takes r0 int milliseconds to delay
Delayms:

			push {r1}

			#Loop r0 times
	1:
			mov r1, #LOOPS_PER_MS
			#Account for extra instructions called each millisecond
			sub r1, #2

			#Loop for 1 ms
	2:
			subs r1, #1
			bne 2b

			#Branch back until delay is over
			subs r0, #1
			bne 1b

			pop {r1}

			bx lr

Delayus:
		# stack
		push {r0,lr}

		lsl r0, r0, #3

	1:
		subs r0, r0, #1
		bne 1b

		# return
		pop {r0,pc}
