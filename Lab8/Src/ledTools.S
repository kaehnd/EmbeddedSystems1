#led_tools.s
#Daniel Kaehn
#CE2801
#Lab3
#Description: Implements sending 10-bit binary numbers to the LEDs for debugging purposes


			.syntax unified
			.cpu cortex-m4
			.thumb
			.section .text

			.equ RCC_BASE, 0x40023800
			.equ RCC_AHB1ENR, 0x30
			.equ RCC_GPIOBEN, 1<<1

			.equ GPIOB_BASE, 0x40020400
			.equ GPIO_MODDER, 0x00
			.equ GPIO_ODR, 0x14

			.global NumToLedInit
			.global NumToLed

#Initializes GPIOB and MUST be called BEFOrE num_to_LED
NumToLedInit:

			push {r1-r3}

			#Set rCC to GPIOB
			ldr r1, =RCC_BASE
			ldr r2, [r1, #RCC_AHB1ENR]
			orr r2, #RCC_GPIOBEN
			str r2, [r1, #RCC_AHB1ENR]

			#Set GPIOB to be Output
			ldr r1, =GPIOB_BASE
			ldr r2, [r1, #GPIO_MODDER]

			movw r3, #0x5400
			movt r3, #0x5515
			orr r2, r3

			movw r3, #0xA800
			movt r3, #0xAA2A
			bic r2, r2, r3

			str r2, [r1, #GPIO_MODDER]

			pop {r1-r3}

			bx lr

#Sends bits 0-10 of r0 to LEDS
#Takes r0 int from which bottom 10 bits will be stored
NumToLed:

			push {r1-r3}

			#Get current reg value
			ldr r1, =GPIOB_BASE
			ldr r2, [r1, #GPIO_ODR]

			#Extract bits 0-6 and insert at 5-10
			ubfx r3, r0, #0, #6
			bfi r2, r3, #5, #6

			#Extract bits 7-10 and insert at 12-15
			ubfx r3, r0, #7, #4
			bfi r2, r3, #12, #4

			#Store result to LEDs
			str r2, [r1, #GPIO_ODR]

			pop {r1-r3}

			bx lr
