#!/usr/bin/env python3

# check_timing.py
# 
# This script accepts a JSON file describing a summary of a Vivado build,
# and checks timing results against specified thresholds.
# 
# The check returns PASS (with return code 0) if all timing values in the
# design are better than the associated thresholds;
# it returns FAIL (with return code 1) if one or more of the timing values
# is worse than the associated threshold.
# 
# The script also generates a JUnit summary of the timing check for reporting purposes.

import argparse
import os
import sys
import json
import xml.etree.ElementTree as ET

parser = argparse.ArgumentParser(
        description = '''
            This script accepts a JSON file describing a summary of a Vivado build,
            and checks timing results against specified thresholds.
        '''
)
parser.add_argument('summary_json_file', type=argparse.FileType('r'))
parser.add_argument('--wns-min', type=float, default=0.0)
parser.add_argument('--tns-min', type=float, default=0.0)
parser.add_argument('--whs-min', type=float, default=0.0)
parser.add_argument('--ths-min', type=float, default=0.0)
parser.add_argument('--wpws-min', type=float, default=0.0)
parser.add_argument('--tpws-min', type=float, default=0.0)
parser.add_argument('--junit-xml-file', default='junit.xml')
args = parser.parse_args();

# Load JSON summary
data = json.load(args.summary_json_file)

# Create JUnit XML timing summary
ts_name = data['name'] + '.timing'
junit_root = ET.Element('testsuites')
junit_testsuite = ET.SubElement(junit_root, 'testsuite', name=ts_name)

# Timing requirements
reqs = {
        'WNS(ns)': args.wns_min,
        'TNS(ns)': args.tns_min,
        'WHS(ns)': args.whs_min,
        'THS(ns)': args.ths_min,
        'WPWS(ns)': args.wpws_min,
        'TPWS(ns)': args.tpws_min
}

# Check results against requirements
errors = 0
for k, v in data['timing'].items():
    junit_testcase = ET.SubElement(junit_testsuite, 'testcase', classname=ts_name, name=k, result=v)
    if k in reqs and float(v) < reqs[k]:
        errors += 1
        msg = k + ' of ' + v + ' does not meet requirement (' + str(reqs[k]) + ')'
        print(msg)
        junit_failure = ET.SubElement(junit_testcase, 'failure', message=msg)

# Pretty-print output, if Python version supports it
try:
    ET.indent(junit_root)
except AttributeError:
    pass

# Print JUnit XML to file
junit_doc = ET.ElementTree(junit_root)
junit_doc.write(args.junit_xml_file)

if errors > 0:
    print(data['name'] + ': Timing check FAILED. See "' + os.path.abspath(args.junit_xml_file) + '" for details.')
    sys.exit(1)
else:
    print(data['name'] + ': Timing check PASSED.')
    sys.exit(0)
