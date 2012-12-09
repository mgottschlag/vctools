
#include "bcm2835_emul.h"
#include "vc4_emul.h"
#include "vcregs.h"

#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <stdio.h>

#define DRAM_SIZE (256 * 1024 * 1024)

struct device_region {
	uint32_t address;
	uint32_t size;
	uint32_t (*load)(struct bcm2835_emul *emul, uint32_t address);
	void (*store)(struct bcm2835_emul *emul, uint32_t address, uint32_t value);
};

static const struct device_region devices[] = {
	{ VC_OTP0__ADDRESS, VC_OTP0__SIZE, otp_load, otp_store },
	{ VC_ALTMMC__ADDRESS, VC_ALTMMC__SIZE, mmc_load, mmc_store },
	{ VC_AUX__ADDRESS, VC_AUX__SIZE, aux_load, aux_store },
	{ VC_GPIO__ADDRESS, VC_GPIO__SIZE, gpio_load, gpio_store },
	{ VC_TIMER__ADDRESS, VC_TIMER__SIZE, timer_load, timer_store },
	{ VC_CM__ADDRESS, VC_CM__SIZE, cm_load, cm_store },
};

#define DEVICE_COUNT (sizeof(devices) / sizeof(devices[0]))

static int is_in_region(uint32_t address,
                        uint32_t size,
                        uint32_t start,
                        uint32_t end) {
	if (address < start || address + size > end) {
		return 0;
	} else {
		return 1;
	}
}

void memory_init(struct bcm2835_emul *emul) {
	emul->dram = malloc(DRAM_SIZE);
	/* ROM and bootram (actually just cache?) are stored here */
	emul->bootram = malloc(0x8800);
}

void memory_fill(struct bcm2835_emul *emul,
                 uint32_t address,
                 const void *data,
                 size_t size) {
	if (is_in_region(address, size, 0x60000000, 0x60008800)) {
		char *dest = emul->bootram + (address - 0x60000000);
		memcpy(dest, data, size);
	} else if (is_in_region(address & 0x3fffffff, size, 0x0, DRAM_SIZE)) {
		char *dest = emul->dram + (address & 0x3fffffff);
		memcpy(dest, data, size);
	} else {
		assert(0 && "memory_fill: Invalid memory area!");
	}
}

uint32_t vc4_emul_load(void *user_data,
                       uint32_t address,
                       int size) {
	struct bcm2835_emul *emul = user_data;
	uint32_t value;
	unsigned int i;
	if (is_in_region(address, size, 0x60000000, 0x60008800)) {
		value = *(uint32_t*)(emul->bootram + (address & 0xffff));
	} else if (is_in_region(address & 0x3fffffff, size, 0x0, DRAM_SIZE)) {
		value = *(uint32_t*)(emul->dram + (address & 0x3fffffff));
	} else {
		/* device registers */
		if (size == 4 && (address & 3) == 0) {
			for (i = 0; i < DEVICE_COUNT; i++) {
				if (address >= devices[i].address &&
						address <= devices[i].address + devices[i].size) {
					uint32_t value = devices[i].load(emul, address);
					printf("MMIO(R, 4) %08x => %08x\n", address, value);
					return value;
				}
			}
		}
		/* TODO: interrupt number? */
		vc4_emul_interrupt(emul->vc4, 0, "Invalid load address.");
	}
	/*printf("%08x\n", value);*/
	value &= 0xffffffff >> ((4 - size) * 8);
	return value;
}

void vc4_emul_store(void *user_data,
                    uint32_t address,
                    int size,
                    uint32_t value) {
	struct bcm2835_emul *emul = user_data;
	char *dest;
	unsigned int i;
	if (is_in_region(address, size, 0x60000000, 0x60008800)) {
		dest = emul->bootram + (address & 0xffff);
	} else if (is_in_region(address & 0x3fffffff, size, 0x0, DRAM_SIZE)) {
		dest = emul->dram + (address & 0x3fffffff);
	} else {
		/* device registers */
		if (size == 4 && (address & 3) == 0) {
			for (i = 0; i < DEVICE_COUNT; i++) {
				if (address >= devices[i].address &&
						address <= devices[i].address + devices[i].size) {
					printf("MMIO(W, 4) %08x <= %08x\n", address, value);
					return devices[i].store(emul, address, value);
				}
			}
		}
		/* TODO: interrupt number? */
		vc4_emul_interrupt(emul->vc4, 0, "Invalid store address.");
	}
	switch (size) {
		case 1:
			*(uint8_t*)dest = value;
			break;
		case 2:
			*(uint16_t*)dest = value;
			break;
		case 4:
			*(uint32_t*)dest = value;
			break;
		default:
			assert(0 && "Invalid store size.");
	}
}

