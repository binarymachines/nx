#!/usr/bin/env python

# generate records for hour dimension table


def line_array_generator(**kwargs):
    hour = 0
    while hour < 24:
        yield [hour, hour, str(hour)]
        hour += 1
