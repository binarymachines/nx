#!/usr/bin/env python

# generate records for value bins


VALUE_BINS = {
    '0-10': '0 to 10',
    '10-49': '10 to 49',
    '50-99': '50 to 99',
    '100-999': '100 to 999',
    '>1000': 'over 1000'
}


def line_array_generator(**kwargs):    
    id = 1
    for abbrev, label in VALUE_BINS.items():
        yield [id, f"'{abbrev}'", f"'{label}'"]
        id += 1