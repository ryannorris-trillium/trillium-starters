# Level 3 of 6
# Run it first. The terminal tells you what is wrong.
# Then change ONE number in the settings block so both checks pass.
#
#     python3 hunt/level3.py

# --- settings ---

crate_count = 3

# --- end of settings ---


# --- Ryan's checker. Do not edit below this line. ---
def code_word(numbers):
    return "".join(chr(n - 7) for n in numbers)


big_enough = crate_count > 50
round_number = crate_count % 10 == 0

print("crate_count is", crate_count)
print("  check A, more than 50:      ", "passed" if big_enough else "failed")
print("  check B, a multiple of ten: ", "passed" if round_number else "failed")
print()

if big_enough and round_number:
    print("CODE WORD 3:", code_word([79, 72, 93, 76]))
else:
    print("Change crate_count and run the file again.")
