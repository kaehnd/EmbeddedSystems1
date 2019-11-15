#main.S
#Daniel Kaehn
#CE2801
#Lab7
#Description: Implements Binary to Hex Training Game
#Uses interrupts

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

			.equ TIM2_BASE, 0x40000000

			.equ TIMx_ARR, 0x2C
			.equ TIMx_CCER, 0x20
			.equ TIMx_CCMR1, 0x18
			.equ TIMx_CR1, 0x00
			.equ TIMx_CCR1, 0x34
			.equ TIMx_CNT, 0x24

			#STK values
			.equ SYSTICK_BASE, 0xE000E010
			.equ STK_CTRL, 0x00
			.equ STK_LOAD, 0x04
			.equ STK_VAL, 0x08
			.equ STK_CALIB, 0x0C
			.equ STK_COUNTFLAG, 1<<16
			.equ STK_CLKSOURCE, 1<<2
			.equ STK_TICKINT, 1<<1
			.equ STK_ENABLE, 1<<0
			.equ TICKS_PER_S, 16000000

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
			.equ NVIC_ISER2, 0x008
			.equ NVIC_ICER0, 0x080

			.equ KEYPAD_INT_MOD, 0x00800400

main:
			#initialize peripherals
			bl PiezoInit
			bl LcdInit
			bl KeyInit


			#RCC for timer 2 and interrupts
			ldr r4, =RCC_BASE
			ldr r5, [r4, #RCC_APB1ENR]
			orr r5, r5, #RCC_TIM2EN
			str r5, [r4, #RCC_APB1ENR]


			#Start timer for randnums
			ldr r6, =TIM2_BASE

			movw r0, 0xFFFF
			movt r0, 0xFFFF
			str r0, [r6, #TIMx_ARR]
			str r0, [r6, #TIMx_CCR1]

			movw r0, #1
			str r0, [r6, #TIMx_CR1]

			#Set up keypad interrupts
			bl KeyIntInit




	rst:	bl LcdClear
			#Print intro messages
			ldr r0, =IntroMsg
			bl LcdPrintString
			bl DelayIntS
			bl DelayIntS

			#Count
			mov r12, #5

			# #correct
			mov r7, #0

			#Press to start
	s:		bl LcdClear
			ldr r0, =PressToStart
			bl LcdPrintString

			#Wait for keypress ***UNCOMMENT***
			bl KeyGetchar


			bl LcdClear

			#Prep keypad rows

			bl KeyPrepRow

			ldr r0, =Ready
			bl LcdPrintString
			bl DelayIntS

			bl LcdClear
			ldr r0, =Set
			bl LcdPrintString
			bl DelayIntS

			bl LcdClear
			ldr r0, =Go
			bl LcdPrintString

			#get rand num
			ldr r6, =TIM2_BASE
			ldr r0, [r6, TIMx_CNT]

			#store rand in r11
			ubfx r11, r0, #0, #4

			bl NumToBinaryAscii
			bl LcdPrintString

			#Sets timer val to 0
			mov r1, #0
			str r1, [r6, #TIMx_CNT]

			bl KeyStartInt

			ldr r1, =KeyPressed
	1:		ldrb r2, [r1]
			cmp r2, '0'
			beq 1b

			bl KeyStopInt

			mov r3, '0'
			strb r3, [r1]

			bl LcdClear

			#Check if correct
			cmp r2, r11
			beq success

	fail:
			ldr r0, =Incorrect
			bl LcdPrintString
			bl PiezoFail

			bl DelayIntS

			bl LcdClear

			ldr r0, =CorAns
			bl LcdPrintString

			#Prints what the correct answer should be
			ldr r1, =Hex
			ldrb r0, [r1, r11]
			bl LcdPrintChar

			bl DelayIntS
			bl DelayIntS

			b end

	success:
			#Display correct message and time taken
			ldr r0, =Correct
			bl LcdPrintString

			mov r0, #1
			mov r1, #0
			bl LcdSetPosition

			ldr r0, =Time
			bl LcdPrintString

			ldr r1, =RecentTime
			ldr r0, [r1]

			#Update fastest time if time is faster
			ldr r1, =FastestTime
			ldr r3, [r1]

			cmp r0, r3
			it lt
			strlt r0, [r1]

			#Div by 16 to make µs
			lsr r0, r0, #4
			bl LcdPrintNumBig

			mov r0, 's'
			bl LcdPrintChar

			bl PiezoSuccess

			#Inc # Correct
			add r7, #1

			bl DelayIntS
			bl DelayIntS

			b end


	end:	subs r12, #1
			bne s

			#End of five trials
			bl LcdClear

			#Display number correct
			ldr r0, =YouGot
			bl LcdPrintString

			mov r0, r7
			bl LcdPrintNum

			ldr r0, =Right
			bl LcdPrintString

			bl DelayIntS
			bl DelayIntS

			#Skip next if none right
			cmp r7, #0
			beq 2f

			#Display fastest time
			bl LcdClear
			ldr r0, =FastTime
			bl LcdPrintString

			mov r0, #1
			mov r1, #0
			bl LcdSetPosition

			ldr r1, =FastestTime
			ldr r0, [r1]
			lsr r0, r0, #4

			bl LcdPrintNumBig

			mov r0, 's'
			bl LcdPrintChar


			bl DelayIntS
			bl DelayIntS

		#	bl KeyGetkey

			#Display play again message
	2:		bl LcdClear
			ldr r0, =Pressb
			bl LcdPrintString

			#Wait for keypress
			bl KeyGetkey

			b rst




.global TakeTime
#Takes time since timer was started
TakeTime:
			push {r1-r2}
			ldr r1, =TIM2_BASE
			ldr r2, [r1, TIMx_CNT]

			ldr r1, =RecentTime
			str r2, [r1]

			pop {r1-r2}
			bx lr




.section .rodata

	Us:	.word 0xB5730000
	Hex: .byte '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'
	IntroMsg: .asciz "Binary to Hex   Trainer"
	PressToStart: .asciz "Press any button to start"
	Correct: .asciz "Correct!"
	Incorrect: .asciz "Incorrect"
	Ready: .asciz "Ready"
	Set: .asciz "Set"
	Go: .asciz "Go!  "
	Time: .asciz "Time: "
	CorAns: .asciz "Correct answer  was: "
	YouGot: .asciz "Score: "
	Right: .asciz "/5"
	FastTime: .asciz "Fastest time:"
	Pressb: .asciz "Press any button to play again"

.section .data

	RecentTime:	.word 0x00000000
	FastestTime: .word 0x7FFFFFFF

	.global KeyPressed
	KeyPressed: .byte '0'
