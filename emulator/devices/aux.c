
#include "../bcm2835_emul.h"
#include "../vcregs.h"

#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>

void aux_init(struct bcm2835_emul *emul) {
	/* TODO */
	(void)emul;
}
uint32_t aux_load(struct bcm2835_emul *emul, uint32_t address) {
	if (address == VC_AUX_MU_LSR_REG) {
		return VC_AUX_MU_LSR_REG_TX_IDLE | VC_AUX_MU_LSR_REG_TX_EMPTY;
	} else {
		printf("AUX load %08x\n", address);
		/* TODO */
		assert(0 && "Not implemented!\n");
		(void)emul;
	}
}
void aux_store(struct bcm2835_emul *emul, uint32_t address, uint32_t value) {
	if (address == VC_AUX_MU_IO_REG) {
		if (isprint(value & 0xff)) {
			printf("UART \'%c\'\n", value & 0xff);
		} else {
			printf("UART 0x%02x\n", value & 0xff);
		}
	} else {
		/* TODO */
		assert(0 && "Not implemented!\n");
		(void)emul;
	}
}

