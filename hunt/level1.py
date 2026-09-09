# Level 1 of 6
# Nothing is broken here. Just run it.
# In the terminal, type this and press Enter:
#
#     python3 hunt/level1.py

print("Starting up.")

for job in ["terminal", "Python", "you"]:
    print("  checking", job, "... ok")

print("All three checks passed.")


# --- Ryan's checker. Do not edit below this line. ---
def code_word(numbers):
    return "".join(chr(n - 7) for n in numbers)


print()
print("CODE WORD 1:", code_word([90, 76, 93, 76, 85]))
print("Write it on your sheet, then open level2.py.")
