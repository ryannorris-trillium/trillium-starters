# Mad Libs

Run it first:

```
python3 madlibs/main.py
```

Answer the four questions and read the story. Then make it yours, one step at a time. Run the program after every step. If it breaks, read the last line of the error.

## Step 1. Change the story

Rewrite the three `print(f"...")` lines so the story is your own. Keep the `{animal}` style blanks, or rename them to anything you want, as long as the name inside the braces matches a variable above.

## Step 2. Add two more blanks

Add two more `input(...)` lines and use both new words in the story. A food, a celebrity, a color, a sound, anything.

## Step 3. Add a random ending

`random` is already imported. Make a list of three endings and let the computer pick one:

```python
endings = ["Nobody believed them.", "The mayor resigned.", "It was Tuesday."]
print(random.choice(endings))
```

Run it three times. You should not always get the same ending.

## Step 4. Give the story a choice

Ask one yes-or-no question before the story, then let the answer change what gets printed:

```python
friendly = input("Is the animal friendly? yes or no: ")

if friendly == "yes":
    print(f"The {animal} waved at everyone.")
else:
    print(f"The {animal} did not wave at anyone.")
```

Put it wherever it fits in your story. The lines under `if` and under `else` must be indented. Try answering something that is not yes or no and see which branch runs.

Then commit: Source Control, message `mad libs`, Commit, Sync Changes. When you are done, go work on your own project.
