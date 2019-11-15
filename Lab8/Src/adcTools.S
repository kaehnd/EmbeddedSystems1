#adcTools.S
#Daniel Kaehn
#CE2801
#Lab8
#Description: API for ADC using timer 5 to control sample rate
#Uses interrupts

.syntax unified
.cpu cortex-m4
.thumb

.section .text

			.equ ADC1_BASE, 0x40012000

			.equ ADC_SR, 0x00
			.equ ADC_CR1, 0x04
			.equ ADC_CR2, 0x08
			.equ ADC_SQR3, 0x34
			.equ ADC_DR, 0x4C

			.equ ADC_EOCSET, 0b1<<1


			#ADC_CR1 Vals
			.equ ADC_RES6B, 0b11<<24
			.equ ADC_RES8B, 0b10<<24
			.equ ADC_RES10B, 0b01<<24
			.equ ADC_RES12B, 0b00<<24


			#ADC_CR2 Vals
			.equ ADC_SWSTART, 1<<30
			.equ ADC_TIM5EXT, 0b1010
			.equ ADC_EXTEN, 0b01<<28

			.equ ADC_CONT, 0b1<<1
			.equ ADC_ENABLE, 0b1<<0

			.equ ADC_CONTMASK, 0x30000002

			#External interrupt values
			.equ EXTI_BASE, 0x40013C00
			.equ EXTI_PR, 0x14
			.equ EXTI_IMR, 0x00
			.equ EXTI_FTSR, 0x0C

			#Sytem config values
			.equ SYSCFG_BASE, 0x40013800
			.equ SYSCFG_EXTICR2, 0x0C

			#NVIC values
			.equ NVIC_BASE, 0xE000E100
			.equ NVIC_ISER0, 0x000
			.equ NVIC_ICPR0, 0x180

			#RCC values
			.equ RCC_BASE, 0x40023800
			.equ RCC_APB2ENR, 0x44
			.equ RCC_APB1ENR, 0x40

			.equ RCC_TIM5EN, 1<<3


			#Timer values
			.equ TIM5_BASE, 0x40000C00

			.equ TIMx_ARR, 0x2C
			.equ TIMx_CCER, 0x20
			.equ TIMx_CCMR1, 0x18
			.equ TIMx_CR1, 0x00
			.equ TIMx_CCR1, 0x34
			.equ TIMx_CNT, 0x24


			.global ADC1Init
			.global ToggleCont
			.global SetSampleRate
			.global TempVToC
			.global TempVToF
			.global ADCManualStart

#Initializes and starts ADC using
ADC1Init:
			push {r2-r5, lr}

			#Turn on ADC in RCC
			ldr r4, =RCC_BASE
			ldr r3, [r4, #RCC_APB2ENR]
			orr r3, #1<<8
			str r3, [r4, #RCC_APB2ENR]

			#Turn on SYSCFG in RCC
			ldr r5, [r4, #RCC_APB2ENR]
			orr r5, r5, #(1<<14)
			str r5, [r4, RCC_APB2ENR]

			#Enable Interrupt in NVIC table
			ldr r4, =NVIC_BASE
			mov r3, #0b1<<18
			str r3, [r4, #NVIC_ISER0]

			ldr r4, =ADC1_BASE

			#Set EOC Interrupt Enable
			ldr r3, [r4, #ADC_CR1]
			orr r3, 0b1<<5
			str r3, [r4, #ADC_CR1]

			#Turn on ADC
			ldr r3, [r4, #ADC_CR2]
			ldr r2, =(ADC_ENABLE)
			orr r3, r2

			#Set external trigger to TIM5 CH1
			mov r2, #ADC_TIM5EXT
			bfi r3, r2, #24, #4

			#Set toggle mode
			mov r2, #0b11
			bfi r3, r2, #28, #2

			str r3, [r4, #ADC_CR2]

			#Set channel 8
			ldr r3, [r4, #ADC_SQR3]
			mov r2, #8
			bfi r3, r2, #0, #5
			str r3, [r4, #ADC_SQR3]

			#Set up timer

			ldr r4, =RCC_BASE
			ldr r5, [r4, #RCC_APB1ENR]
			orr r5, r5, #RCC_TIM5EN
			str r5, [r4, #RCC_APB1ENR]

			ldr r4, =TIM5_BASE

			#Set ARR and CCR to determine frequency
			ldr r5, =16000000
			str r5, [r4, #TIMx_ARR]
			str r5, [r4, #TIMx_CCR1]

			#Set output mode to toggle
			movw r5, #(0b011<<4)
			str r5, [r4, #TIMx_CCMR1]

			#Compare output enable
			movw r5, #1
			str r5, [r4, #TIMx_CCER]

			#ENABLE TIMER AND START ADC
			ldr r4, =TIM5_BASE
			movw r2, #1
			str r2, [r4, #TIMx_CR1]

			pop {r2-r5, pc}

#Toggles continuous conversion in ADC
#No params
#No return
ToggleCont:
			push {r1-r4}

			ldr r4, =ADC1_BASE

			#Toggle cont bit and ext start mode
			ldr r3, [r4, #ADC_CR2]
			ldr r2, =ADC_CONTMASK
			eor r3, r2

			#If turning on, do software start
			ands r1, r3, r2
			beq 1f
			ldr r2, =(ADC_SWSTART)
			orr r3, r2


		1:	str r3, [r4, #ADC_CR2]

			#Toggle interrupt
			ldr r3, [r4, #ADC_CR1]
			eor r3, 0b1<<5
			str r3, [r4, #ADC_CR1]

			pop {r1-r4}
			bx lr

#Takes r0 seconds between samples
SetSampleRate:
			push {r4-r5}
			ldr r4, =TIM5_BASE


			#Set ARR and CCR to determine frequency
			ldr r5, =16000000

			mul r5, r0
			str r5, [r4, #TIMx_ARR]
			str r5, [r4, #TIMx_CCR1]

			mov r5, #0
			str r5, [r4, #TIMx_CNT]

			pop {r4-r5}
			bx lr

#Handles when ADC EOC is set
.global ADC_IRQHandler
.thumb_func
ADC_IRQHandler:

			#Read data and store at PrevTemp
			ldr r3, =ADC1_BASE
			ldr r2, [r3, ADC_DR]

			ldr r3, =PrevTemp
			str r2, [r3]


			#Clear pending interrupt
			ldr r0, =NVIC_BASE
			mov r1, 0b1<<18
			str r1, [r0, #NVIC_ICPR0]

			bx lr

#Manual start for ADC
#No params
#No return
ADCManualStart:
			push {r2-r4}
			ldr r4, =ADC1_BASE
			#Toggle cont bit and ext start mode
			ldr r3, [r4, #ADC_CR2]
			ldr r2, =(ADC_SWSTART)
			orr r3, r2
			pop {r2-r4}


#Converts voltage percentage to degrees C
#Param: r0 voltage
#RETURN r0 temp in Celsius
TempVToC:
			push {r1}

			#Eq to convert to degrees celsius
			mov r1, #81
			mul r0, r1
			ldr r1, =50000
			sub r0, r1

			#Divide to two dec precision
			mov r1, #10
			udiv r0, r1

			pop {r1}
			bx lr

#Converts voltage percentage to degrees F
#Param: r0 voltage
#RETURN r0 temp in farenheight
TempVToF:
			push {r1, lr}

			bl TempVToC

			mov r1, #9
			mul r0, r1
			mov r1, #5
			udiv r0, r1
			add r0, #3200

			pop {r1, pc}



.section .data
.global PrevTemp
PrevTemp:
	.word 0x00000000

