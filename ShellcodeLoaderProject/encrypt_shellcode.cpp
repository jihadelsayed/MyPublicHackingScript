#include <iostream>
#include <fstream>
#include <vector>
#include <cryptopp/aes.h>
#include <cryptopp/modes.h>
#include <cryptopp/filters.h>

int main() {
    using namespace CryptoPP;

    byte key[AES::DEFAULT_KEYLENGTH] = {
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
        0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F
    };

    std::ifstream input("shellcode.bin", std::ios::binary);
    std::vector<byte> shellcode((std::istreambuf_iterator<char>(input)), {});

    ECB_Mode<AES>::Encryption encryptor;
    encryptor.SetKey(key, sizeof(key));

    std::string ciphertext;
    StringSource(shellcode.data(), shellcode.size(), true,
        new StreamTransformationFilter(encryptor, new StringSink(ciphertext)));

    std::ofstream output("encrypted_shellcode.bin", std::ios::binary);
    output.write(ciphertext.data(), ciphertext.size());

    std::cout << "Shellcode encrypted.\n";
    return 0;
}
