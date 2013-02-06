
#include <iostream>
#include <string>
#include <sstream>

#include "vcdecoder.h"

int main() {
    char buffer[1024];
    std::string line;
    while (!std::cin.eof()) {
        std::getline(std::cin, line);
        size_t separator = line.find(": ");
        if (separator == std::string::npos) {
            continue;
        }
		std::istringstream parser(line);
		unsigned int address;
		parser >> std::hex >> address;
		char colon;
		parser >> colon;
		unsigned int value;
		parser >> std::hex >> value;
        vc_decode_register(address, buffer, sizeof(buffer));
        std::cout << buffer;
        std::cout << ": ";
        vc_decode_value(address, value, buffer, sizeof(buffer));
        std::cout << buffer << std::endl;
    }
    return 0;
}
