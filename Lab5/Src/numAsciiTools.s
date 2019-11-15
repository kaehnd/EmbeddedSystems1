#num_to_ASCII.s
#Daniel Kaehn
#CE2801
#Lab3
#Description: Implements conversion from int between 0 & 9999 to ASCII
			.syntax unified
			.cpu cortex-m4
			.thumb

			.section .text
			.equ ERR, 0x00457272
			.global NumToAscii

#Implements conversion from int between 0 & 9999 to ASCII
#Takes int 0-9999 arg at r0
#returns 4 ASCII bytes at r0
NumToAscii:

			push {r1-r4}

			#Check if the int passed to r0 is in acceptable range
			ldr r1, =9999
			cmp r0, r1
			bgt error

			#Initialize BCD sctratch reg
			mov r2, #0
			#Initialize counter
			mov r4, #13

			#Double Dabble Algorithm storing to
	dd:
			#Shift value from queue to BCD reg
			lsl r0, #1
			lsl r2, #1
			ubfx r1, r0, #14, #1
			orr r2, r1

			#Add 3 to each byte that is > 4

			ubfx r3, r2, #0, #4
			cmp r3, #4
			ble 2f

			add r3, #3
			bfi r2, r3, #0, #4
	2:
			ubfx r3, r2, #4, #4
			cmp r3, #4
			ble 3f

			add r3, #3
			bfi r2, r3, #4, #4
	3:
			ubfx r3, r2, #8, #4
			cmp r3, #4
			ble 4f

			add r3, #3
			bfi r2, r3, #8, #4
	4:
			ubfx r3, r2, #12, #4
			cmp r3, #4
			ble 5f

			add r3, #3
			bfi r2, r3, #12, #4
	5:
			subs r4, #1
			bne dd

			#Edge Case last shift
			lsl r0, #1
			lsl r2, #1
			ubfx r1, r0, #14, #1
			orr r2, r1

			#Add 0x30 to each byte to convert to ASCII

			ubfx r3, r2, #0, #4
			add r3, #0x30
			bfi r0, r3, #0, #8

			ubfx r3, r2, #4, #4
			add r3, #0x30
			bfi r0, r3, #8, #8

			ubfx r3, r2, #8, #4
			add r3, #0x30
			bfi r0, r3, #16, #8

			ubfx r3, r2, #12, #4
			add r3, #0x30
			bfi r0, r3, #24, #8

			b end

			#return "err" if not acceptable range
	error:
			ldr r0, =ERR

	end:
			pop {r1-r4}

			bx lr
