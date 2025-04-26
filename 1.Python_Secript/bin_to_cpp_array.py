# bin_to_cpp_array.py

def bin_to_cpp_array(input_file, output_file, var_name):
    with open(input_file, 'rb') as f:
        data = f.read()

    with open(output_file, 'w') as f:
        f.write(f"std::vector<uint8_t> {var_name} = {{\n")
        for i, byte in enumerate(data):
            f.write(f"0x{byte:02X}, ")
            if (i + 1) % 12 == 0:
                f.write("\n")
        f.write("\n};\n")

if __name__ == "__main__":
    import sys
    if len(sys.argv) != 4:
        print("Usage: python bin_to_cpp_array.py <input.bin> <output.txt> <variable_name>")
        sys.exit(1)

    bin_to_cpp_array(sys.argv[1], sys.argv[2], sys.argv[3])
