# Showdown

A small gradebook program with several bugs in it, and a test file that
catches them. This is the folder Ryan uses for the coding-agent head-to-head.

Run the tests from inside this folder:

```
cd showdown
python3 -m unittest -v
```

Some tests fail. The job is to fix `gradebook.py` and `report.py` until
every test passes, without touching `test_gradebook.py` or `data/`.
