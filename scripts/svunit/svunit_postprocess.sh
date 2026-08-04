#!/bin/sh
# ******************************************************************************
#
# File: svunit_postprocess.sh
#
# Description:
#
#   This is a helper script that makes minor modifications to the shape of the
#   SVUnit build outputs so that they are compatible with the proprietary
#   ESnet compile/sim scripting infrastructure.
#
# ******************************************************************************

# Enhancement: Allow prefixing of files in source list to allow separate compile
#              and run directories.
# ----------------------------------------------
if [ $# -lt 1 ]; then TARGET_DIR=pwd
else                  TARGET_DIR=$1
fi

# Add ${TARGET_DIR} root to path of all references to files in current directory
sed -i "s:^\.:${TARGET_DIR}/&:" ${TARGET_DIR}/.svunit.f

# Add ${TARGET_DIR} to list of include directories
echo +incdir+${TARGET_DIR} >> ${TARGET_DIR}/.svunit.f

# Enhancement: Rename package files with _pkg suffix since these source files
#              are identified as packages and compiled first.
# ----------------------------------------------
# Create ephemeral copy of junit_xml package in run directory, including _pkg suffix
# (_pkg source files are identified as packages and compiled first)
cp ${SVUNIT_INSTALL}/svunit_base/junit-xml/junit_xml.sv ${TARGET_DIR}/junit_xml_pkg.sv

# Modify file list to refer to modified junit_xml
sed -i "s:^.*junit_xml.sv:${TARGET_DIR}/junit_xml_pkg.sv:g" ${TARGET_DIR}/.svunit.f

# Enhancement: Fix duplicate foreach loop variable in svunit_testsuite.sv.
#              Verilator 5.050+ rejects nested foreach loops that reuse the
#              same iteration variable (IEEE 1800 violation).
# ----------------------------------------------
cp ${SVUNIT_INSTALL}/svunit_base/svunit_testsuite.sv ${TARGET_DIR}/svunit_testsuite.sv
sed -i 's/junit_test_cases\[i\]/junit_test_cases[j]/g' ${TARGET_DIR}/svunit_testsuite.sv
python3 -c "
import re
text = open('${TARGET_DIR}/svunit_testsuite.sv').read()
# Each function body is bounded by its own scope; replace all [i] references
# within each foreach block with a unique variable name.
n = [0]
def repl_block(m):
    n[0] += 1
    return m.group(0).replace('[i]', '[k%d]' % n[0])
# Match from 'foreach' through the end of the statement or block:
# single-statement foreach (no begin..end) and begin..end blocks.
# Process the whole file one foreach-touching-list_of_testcases at a time.
# Strategy: replace [i] globally within each function by splitting on function boundaries.
parts = re.split(r'((?:local\s+)?function\b[^;]*;|endfunction\b|task\b[^;]*;|endtask\b)', text)
counter = 0
result = []
for part in parts:
    if 'list_of_testcases[i]' in part:
        counter += 1
        part = part.replace('list_of_testcases[i]', 'list_of_testcases[k%d]' % counter)
    result.append(part)
open('${TARGET_DIR}/svunit_testsuite.sv', 'w').write(''.join(result))
"
sed -i "s:^.*svunit_testsuite.sv:${TARGET_DIR}/svunit_testsuite.sv:g" ${TARGET_DIR}/.svunit.f

