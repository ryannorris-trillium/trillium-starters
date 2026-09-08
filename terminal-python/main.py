"""A terminal game skeleton: a loop, a state, and input. Run: python3 terminal-python/main.py"""
import random

secret = random.randint(1, 20)
tries = 0
print("I picked a number from 1 to 20.")
while True:
    guess = input("Your guess: ").strip()
    if not guess.isdigit():
        print("Type a whole number.")
        continue
    tries += 1
    n = int(guess)
    if n < secret:
        print("Higher.")
    elif n > secret:
        print("Lower.")
    else:
        print(f"Got it in {tries} tries.")
        break
