
#include "bcm2835_emul.h"
#include "vc4_emul.h"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <getopt.h>
#include <ctype.h>

int load_file(struct bcm2835_emul *emul,
              const char *filename,
              uint32_t target_address) {
	char buffer[512];
	size_t length;
	FILE *file = fopen(filename, "rb");
	if (file == NULL) {
		return -1;
	}
	do {
		length = fread(buffer, 1, 512, file);
		memory_fill(emul, target_address, buffer, length);
		target_address += 512;
	} while (length == 512);
	return 0;
}

const char *help = "Usage:\n\
    %s <options>\n\
Where <options> can contain the following:\n\
    -h          Prints this help.\n\
    -c IMAGE    Specifies the SD card image to be used.\n\
    -s PORT     Creates a local TCP server at PORT for uart data.\n\
    -r ROMFILE  Specifies a bootrom file which is placed at 0x60004000.\n\
    -b BOOTCODE Specifies a bootcode.bin file which is placed at 0x80000000.\n\
At least either bootrom or bootcode.bin is necessary.\n\
If a bootcode.bin file is specified, execution starts with this file. \
If not bootcode.bin file is present, the bootrom is used to load it from the \
SD card image.\n";

int main(int argc, char **argv) {
	int option;
	int i;

	const char *sdcard_file = NULL;
	const char *rom_file = NULL;
	const char *bootcode_file = NULL;

	int serial_port = -1;

	/* parse the command line arguments */
	while ((option = getopt(argc, argv, "c:s:r:b:h")) != -1) {
		switch (option) {
			case 'h':
				printf(help, argv[0]);
				return 0;
			case 'c':
				sdcard_file = optarg;
				break;
			case 's':
				serial_port = atoi(optarg);
				break;
			case 'r':
				rom_file = optarg;
				break;
			case 'b':
				bootcode_file = optarg;
				break;
			case '?':
				if (strchr("csrbh", optopt) != NULL) {
					fprintf(stderr, "Option -%c requires an argument.\n",
					        optopt);
				} else if (isprint(optopt)) {
					fprintf (stderr, "Unknown option \'-%c\'.\n", optopt);
				} else {
					fprintf (stderr, "Unknown option character \'\\x%x\'.\n",
					         optopt);
				}
				return -1;
			default:
				abort();
		}
	}
	if (optind != argc) {
		for (i = optind; i < argc; i++) {
			fprintf(stderr, "Error: Invalid argument %s\n", argv[i]);
		}
		printf(help, argv[0]);
		return -1;
	}
	if (rom_file == NULL && bootcode_file == NULL) {
		fprintf(stderr, "Error: Cannot boot without bootrom and bootcode.\n");
		printf(help, argv[0]);
		return -1;
	}
	/* create the emulator */
	struct bcm2835_emul *emul = calloc(1, sizeof(struct bcm2835_emul));
	emul->vc4 = vc4_emul_init(emul);
	memory_init(emul);
	if (mmc_init(emul, sdcard_file) != 0) {
		fprintf(stderr, "Error: Cannot initialize MMC.\n");
		return -1;
	}
	aux_init(emul);
	otp_init(emul);
	gpio_init(emul);
	timer_init(emul);
	cm_init(emul);
	inte_init(emul);
	/* load the boot code into memory */
	if (rom_file != NULL) {
		if (load_file(emul, rom_file, 0x60000000) != 0) {
			fprintf(stderr, "Could not open the bootrom file!\n");
			return -1;
		}
		vc4_emul_set_scalar_reg(emul->vc4, 31, 0x60000000);
	}
	if (bootcode_file != NULL) {
		if (load_file(emul, bootcode_file, 0x80000000) != 0) {
			fprintf(stderr, "Could not open the bootcode file!\n");
			return -1;
		}
		vc4_emul_set_scalar_reg(emul->vc4, 31, 0x80000000);
	}
	/* start the emulator */
	/* TODO */
	for (i = 0; i < 10000; i++) {
		printf("step: %08x\n", vc4_emul_get_scalar_reg(emul->vc4, 31));
		vc4_emul_step(emul->vc4);
	}
	return 0;
}

