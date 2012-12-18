
#ifndef BCM2835_EMUL_H_INCLUDED
#define BCM2835_EMUL_H_INCLUDED

#include <stdint.h>
#include <stddef.h>

#include "devices/cm.h"
#include "devices/gpio.h"
#include "devices/inte.h"

struct vc4_emul;

struct bcm2835_emul {
	struct vc4_emul *vc4;

	char *dram;
	char *bootram;

	struct cm_data cm;
	struct gpio_data gpio;
	struct inte_data inte;
};

void memory_init(struct bcm2835_emul *emul);
void memory_fill(struct bcm2835_emul *emul,
                 uint32_t address,
                 const void *data,
                 size_t size);

int mmc_init(struct bcm2835_emul *emul, const char *sdcard_file);
uint32_t mmc_load(struct bcm2835_emul *emul, uint32_t address);
void mmc_store(struct bcm2835_emul *emul, uint32_t address, uint32_t value);

void aux_init(struct bcm2835_emul *emul);
uint32_t aux_load(struct bcm2835_emul *emul, uint32_t address);
void aux_store(struct bcm2835_emul *emul, uint32_t address, uint32_t value);

void otp_init(struct bcm2835_emul *emul);
uint32_t otp_load(struct bcm2835_emul *emul, uint32_t address);
void otp_store(struct bcm2835_emul *emul, uint32_t address, uint32_t value);

void gpio_init(struct bcm2835_emul *emul);
uint32_t gpio_load(struct bcm2835_emul *emul, uint32_t address);
void gpio_store(struct bcm2835_emul *emul, uint32_t address, uint32_t value);

void timer_init(struct bcm2835_emul *emul);
uint32_t timer_load(struct bcm2835_emul *emul, uint32_t address);
void timer_store(struct bcm2835_emul *emul, uint32_t address, uint32_t value);

void cm_init(struct bcm2835_emul *emul);
uint32_t cm_load(struct bcm2835_emul *emul, uint32_t address);
void cm_store(struct bcm2835_emul *emul, uint32_t address, uint32_t value);

void inte_init(struct bcm2835_emul *emul);
uint32_t inte_load(struct bcm2835_emul *emul, uint32_t address);
void inte_store(struct bcm2835_emul *emul, uint32_t address, uint32_t value);

#endif

