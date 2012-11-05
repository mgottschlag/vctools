
#ifndef VIDEOCORE_VCDECODER_H_INCLUDED
#define VIDEOCORE_VCDECODER_H_INCLUDED

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Converts an address to a readable string, using the available register or
 * register block names.
 *
 * Examples:
 *   0x7e002030 would be decoded as "VC_INTE_TABLE_PTR"
 *   0x7e002100 would be decided as "VC_INTE + 0x100" (unknown register)
 *
 * @param address Address of the register
 * @param buffer Buffer into which the result is placed
 * @param buffer_length Size of "buffer" in bytes
 * @return The number of bytes which were placed in the buffer - if this number
 *         is as large as buffer_length or larger, try again with a buffer which
 *         is at least one byte larger than this value
 */
int vc_decode_register(unsigned int address,
                       char *buffer,
                       unsigned int buffer_length);

/**
 * Parses and interprets a register and converts the result to a string.
 *
 * For bitfields with known sets of values, this will replace the value or parts
 * of it with the bitfield value names.
 *
 * Examples:
 *   0x7e007000u 0x00000123 would be decoded as
 *     "VC_DMA_CHAN_CS_ERROR_ERROR | 0x23"
 */
int vc_decode_value(unsigned int address,
                    unsigned int value,
                    char *buffer,
                    unsigned int buffer_length);

#ifdef __cplusplus
}
#endif

#endif
