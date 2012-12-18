
	.include "vcregs.inc"

	.macro poke reg, val
		mov r1, \reg
		mov r0, \val
		st r0, (r1)
	.endm

	.macro check reg, val
		mov r1, \reg
1:
		ld r0, (r1)
		mov r2, \val
		bne r0, r2, 1b
	.endm

	.global _start
_start:
	.fill 0x200, 1, 0x00
	mov sp, 0x10000
	b start

	.text
	.global start
start:
	/* initialize the clocks */
	.equ PASSWD, 0x5a000000
	.equ PLLC, 5
	.equ OSC, 1
	poke VC_A2W__ADDRESS + 0x190, 0x5a000001
	poke VC_A2W_PLLC_MULT_FRACT, PASSWD | 87380
	poke VC_A2W_PLLC_MULT2, PASSWD | 52 | 0x1000
	poke VC_A2W_PLLC_UNK_0x3c, 0x5a000100
	poke VC_A2W_PLLC_UNK_0x38, 0x5a000000
	poke VC_A2W_PLLC_UNK_0x34, 0x5a144000
	poke VC_A2W_PLLC_UNK_0x30, 0x5a000000
	poke VC_CM__ADDRESS + 0x108, 0x5a000200
	poke VC_CM__ADDRESS + 0x108, 0x5a0002aa
	poke VC_A2W_PLLC_UNK_0x2c, 0x5a000000
	poke VC_A2W_PLLC_UNK_0x28, 0x5a400000
	poke VC_A2W_PLLC_UNK_0x24, 0x5a000005
	poke VC_A2W_PLLC_MULT, PASSWD | 52 | 0x555000
	poke VC_A2W_PLLC_MULT2, PASSWD | 52 | 0x21000
	poke VC_A2W_PLLC_UNK_0x2c, 0x5a000042
	poke VC_A2W_PLLC_UNK_0x28, 0x5a500401
	poke VC_A2W_PLLC_UNK_0x24, 0x5a004005
	poke VC_A2W_PLLC_MULT, PASSWD | 52 | 0x555000
	poke VC_A2W_PLLx_DIV, PASSWD | 2
	poke VC_CM__ADDRESS + 0x108, 0x5a0002ab
	poke VC_CM__ADDRESS + 0x108, 0x5a0002aa
	poke VC_CM__ADDRESS + 0x108, 0x5a0002a8
	poke VC_CM_VPU_CTL, PASSWD | 0x200 | OSC | 0x40
	poke VC_CM_VPU_DIV, PASSWD | (4 << 12)
	poke VC_CM_VPU_CTL, PASSWD | PLLC | 0x40
	poke VC_CM_VPU_CTL, PASSWD | PLLC | 0x50
	poke VC_CM_TIME_DIV, PASSWD | (19 << 12) | 819
	poke VC_CM_TIME_CTL, PASSWD | OSC | 0x10

	/* initialize the uart */
	bl initialize_gpio
	/*bl set_led_on*/

	/* initialize DRAM */
	poke VC_PM__ADDRESS + 0x6c, 0x5a000001
	poke VC_A2W__ADDRESS + 0xd4, 0x5a040000
	poke VC_A2W__ADDRESS + 0xd0, 0x5a000000
	#check VC_A2W__ADDRESS + 0x190, 0x0008f08f
	poke VC_A2W__ADDRESS + 0x190, 0x5a08f09f
	poke VC_CM__ADDRESS + 0x1ac, 0x5a001000
	#check VC_CM__ADDRESS + 0x1a8, 0x00004000
	poke VC_CM__ADDRESS + 0x1a8, 0x5a004001
	#check VC_CM__ADDRESS + 0x1a8, 0x00004001
	poke VC_CM__ADDRESS + 0x1a8, 0x5a004011
	check VC_CM__ADDRESS + 0x1a8, 0x00004091
	#check VC_CM__ADDRESS + 0x1a8, 0x00004091
	poke VC_CM__ADDRESS + 0x1a8, 0x5a024091
	check VC_CM__ADDRESS + 0x1a8, 0x00034091
	#check VC_CM__ADDRESS + 0x1a8, 0x00034091
	poke VC_CM__ADDRESS + 0x1a8, 0x5a030091
	#check VC_CM__ADDRESS + 0x1a8, 0x00030091
	poke VC_CM__ADDRESS + 0x1a8, 0x5a010091
	check VC_CM__ADDRESS + 0x1a8, 0x00000091
	poke VC_SDCO__ADDRESS + 0x60, 0x00000001
	mov r0, 1000
	bl sleep
	poke VC_SDCO__ADDRESS + 0x60, 0x00000000
	poke VC_DCRC__ADDRESS + 0x48, 0x00000007
	poke VC_DCRC__ADDRESS + 0x50, 0x00000000
	poke VC_DCRC__ADDRESS + 0x40, 0x00000011
	poke VC_UNKe06000__ADDRESS + 0x80, 0x00000030
	poke VC_DCRC__ADDRESS + 0x4, 0x00000001
	poke VC_UNKe06000__ADDRESS + 0x4, 0x00000001
	mov r0, 1000
	bl sleep
	poke VC_DCRC__ADDRESS + 0x4, 0x00000000
	poke VC_UNKe06000__ADDRESS + 0x4, 0x00000000
	check VC_DCRC__ADDRESS + 0x18, 0x0000ffff
	poke VC_UNKe06000__ADDRESS + 0x80, 0x00000000
	poke VC_SDCO__ADDRESS + 0x4, 0x006e3395
	poke VC_SDCO__ADDRESS + 0x8, 0x000000f9
	poke VC_SDCO__ADDRESS + 0xc, 0x06000431
	poke VC_SDCO__ADDRESS + 0x94, 0x10000011
	poke VC_SDCO__ADDRESS + 0x98, 0x10106000
	poke VC_SDCO__ADDRESS + 0x14, 0x000af002
	poke VC_SDCO__ADDRESS + 0x10, 0x0000008c
	poke VC_SDCO__ADDRESS + 0x64, 0x00000003
	poke VC_SDCO__ADDRESS + 0x0, 0x00200042
	check VC_SDCO__ADDRESS + 0x0, 0x00218e42
	#check VC_SDCO__ADDRESS + 0x90, 0x80000000
	poke VC_SDCO__ADDRESS + 0x90, 0x10000402
	check VC_SDCO__ADDRESS + 0x90, 0x90000402
	#check VC_SDCO__ADDRESS + 0x90, 0x90000402
	poke VC_SDCO__ADDRESS + 0x90, 0x100000ff
	check VC_SDCO__ADDRESS + 0x90, 0x900000ff
	#check VC_SDCO__ADDRESS + 0x90, 0x900000ff
	poke VC_SDCO__ADDRESS + 0x90, 0x10000402
	poke VC_UNKe06000__ADDRESS + 0x68, 0x00000223
	poke VC_DCRC__ADDRESS + 0x4c, 0x00000223
	poke VC_UNKe06000__ADDRESS + 0x80, 0x00000030
	poke VC_UNKe06000__ADDRESS + 0x70, 0x00000001
	poke VC_DCRC__ADDRESS + 0x54, 0x00000001
	check VC_UNKe06000__ADDRESS + 0x78, 0x00000002
	check VC_DCRC__ADDRESS + 0x5c, 0x00000002
	poke VC_UNKe06000__ADDRESS + 0x80, 0x00000000
	check VC_SDCO__ADDRESS + 0x64, 0x00000003
	poke VC_SDCO__ADDRESS + 0x64, 0x00000014
	poke VC_SDCO__ADDRESS + 0x90, 0x3000ff0a
	check VC_SDCO__ADDRESS + 0x90, 0xb000ff0a
	poke VC_SDCO__ADDRESS + 0x64, 0x00000003
	check VC_SDCO__ADDRESS + 0x90, 0xb000ff0a
	poke VC_SDCO__ADDRESS + 0x90, 0x10000303
	check VC_SDCO__ADDRESS + 0x90, 0x90000303
	poke VC_SDCO__ADDRESS + 0x90, 0x00000005
	check VC_SDCO__ADDRESS + 0x90, 0x80010005
	check VC_SDCO__ADDRESS + 0x90, 0x80010005
	check VC_SDCO__ADDRESS + 0x90, 0x80010005
	poke VC_SDCO__ADDRESS + 0x90, 0x00000008
	check VC_SDCO__ADDRESS + 0x90, 0x80140008
	check VC_SDCO__ADDRESS + 0x90, 0x80140008
	check VC_SDCO__ADDRESS + 0x90, 0x80140008
	check VC_SDCO__ADDRESS + 0x0, 0x00218e42

	/* the second part of dram initialization is run from 0x60008000 */
	lea r0, draminit_start
	add r1, r0, 0x400
	mov r2, 0x60008000
copy_draminit_loop:
	ldb r3, (r0)
	stb r3, (r2)
	add r0, 1
	add r2, 1
	bne r0, r1, copy_draminit_loop

	mov r0, 0x60008000
	b r0

	/**
	 * Initializes the clocks for use with the mini uart and the OK led.
	 */
	.global initialize_gpio
initialize_gpio:
	push r6, lr
	/* configure TX and RX GPIO pins for Mini Uart function. */
	mov r1, VC_GPIO_FSEL1
	ld r0, (r1)
	and r0, ~(7<<12)
	or r0, 2<<12
	and r0, ~(7<<15)
	or r0, 2<<15
	/* configure LED pin */
	and r0, ~(7<<18)
	or r0, 1<<18
	st r0, (r1)

	mov r1, VC_GPIO_PUD
	mov r0, 0
	st r0, (r1)

	mov r0, 150
	bl delay

	mov r1, VC_GPIO_PUDCLK0
	mov r0, 1<<14|1<<15
	st r0, (r1)

	mov r0, 150
	bl delay

	mov r1, VC_GPIO_PUDCLK0
	mov r0, 0
	st r0, (r1);

	/* set up serial port */
	poke VC_AUX_ENABLES, 1
	poke VC_AUX_MU_IER_REG, 0
	poke VC_AUX_MU_CNTL_REG, 0
	poke VC_AUX_MU_LCR_REG, 3
	poke VC_AUX_MU_MCR_REG, 0
	poke VC_AUX_MU_IER_REG, 0
	poke VC_AUX_MU_IIR_REG, 0xc6
	.equ BAUD_REG, ((250000000/(115200*8))-1)
	poke VC_AUX_MU_BAUD_REG, BAUD_REG
	poke VC_AUX_MU_LCR_REG, 0x03
	poke VC_AUX_MU_CNTL_REG, 3

	pop r6, pc

	/**
	 * Waits for some cycles, the cycle count is passed in r0.
	 */
	.global delay
delay:
	mov r1, 0
L_delay_loop:
	add r1, 1
	cmp r1, r0
	bne L_delay_loop
	rts

	/**
	 * Sleeps using the system timer, the timer tick count is passed in r0.
	 */
	.global sleep
sleep:
	mov r2, VC_TIMER__ADDRESS + 0x4
	ld r1, (r2)
	add r1, r0
L_sleep_loop:
	ld r0, (r2)
	cmp r0, r1
	ble L_sleep_loop
	rts

draminit_start:

