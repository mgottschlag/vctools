
#include "../bcm2835_emul.h"
#include "../vcregs.h"

#include <assert.h>

void otp_init(struct bcm2835_emul *emul) {
	/* TODO */
	(void)emul;
}
uint32_t otp_load(struct bcm2835_emul *emul, uint32_t address) {
	if (address == VC_OTP0__ADDRESS + 0x0) {
		return 0x1020000a;
	}
	/* TODO */
	assert(0 && "Not implemented!\n");
	(void)emul;
}
void otp_store(struct bcm2835_emul *emul, uint32_t address, uint32_t value) {
	/* TODO */
	assert(0 && "Not implemented!\n");
	(void)emul;
	(void)address;
	(void)value;
}

