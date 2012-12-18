
ENTRY(_start)
OUTPUT_FORMAT(binary)
SECTIONS
{
	.text : {
		_TEXT_START_ = .;
		*(.text)
		_TEXT_END_ = .;
	}

	.data : {
		_DATA_START_ = .;
		*(.data)
		_DATA_END_ = .;
	}

	.bss : {
		_BSS_START_ = .;
		*(.bss)
		_BSS_END_ = .;
	}

	.data.draminit : {
		obj/draminit_include.o(.data)
	}
}
