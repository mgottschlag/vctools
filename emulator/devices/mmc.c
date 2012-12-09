
#include "../bcm2835_emul.h"
#include "../vcregs.h"

#include <assert.h>

int mmc_init(struct bcm2835_emul *emul, const char *sdcard_file) {
	/* TODO */
	(void)emul;
	(void)sdcard_file;
	return 0;
}
uint32_t mmc_load(struct bcm2835_emul *emul, uint32_t address) {
	/* TODO */
	assert(0 && "Not implemented!\n");
	(void)emul;
	(void)address;
}
void mmc_store(struct bcm2835_emul *emul, uint32_t address, uint32_t value) {
	/* TODO */
	assert(0 && "Not implemented!\n");
	(void)emul;
	(void)address;
	(void)value;
}

