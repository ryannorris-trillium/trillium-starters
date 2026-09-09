# Level 2 of 6
# This file will not run. One character is missing.
# Run it and read the last line of the error. It names the character.
#
#     python3 hunt/level2.py

name = "hunter"
tries = 3

if tries > 0
    print(name, "has", tries, "tries left")
else:
    print(name, "is out of tries")


# --- Ryan's checker. Do not edit below this line. ---
def code_word(numbers):
    return "".join(chr(n - 7) for n in numbers)


print()
print("CODE WORD 2:", code_word([78, 76, 76, 90, 76]))
