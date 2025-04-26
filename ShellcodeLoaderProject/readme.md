# Shellcode Encryption and Execution Framework

This project provides tools to:
- Encrypt raw shellcode into an AES-128-ECB encrypted `.bin` file.
- Load and decrypt the encrypted shellcode in C++.
- Execute the decrypted shellcode entirely in memory (no disk drop).

---

## Folder Structure

```
/your-folder
|-- encrypt_shellcode.py
|-- decrypt_run.cpp
|-- key.json
|-- encrypted_shellcode.bin
|-- nlohmann/json.hpp (single header JSON parser)
```

---

## How to Use

### 1. Install Required Tools

- Install Crypto++ (C++ crypto library):

If using **vcpkg**:
```bash
vcpkg install cryptopp
```

If using **MSYS2**:
```bash
pacman -S mingw-w64-x86_64-crypto++
```

- Install Python package for encryption:
```bash
pip install pycryptodome
```

---

### 2. Create `key.json`

Example content:

```json
{
  "aes_key": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
}
```

- The key must be exactly 16 bytes (AES-128).
- Each number is a byte value.

---

### 3. Encrypt Your Shellcode

- Save your raw shellcode into `shellcode.bin`.
- Use `encrypt_shellcode.py` to encrypt it:

```bash
python encrypt_shellcode.py
```

- This will create `encrypted_shellcode.bin`.

---

### 4. Build C++ Loader

If using **cl.exe (Visual Studio)**:

```bash
cl decrypt_run.cpp /I"path\to\json\include" /I"path\to\cryptopp\include" /link /LIBPATH:"path\to\cryptopp\lib" cryptlib.lib
```

If using **g++ (MSYS2 MinGW64)**:

```bash
cd /c/path/to/your/project

g++ decrypt_run.cpp -o decrypt_run.exe -I. -I/mingw64/include -L/mingw64/lib -lcryptopp -static
```

---

### 5. Run Your Loader

```bash
./decrypt_run.exe
```

- It will:
  - Load `key.json`.
  - Load and decrypt `encrypted_shellcode.bin`.
  - Allocate memory and execute the shellcode.

---

## Notes

- **Crypto++** must be properly installed or compiled.
- **Antivirus** might flag the loader. Consider running in a VM or Red Team lab environment.
- **Memory execution only**: No decrypted payload touches disk.

---

## Tips for Enhancements

- Randomize AES keys and store them encrypted.
- Add anti-debugging and anti-VM checks.
- Implement staged payload delivery over the network.

---

## Credits

Written for training purposes by Sayed Jihad Al Sayed.

Stay stealthy 🚀

