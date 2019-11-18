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


			.equ USART2_BASE, 0x40004400



			.equ USART_SR, 0x00
			.equ USART_DR, 0x04
			.equ USART_BRR, 0x08
			.equ USART_CR1, 0x0C

			.equ USART_BAUD, 0x341


			.equ GPIOA_BASE, 0x40020000
		    .equ GPIOC_BASE, 0x40020800
		    .equ GPIO_MODER, 0x00
		    .equ GPIO_IDR, 0x10
		    .equ GPIO_ODR, 0x14
		    .equ GPIO_BSRR, 0x18
		    .equ GPIO_AFRL, 0x20



		    .equ RCC_BASE,    0x40023800
			.equ RCC_AHB1ENR, 0x30
			.equ RCC_APB1ENR, 0x40
		    .equ RCC_GPIOAEN, 1
		    .equ RCC_USART2EN, 1<<17



main:
			#Turn on in RCC

			ldr r1, =RCC_BASE
		    ldr r2, [r1, RCC_AHB1ENR]
		    orr r2, RCC_GPIOAEN
		    str r2, [r1, RCC_AHB1ENR]

		    ldr r2, [r1, RCC_APB1ENR]
		    orr r2, RCC_USART2EN
		    str r2, [r1, RCC_APB1ENR]


		    #Set up pins

			#set mode to alternate function
		    ldr r1, =GPIOA_BASE
		    ldr r2, [r1, #GPIO_MODER]
		    orr r2, #(0b1010<<4)
		    str r2, [r1, #GPIO_MODER]

		    #set alternate function to af7

		    ldr r2, [r1, #GPIO_AFRL]
		    orr r2, #(0b01110111<<8)
		    str r2, [r1, #GPIO_AFRL]


		    #Set up USART

		    ldr r1, =USART2_BASE
		    ldr r2, =USART_BAUD
		    str r2, [r1, #USART_BRR]

		    #Set stuff in USART
		    ldr r2, [r1, #USART_CR1]
		    bic r2, #0b1111<<10
		    orr r2, #0b1011<<10
		    bic r2, #111<<1
		    orr r2, #110<<1
		   	str r2, [r1, #USART_CR1]

	2:		bl DelayIntS
			ldr r1, =USART2_BASE
			ldr r3, =string

	1:		ldr r2, [r1, #USART_SR]
			ands r2, 1<<7
			beq 1b

			ldrb r4, [r3]

			cmp r4, #0
			beq end

			str r4, [r1, #USART_DR]

			add r3, #1
			b 1b




end:	    b	2b

.section .rodata
string: .asciz "Helloworld!\n"



