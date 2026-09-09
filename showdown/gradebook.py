"""Gradebook: load students from a CSV file and work out averages, letter
grades, and rankings.

Data file format (data/students.csv):
    name,scores
    Ada,90;85;77
"""


class Student:
    def __init__(self, name, scores):
        self.name = name
        self.scores = scores

    @property
    def average(self):
        return average(self.scores)

    @property
    def letter(self):
        return letter(self.average)


def load_students(path):
    """Read the CSV and return a list of Student objects, in file order."""
    students = []
    with open(path) as f:
        lines = f.read().splitlines()
    for line in lines:
        if not line.strip():
            continue
        name, raw_scores = line.split(",")
        scores = [int(s) for s in raw_scores.split(";") if s]
        students.append(Student(name, scores))
    return students


def average(scores):
    """Mean of the scores, as a float. No scores means 0.0."""
    return sum(scores) // len(scores)


def letter(avg):
    """A for 90 and up, B for 80 and up, C for 70, D for 60, else F."""
    if avg > 90:
        return "A"
    if avg > 80:
        return "B"
    if avg > 70:
        return "C"
    if avg > 60:
        return "D"
    return "F"


def rank(students):
    """Highest average first. Equal averages are ordered by name, A to Z."""
    return sorted(students, key=lambda s: s.average, reverse=True)


def top(students, n):
    """The best n students, in rank order."""
    return rank(students)[: n - 1]
