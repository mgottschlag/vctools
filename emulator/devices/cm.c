
#include "../bcm2835_emul.h"
#include "../vcregs.h"

#include <assert.h>
#include <string.h>

static const uint32_t clock_address[] = {
	VC_CM_VPU_CTL,
	VC_CM_H264_CTL,
	VC_CM_V3D_CTL,
	VC_CM_CAM0_LP_CTL,
	VC_CM_DSI0_ESC_CTL,
	VC_CM_DSI1_ESC_CTL,
	VC_CM_DPI_CTL,
	VC_CM_GP_CTL(0),
	VC_CM_GP_CTL(1),
	VC_CM_HSM_CTL,
	VC_CM_ISP_CTL,
	VC_CM_PCM_CTL,
	VC_CM_PWM_CTL,
	VC_CM_SLIM_CTL,
	VC_CM_SMI_CTL,
	VC_CM_eMMC_CTL,
	VC_CM_TSENS_CTL,
	VC_CM_TIME_CTL,
	VC_CM_UART_CTL,
	VC_CM_VEC_CTL,
	VC_CM_ARM_CTL,
};

void cm_init(struct bcm2835_emul *emul) {
	memset(&emul->cm, 0, sizeof(emul->cm));
}
uint32_t cm_load(struct bcm2835_emul *emul, uint32_t address) {
	int i;
	for (i = 0; i < CLOCK_COUNT; i++) {
		if (address == clock_address[i]) {
			return emul->cm.clocks[i].control;
		}
		if (address == clock_address[i] + 4) {
			return emul->cm.clocks[i].divisor;
		}
	}
	assert(0 && "Unknown CM register!\n");
}
void cm_store(struct bcm2835_emul *emul, uint32_t address, uint32_t value) {
	int i;
	/* all registers need the password field */
	if ((value >> 24) != 0x5a) {
		return;
	}
	for (i = 0; i < CLOCK_COUNT; i++) {
		if (address == clock_address[i]) {
			/* TODO */
			emul->cm.clocks[i].control = value;
			return;
		}
		if (address == clock_address[i] + 4) {
			/* TODO */
			emul->cm.clocks[i].divisor = value;
			return;
		}
	}
	assert(0 && "Unknown CM register!\n");
}

