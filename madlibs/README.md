# Mad Libs

Run it first:

```
python3 madlibs/main.py
```

Answer the four questions and read the story. Then make it yours, one step at a time. Run the program after every step. If it breaks, read the last line of the error.

## Step 1. Change the story

Rewrite the three `print(f"...")` lines so the story is your own. Keep the `{animal}` style blanks, or rename them to anything you want, as long as the name inside the braces matches a variable above.

Raise a hand when your story prints.

## Step 2. Add two more blanks

Add two more `input(...)` lines and use both new words in the story. A food, a celebrity, a color, a sound, anything.

## Step 3. Make the story longer

At least six lines of story. Every blank should be used at least once. Use one blank twice for effect.

## Step 4. Add a random ending

`random` is already imported. Make a list of three endings and let the computer pick one:

```python
endings = ["Nobody believed them.", "The mayor resigned.", "It was Tuesday."]
print(random.choice(endings))
```

Run it three times. You should not always get the same ending.

## Step 5. Make it repeat

Ask the player how many times they want the story, and print it that many times with a blank line between. Hint: `for i in range(int(number)):` and put the story lines inside the loop, indented.

## Step 6. Make it yours

Pick one:

- Let the player choose between two different stories with a menu (`input("Story 1 or 2? ")`).
- Refuse to continue until the player gives a real number (`while` loop).
- Save the finished story to a file (`open("story.txt", "w")`).

Then commit: Source Control, message `mad libs`, Commit, Sync Changes. When you are done, go work on your own project.
