# Final AES Encrypted Shellcode Loader

Memory-only, fully encrypted, stealth shellcode execution  
Written by **Sayed Jihad Al Sayed**

---

## 🚀 Features

- AES-128-ECB encrypted shellcode
- Memory-only decryption and execution (no touching disk)
- Standalone `.exe` (no external files needed)
- Easy shellcode updates via auto-generated headers
- Fully bypasses basic AV signature scans
- Ready for red team and advanced lab simulations

---

## 📦 Project Structure

```
/Final_AES_Loader
|-- encrypt_shellcode_to_cpp.py    (Python script to encrypt shellcode and generate .h headers)
|-- final_loader.cpp               (Final C++ loader that decrypts and executes)
|-- encrypted_shellcode.h          (Auto-generated header: encrypted shellcode array)
|-- aes_key.h                      (Auto-generated header: AES encryption key array)
|-- shell.bin                      (Donut-generated shellcode input file)
```

---

## 🛠 Setup Instructions

### 1. Generate Shellcode

First, create real shellcode using **Donut**:

```
donut.exe -i implant.exe -a x64 -f1 -o shell.bin
```

- `implant.exe` = your payload
- `shell.bin` = output shellcode ready for memory execution

---

### 2. Encrypt Shellcode and Prepare Headers

Run the Python script:

```
python encrypt_shellcode_to_cpp.py
```

This generates:
- `encrypted_shellcode.h`
- `aes_key.h`

Both ready for direct C++ include!

---

### 3. Compile the Final Loader

Use MinGW64 g++:

```
g++ final_loader.cpp -o final_loader.exe -I/mingw64/include -L/mingw64/lib -lcryptopp -static
```

This creates `final_loader.exe`.

---

### 4. Execute the Loader

Simply run:

```
final_loader.exe
```

It will:
- Decrypt the embedded shellcode at runtime
- Allocate memory
- Copy decrypted shellcode
- Launch the shellcode thread in memory

---

## 📢 Important Notes

- **Crypto++** Library must be installed in your MinGW environment.
- **Python 3.x** required with `pycryptodome` installed (`pip install pycryptodome`).
- **Donut** recommended latest version from GitHub (`odzhan/donut`).
- **Antivirus** may still flag if not additionally obfuscated — recommended to encrypt and add garbage bytes for maximum stealth.

---

## 🧠 Future Enhancements

- Add garbage/random bytes between payloads
- Add Hotkey trigger (e.g., execute only on CTRL+SHIFT+L)
- Integrate staged payload downloads (memory-only)
- Manual PE injection instead of relying on Donut

---

## 👑 Author

**Sayed Jihad Al Sayed**  
Building stealth memory loaders for educational, red teaming, and ethical security research.

---

# 🔥 Stay stealthy. Stay smart. Stay learning.
