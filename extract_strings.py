
import sys
import string

def extract_strings(filename, min_len=4):
    with open(filename, "rb") as f:
        content = f.read()
    
    # Define valid characters (printable ASCII)
    # 0x20 to 0x7E plus \t, \n, \r
    # We'll include these.
    
    result = ""
    for b in content:
        # Check if byte is printable ascii
        if (0x20 <= b <= 0x7E) or b in (0x09, 0x0A, 0x0D):
            result += chr(b)
        else:
            if len(result) >= min_len:
                yield result
            result = ""
            
    if len(result) >= min_len:
        yield result

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: extract_strings.py <filename>")
        sys.exit(1)
        
    found_any = False
    for s in extract_strings(sys.argv[1]):
        print(s)
        found_any = True
        
    if not found_any:
        # If no ASCII strings found, try UTF-16LE extraction?
        # For now, just exit.
        pass
