
#include "../bcm2835_emul.h"
#include "../vcregs.h"

#include <assert.h>
#include <stdio.h>
#include <string.h>

void gpio_init(struct bcm2835_emul *emul) {
	memset(&emul->gpio, 0, sizeof(emul->gpio));
}
uint32_t gpio_load(struct bcm2835_emul *emul, uint32_t address) {
	if (address >= VC_GPIO_FSEL0 && address <= VC_GPIO_FSEL5) {
		return emul->gpio.fsel[(address - VC_GPIO_FSEL0) >> 2];
	}
	/* TODO */
	assert(0 && "Not implemented!\n");
	(void)emul;
	(void)address;
}
void gpio_store(struct bcm2835_emul *emul, uint32_t address, uint32_t value) {
	int i;
	if (address >= VC_GPIO_FSEL0 && address <= VC_GPIO_FSEL5) {
		int reg_index = (address - VC_GPIO_FSEL0) >> 2;
		uint32_t old_value = emul->gpio.fsel[reg_index];
		emul->gpio.fsel[reg_index] = value;
		for (i = 0; i < 10; i++) {
			if ((value & 0x7) != (old_value & 0x7)) {
				printf("GPIO %d fsel %d\n", i + reg_index * 10, value & 0x7);
			}
			value >>= 3;
			old_value >>= 3;
		}
		return;
	} else if (address >= VC_GPIO_CLR0 && address <= VC_GPIO_CLR1) {
		int reg_index = (address - VC_GPIO_CLR0) >> 2;
		uint32_t old_value = emul->gpio.output_level[reg_index];
		emul->gpio.output_level[reg_index] &= ~value;
		for (i = 0; i < 32; i++) {
			if ((value & 0x1) == 1 && (old_value & 0x1) == 1) {
				printf("GPIO %d clear\n", i + reg_index * 32);
			}
			value >>= 1;
			old_value >>= 1;
		}
	} else if (address >= VC_GPIO_SET0 && address <= VC_GPIO_SET1) {
		int reg_index = (address - VC_GPIO_SET0) >> 2;
		uint32_t old_value = emul->gpio.output_level[reg_index];
		emul->gpio.output_level[reg_index] |= value;
		for (i = 0; i < 32; i++) {
			if ((value & 0x1) == 1 && (old_value & 0x1) == 0) {
				printf("GPIO %d set\n", i + reg_index * 32);
			}
			value >>= 1;
			old_value >>= 1;
		}
	} else {
		/* TODO */
		assert(0 && "Not implemented!\n");
		(void)emul;
		(void)address;
		(void)value;
	}
}

