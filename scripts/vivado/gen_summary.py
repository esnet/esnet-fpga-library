#!/usr/bin/env python3

# gen_summary.py
# 
# This script parses standard Vivado build reports and synthesizes
# a concise summary of important parameters (in JSON) format.

import argparse
import os
import sys
import json

parser = argparse.ArgumentParser(
        description = '''
            This script parses standard Vivado build reports and synthesizes
            a concise summary of important parameters (in JSON) format.
        '''
)
parser.add_argument('timing_summary_report', type=argparse.FileType('r'))
parser.add_argument('--build-name', default='build')
parser.add_argument('--summary-json-file', default='summary.json')
args = parser.parse_args();

# Parse timing summary
lines = args.timing_summary_report.readlines()

ts = {}
line_idx = 0
while line_idx < len(lines)-6:
    line = lines[line_idx]
    if 'Design Timing Summary' in line:
       ts_line = lines[line_idx+6]
       ts_fields = ts_line.split()
       ts['WNS(ns)'] = ts_fields[0]
       ts['TNS(ns)'] = ts_fields[1]
       ts['TNS Failing Endpoints'] = ts_fields[2]
       ts['TNS Total Endpoints'] = ts_fields[3]
       ts['WHS(ns)'] = ts_fields[4]
       ts['THS(ns)'] = ts_fields[5]
       ts['THS Failing Endpoints'] = ts_fields[6]
       ts['THS Total Endpoints'] = ts_fields[7]
       ts['WPWS(ns)'] = ts_fields[8]
       ts['TPWS(ns)'] = ts_fields[9]
       ts['TPWS Failing Endpoints'] = ts_fields[10]
       ts['TPWS Total Endpoints'] = ts_fields[11]
       break
    line_idx += 1

args.timing_summary_report.close()

# Synthesize design summary
summary = {'name': args.build_name, 'timing': ts}

# Write summary to JSON
with open(args.summary_json_file, 'w') as f:
    json.dump(summary, f, indent='\t')
