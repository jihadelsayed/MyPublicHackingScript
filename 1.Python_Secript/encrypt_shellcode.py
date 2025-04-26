# encrypt_shellcode.py

from Crypto.Cipher import AES
import json

def load_key(key_file):
    with open(key_file, 'r') as f:
        data = json.load(f)
    return bytes(data['aes_key'])

def encrypt_shellcode(input_file, output_file, key_file):
    key = load_key(key_file)

    with open(input_file, 'rb') as f:
        shellcode = f.read()

    cipher = AES.new(key, AES.MODE_ECB)

    padding_length = 16 - (len(shellcode) % 16)
    shellcode += bytes([padding_length]) * padding_length

    encrypted = cipher.encrypt(shellcode)

    with open(output_file, 'wb') as f:
        f.write(encrypted)

    print("[+] Shellcode encrypted and saved to", output_file)

if __name__ == "__main__":
    encrypt_shellcode("shellcode.bin", "encrypted_shellcode.bin", "key.json")
