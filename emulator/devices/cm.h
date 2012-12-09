
#ifndef DEVICES_CM_H_INCLUDED
#define DEVICES_CM_H_INCLUDED

struct cm_clock_info {
	uint32_t divisor;
	uint32_t control;
};

enum {
	VPU_CLOCK,
	H264_CLOCK,
	V3D_CLOCK,
	CAM0_LP_CLOCK,
	DSI0_ESC_CLOCK,
	DSI1_ESC_CLOCK,
	DPI_CLOCK,
	GP0_CLOCK,
	GP1_CLOCK,
	HSM_CLOCK,
	ISP_CLOCK,
	PCM_CLOCK,
	PWM_CLOCK,
	SLIM_CLOCK,
	SMI_CLOCK,
	EMMC_CLOCK,
	TSENS_CLOCK,
	TIMER_CLOCK,
	UART_CLOCK,
	VEC_CLOCK,
	ARM_CLOCK,
	CLOCK_COUNT
};

struct cm_data {
	struct cm_clock_info clocks[CLOCK_COUNT];
};

#endif

