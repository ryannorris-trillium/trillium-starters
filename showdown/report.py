"""Print a ranked report of the gradebook.

    python3 report.py            # everyone
    python3 report.py 3          # top 3
"""
import sys
from gradebook import load_students, rank, top


def format_row(position, student):
    """One report line: '1. Ada        84.5  B' (name padded to 10)."""
    return f"{position}. {student.name:<10}{student.average:.2f}  {student.letter}"


def report(students, n=None):
    """The full report as one string, one line per student."""
    chosen = rank(students) if n is None else top(students, n)
    lines = []
    for i, s in enumerate(chosen):
        lines.append(format_row(i, s))
    return "\n".join(lines)


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else None
    print(report(load_students("data/students.csv"), n))
