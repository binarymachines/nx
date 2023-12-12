#!/usr/bin/env python

# generate records for minute dimension table


def line_array_generator(**kwargs):
    minute = 0
    while minute < 60:
        yield [minute, minute, str(minute)]
        minute += 1
