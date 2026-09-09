# Level 5 of 6
# Two functions are empty. Make each one return the right answer.
# Do not change the names or the inputs. Only change what is returned.
#
#     python3 hunt/level5.py


def area(w, h):
    """Return the area of a rectangle that is w wide and h tall.
    area(3, 4) should be 12."""
    return 0


def longest(a, b):
    """Return whichever word is longer, a or b.
    longest("cat", "walrus") should be "walrus".
    If they are the same length, return a."""
    return ""


# --- Ryan's checker. Do not edit below this line. ---
def code_word(numbers):
    return "".join(chr(n - 7) for n in numbers)


tests = [
    ("area(3, 4)", area(3, 4), 12),
    ("area(10, 10)", area(10, 10), 100),
    ("area(1, 7)", area(1, 7), 7),
    ('longest("cat", "walrus")', longest("cat", "walrus"), "walrus"),
    ('longest("elephant", "ox")', longest("elephant", "ox"), "elephant"),
    ('longest("red", "cat")', longest("red", "cat"), "red"),
]

passed = 0
for label, got, want in tests:
    if got == want:
        print("passed  ", label)
        passed = passed + 1
    else:
        print("failed  ", label, "gave", repr(got), "and should give", repr(want))

print()

if passed == len(tests):
    print("CODE WORD 5:", code_word([91, 79, 76]))
else:
    print(passed, "of", len(tests), "tests passed. Fix the failures and run it again.")
