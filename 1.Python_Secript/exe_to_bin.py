# save as exe_to_bin.py

def convert_to_bin(input_file, output_file):
    with open(input_file, 'rb') as f_in:
        data = f_in.read()

    with open(output_file, 'wb') as f_out:
        f_out.write(data)

if __name__ == "__main__":
    import sys

    if len(sys.argv) != 3:
        print("Usage: python exe_to_bin.py <input_exe_or_dll> <output_bin>")
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2]

    convert_to_bin(input_path, output_path)
    print(f"[+] Saved binary shellcode to {output_path}")
