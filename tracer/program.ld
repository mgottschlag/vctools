
ENTRY(_start)
OUTPUT_FORMAT(binary)
SECTIONS
{
	. = 0x84000000;
	.text : AT(ADDR(.text) - 0x84000000) {
		_TEXT_START_ = .;
		*(.text)
		_TEXT_END_ = .;
	}

	.data : AT(ADDR(.data) - 0x84000000) {
		_DATA_START_ = .;
		*(.data)
		_DATA_END_ = .;
	}

	.bss : AT(ADDR(.bss) - 0x84000000) {
		_BSS_START_ = .;
		*(.bss)
		_BSS_END_ = .;
	}
}
