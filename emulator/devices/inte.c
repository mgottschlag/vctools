
#include "../bcm2835_emul.h"
#include "../vcregs.h"

#include <assert.h>
#include <stdio.h>
#include <string.h>

void inte_init(struct bcm2835_emul *emul) {
	memset(&emul->inte, 0, sizeof(emul->inte));
}
uint32_t inte_load(struct bcm2835_emul *emul, uint32_t address) {
	/* TODO */
	assert(0 && "Not implemented!\n");
	(void)emul;
	(void)address;
}
void inte_store(struct bcm2835_emul *emul, uint32_t address, uint32_t value) {
	if (address == VC_INTE_TABLE_PTR) {
		printf("INTE ivt %08x\n", value);
		emul->inte.ivt_address = value;
	} else {
		/* TODO */
		assert(0 && "Not implemented!\n");
	}
}

uint32_t vc4_emul_get_ivt_address(void *user_data) {
	struct bcm2835_emul *emul = user_data;
	return emul->inte.ivt_address;
}

