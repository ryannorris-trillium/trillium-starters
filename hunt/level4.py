# Level 4 of 6
# This loop is supposed to print exactly 7 stars. It does not.
# Change the numbers in range() until it does.
#
#     python3 hunt/level4.py

stars = 0

for i in range(1, 7):
    print("*")
    stars = stars + 1


# --- Ryan's checker. Do not edit below this line. ---
def code_word(numbers):
    return "".join(chr(n - 7) for n in numbers)


print()
print("You printed", stars, "stars.")
print()

if stars == 7:
    print("CODE WORD 4:", code_word([90, 91, 86, 83, 76, 85]))
else:
    print("It needs to be 7. Change the loop and run the file again.")
