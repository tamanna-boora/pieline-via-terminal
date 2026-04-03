import random
import struct

def to_hex(val):
    return format(val & 0xFFFFFFFF, '08x')

def generate_tests(filename, num_tests=100):
    with open(filename, 'w') as f:
        # Add a few manual edge cases first
        edge_cases = [
            (10, 5), (100, 7), (-100, 7), (50, 0), 
            (0x80000000, 0xFFFFFFFF), (0xFFFFFFFF, 0xFFFFFFFF)
        ]
        
        for i in range(num_tests + len(edge_cases)):
            if i < len(edge_cases):
                a_int, b_int = edge_cases[i]
                # Ensure they stay in 32-bit range
                a_int &= 0xFFFFFFFF 
                if a_int > 0x7FFFFFFF: a_int -= 0x100000000
                b_int &= 0xFFFFFFFF
                if b_int > 0x7FFFFFFF: b_int -= 0x100000000
            else:
                a_int = random.randint(-2147483648, 2147483647)
                b_int = random.randint(-2147483648, 2147483647)

            # MUL (Signed 32-bit truncated)
            exp_mul = (a_int * b_int) & 0xFFFFFFFF
            
            # DIV (Signed 32-bit truncated)
            if b_int == 0:
                exp_q = 0xFFFFFFFF
                exp_r = a_int & 0xFFFFFFFF
            elif a_int == -2147483648 and b_int == -1: # RISC-V Overflow rule
                exp_q = 0x80000000
                exp_r = 0
            else:
                exp_q = int(a_int / b_int) & 0xFFFFFFFF
                exp_r = (a_int - (int(a_int / b_int) * b_int)) & 0xFFFFFFFF

            f.write(f"{to_hex(a_int)} {to_hex(b_int)} {to_hex(exp_mul)} {to_hex(exp_q)} {to_hex(exp_r)}\n")

if __name__ == "__main__":
    generate_tests("math_gold.txt", 100)
    print("Successfully generated math_gold.txt with 106 cases.")
