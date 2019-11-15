#pizoSpkr_tools.s
#Daniel Kaehn
#CE2801
#Lab3
#Description: Stufffsdaf'ailds;jfszd[o8yy


			.syntax unified
			.cpu cortex-m4
			.thumb
			.section .text

			.equ RCC_BASE, 0x40023800
			.equ RCC_APB1ENR, 0x40
			.equ RCC_AHB1ENR, 0x30
			.equ RCC_GPIOBEN, 1<<1
			.equ RCC_TIM3EN, 1<<1

			.equ GPIOB_BASE, 0x40020400
			.equ GPIO_MODER, 0x00
			.equ GPIO_ODR, 0x14
			.equ GPIO_AFRL, 0x20


			.equ TIM3_BASE, 0x40000400

			.equ TIMx_ARR, 0x2C
			.equ TIMx_CCER, 0x20
			.equ TIMx_CCMR1, 0x18
			.equ TIMx_CR1, 0x00
			.equ TIMx_CCR1, 0x34

			.global PiezoInit
			.global PiezoStartBuzz
			.global PiezoStopBuzz
			.global PiezoSuccess
			.global PiezoFail



#Initializes PizeoBuzzer subroutines
#**MUST BE RUN BEFORE ANY BELOW SUBROUTINES**
PiezoInit:
			push {r3-r5, lr}

			#RCC Enables for Timer 3 and GPIOB
			ldr r4, =RCC_BASE
			ldr r5, [r4, #RCC_APB1ENR]
			orr r5, r5, #RCC_TIM3EN
			str r5, [r4, #RCC_APB1ENR]

			ldr r5, [r4, #RCC_AHB1ENR]
			orr r5, r5, #RCC_GPIOBEN
			str r5, [r4, #RCC_AHB1ENR]

			#Enable alternate function

			ldr r4, =GPIOB_BASE
			ldr r5, [r4, #GPIO_AFRL]
			mov r3, #0b0010
			bfi r5, r3, #16, #4
			str r5, [r4, #GPIO_AFRL]

			ldr r5, [r4, GPIO_MODER]
			mov r3, #0b10
			bfi r5, r3, #8, #2
			str r5, [r4, GPIO_MODER]

			ldr r4, =TIM3_BASE

			#Set ARR and CCR to determine frequency
			movw r5, #8000
			str r5, [r4, #TIMx_ARR]
			str r5, [r4, #TIMx_CCR1]

			#Set output mode to toggle
			movw r5, #(0b011<<4)
			str r5, [r4, #TIMx_CCMR1]

			#Compare output enable
			movw r5, #1
			str r5, [r4, #TIMx_CCER]

			pop {r3-r5, pc}



#Starts buzz at specified frequency ticks T = f * 8
#Args r0 = ticks specifiying frequency T = frequency * 8
#No returns
PiezoStartBuzz:
			push {r0-r1}

			#Set new frequency
			ldr r1, =TIM3_BASE
			str r0, [r1, #TIMx_ARR]
			str r0, [r1, #TIMx_CCR1]

			#Enable and start buzz
			movw r0, #1
			str r0, [r1, #TIMx_CR1]

			pop {r0-r1}

			bx lr


#Stopps buzzer
#No Args
#No returns
PiezoStopBuzz:
			push {r0-r1}

			#Disable and stop buzz
			ldr r1, =TIM3_BASE
			movw r0, #0
			str r0, [r1, #TIMx_CR1]

			pop {r0-r1}

			bx lr

PiezoSuccess:
			push {r0, lr}
			mov r0, #18181
			bl PiezoStartBuzz

			mov r0, #100
			bl DelayMs


			ldr r0, =12121
			bl PiezoStartBuzz

			mov r0, #100
			bl DelayMs

			ldr r0, =9090
			bl PiezoStartBuzz

			mov r0, #100
			bl DelayMs

			bl PiezoStopBuzz

			pop {r0, pc}


PiezoFail:

			push {r0, lr}
			mov r0, #9090
			bl PiezoStartBuzz

			mov r0, #100
			bl DelayMs


			ldr r0, =12121
			bl PiezoStartBuzz

			mov r0, #100
			bl DelayMs

			ldr r0, =18181
			bl PiezoStartBuzz

			mov r0, #100
			bl DelayMs

			bl PiezoStopBuzz

			pop {r0, pc}



