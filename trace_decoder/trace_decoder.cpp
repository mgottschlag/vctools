
#include <iostream>
#include <string>
#include <sstream>

#include "vcdecoder.h"

int main() {
    char buffer[1024];
    std::string line;
    while (!std::cin.eof()) {
        std::getline(std::cin, line);
        size_t mmio = line.find("MMIO");
        size_t separator = line.find(": ");
        if (separator == std::string::npos || mmio == std::string::npos) {
            continue;
        }
        std::cout << line.substr(0, separator + 2);
        std::istringstream parser(line.substr(separator + 2));
        unsigned int address;
        parser >> std::hex >> address;
        std::string direction;
        parser >> direction;
        unsigned int value;
        parser >> std::hex >> value;
        vc_decode_register(address, buffer, sizeof(buffer));
        std::cout << buffer;
        std::cout << " " << direction << " ";
        vc_decode_value(address, value, buffer, sizeof(buffer));
        std::cout << buffer << std::endl;
    }
    return 0;
}
