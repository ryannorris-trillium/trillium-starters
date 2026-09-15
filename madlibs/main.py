"""Mad Libs. Ask for words, drop them into a story, print the story.

Run it:   python3 madlibs/main.py
Then open README.md in this folder for the five changes to make.
"""
import random

print("Give me some words. Do not think too hard.")
print()

animal = input("An animal: ")
place = input("A place: ")
verb = input("A verb ending in -ing: ")
number = input("A number: ")

print()
print("Here is your story.")
print()
print(f"Last night a {animal} was seen {verb} outside the {place}.")
print(f"Witnesses say it happened {number} times before anyone called for help.")
print(f"The {animal} is still missing.")
