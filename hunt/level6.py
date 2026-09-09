# Level 6 of 6
# Build a tiny text adventure. Two jobs.
#
# Job 1. Add rooms to ROOMS below. Rules the checker enforces:
#   - at least 3 rooms
#   - every room has a description of at least 15 characters
#   - every room has at least one exit
#   - every exit points at a room that actually exists
#   - every room can be reached from the first room by walking through exits
#
# Job 2. Finish move() so it returns the name of the room a direction leads to,
#        or None when there is no exit that way.
#
# When every check passes you get the code word and your game starts.
#
#     python3 hunt/level6.py

ROOMS = {
    "hall": {
        "description": "A cold stone hall. A door stands open to the north.",
        "exits": {"north": "library"},
    },
    "library": {
        "description": "",
        "exits": {},
    },
}


def move(room, direction):
    """Return the name of the room that `direction` leads to from `room`.
    Return None if there is no exit in that direction.

    ROOMS[room] is a dictionary with two keys, "description" and "exits".
    ROOMS[room]["exits"] is a dictionary like {"north": "library"}."""
    return None


# --- Ryan's checker. Do not edit below this line. ---
def code_word(numbers):
    return "".join(chr(n - 7) for n in numbers)


def structure_problems():
    problems = []
    if len(ROOMS) < 3:
        problems.append("ROOMS has " + str(len(ROOMS)) + " rooms. It needs at least 3.")
    for name in ROOMS:
        room = ROOMS[name]
        description = room.get("description", "")
        exits = room.get("exits", {})
        if len(description) < 15:
            problems.append(name + " needs a description of at least 15 characters.")
        if len(exits) < 1:
            problems.append(name + " needs at least one exit.")
        for direction in exits:
            if exits[direction] not in ROOMS:
                problems.append(
                    name + " has an exit " + direction + " to " + repr(exits[direction])
                    + ", which is not a room in ROOMS."
                )
    return problems


def unreachable_rooms():
    start = list(ROOMS)[0]
    seen = [start]
    queue = [start]
    while queue:
        here = queue.pop()
        for direction in ROOMS[here].get("exits", {}):
            there = ROOMS[here]["exits"][direction]
            if there in ROOMS and there not in seen:
                seen.append(there)
                queue.append(there)
    return [name for name in ROOMS if name not in seen]


def move_problems():
    problems = []
    start = list(ROOMS)[0]
    exits = ROOMS[start].get("exits", {})
    for direction in exits:
        want = exits[direction]
        got = move(start, direction)
        if got != want:
            problems.append(
                "move(" + repr(start) + ", " + repr(direction) + ") gave " + repr(got)
                + " and should give " + repr(want) + "."
            )
    if move(start, "flurble") is not None:
        problems.append(
            "move(" + repr(start) + ", 'flurble') should give None, because flurble "
            "is not an exit."
        )
    return problems


def play():
    here = list(ROOMS)[0]
    print()
    print("Type a direction to move. Type quit to stop.")
    while True:
        print()
        print(ROOMS[here]["description"])
        print("Exits:", ", ".join(ROOMS[here]["exits"]))
        command = input("> ").strip().lower()
        if command == "quit":
            print("Bye.")
            return
        if command == "":
            print("Type a direction, or quit.")
            continue
        there = move(here, command)
        if there is None:
            print("You cannot go that way.")
        else:
            here = there


found = structure_problems()
if not found:
    found = [name + " cannot be reached from " + list(ROOMS)[0] + "."
             for name in unreachable_rooms()]
if not found:
    found = move_problems()

if found:
    print("Not yet:")
    for problem in found:
        print("  -", problem)
    print()
    print("Fix those and run the file again.")
else:
    print("CODE WORD 6:", code_word([87, 89, 86, 81, 76, 74, 91, 86, 89]))
    play()
    print()
    print("CODE WORD 6 was:", code_word([87, 89, 86, 81, 76, 74, 91, 86, 89]))
