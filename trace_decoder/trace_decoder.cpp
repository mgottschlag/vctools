
#include <iostream>
#include <string>
#include <sstream>

#include "vcdecoder.h"

void decodeOldTracer(const std::string &line) {
    char buffer[1024];
    size_t separator = line.find(": ");
    if (separator == std::string::npos) {
        return;
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

void decode(const std::string &line, bool store) {
    char buffer[1024];
    std::string pc = line.substr(2, 8);
    std::stringstream addressStr;
    addressStr << std::hex << line.substr(11, 8);
    unsigned int address;
    addressStr >> address;
    std::stringstream valueStr;
    valueStr << std::hex << line.substr(19, 8);
    unsigned int value;
    valueStr >> value;
    std::cout << "MMIO(";
    if (store) {
        std::cout << "W";
    } else {
        std::cout << "R";
    }
    std::cout << ", 4, 0x" << pc << "): ";
    vc_decode_register(address, buffer, sizeof(buffer));
    std::cout << buffer;
    if (store) {
        std::cout << " <= ";
    } else {
        std::cout << " => ";
    }
    vc_decode_value(address, value, buffer, sizeof(buffer));
    std::cout << buffer << std::endl;
}

int main() {
    std::string line;
    while (!std::cin.eof()) {
        std::getline(std::cin, line);
        if (line.find("MMIO") != std::string::npos) {
            decodeOldTracer(line);
        } else if (line.substr(0, 1) == "r") {
            decode(line, false);
        } else if (line.substr(0, 1) == "w") {
            decode(line, true);
        } else if (line.find("interrupt") != std::string::npos) {
            std::cout << line << std::endl;
        }
    }
    return 0;
}

