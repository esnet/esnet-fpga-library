#!/bin/sh
# ==============================================================================
#  NOTICE: This computer software was prepared by The Regents of the
#  University of California through Lawrence Berkeley National Laboratory
#  and Jonathan Sewter hereinafter the Contractor, under Contract No.
#  DE-AC02-05CH11231 with the Department of Energy (DOE). All rights in the
#  computer software are reserved by DOE on behalf of the United States
#  Government and the Contractor as provided in the Contract. You are
#  authorized to use this computer software for Governmental purposes but it
#  is not to be released or distributed to the public.
#
#  NEITHER THE GOVERNMENT NOR THE CONTRACTOR MAKES ANY WARRANTY, EXPRESS OR
#  IMPLIED, OR ASSUMES ANY LIABILITY FOR THE USE OF THIS SOFTWARE.
#
#  This notice including this sentence must appear on any copies of this
#  computer software.
# ==============================================================================

# ******************************************************************************
#
# File: svunit_vivado_workaround.sh
#
# Description:
#
#   This script provides (hopefully) temporary workarounds to enable SVUnit
#   compatibility with Vivado Simulator.
#
#   ISSUE 1:
#
#   Native SVUnit report() method makes use of following SystemVerilog construct
#   to determine count of passing test suites:
#
#   'list_of_suites.find() with (item.get_results() == PASS)'
#
#   This construct is not handled by Vivado (as of v2022.2), with a tool error
#   as the unfortunate result:
#
#   "FATAL_ERROR: Vivado Simulator kernel has discovered an exceptional condition
#   from which it cannot recover. Process will terminate."
#
#   The workaround below makes ephemeral copies of the svunit_testsuite.sv
#   and svunit_testrunner.sv source files, and replaces the problematic iterator
#   with a less elegant but simpler 'iterate over all elements of the list and
#   check for PASS' construction.
#
#   This workaround needs to remain in place until the native SVUnit syntax is
#   properly supported by Vivado.
#
#   ISSUE 2:
#
#   As of Vivado 2022.2, the SVUnit XmlElement class emits garbage as closing tags.
#   This appears to be due to corruption of the 'tag' member variable.
#
#   The tag member variable is defined as local const string (and therefore
#   should be immutable) but ends up being corrupted between emission of the
#   start and end tags in the 'as_string_with_indent' function. Experimentation
#   suggests that the corruption happens as a result of the call to the
#   'get_start_tag_contents' function, where the tag variable is inspected but
#   not modified.
#
#   As a workaround, the 'get_start_tag_contents' function no longer inspects
#   the tag variable, and the tag is emitted directly within the
#   'as_string_with_indent` function.
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

# ISSUE 1 Resolution
# ------------------------
# Create ephemeral copies of svunit_testsuite.sv and svunit_testrunner in run directory.
cp ${SVUNIT_INSTALL}/svunit_base/svunit_testsuite.sv ${TARGET_DIR}/svunit_testsuite__vivado.sv
cp ${SVUNIT_INSTALL}/svunit_base/svunit_testrunner.sv ${TARGET_DIR}/svunit_testrunner__vivado.sv

# Replace 'find() with' list iterator in report() method with construct supported by Vivado Simulator
perl -0777 -i -pe 's/begin\n.*list_of_testcases.find().*\n\s+pass_cnt = match\.size\(\);\n\s+end/pass_cnt = 0;\n  foreach (list_of_testcases[i])\n    if (list_of_testcases[i].get_results() == PASS) pass_cnt++;\n/g' ${TARGET_DIR}/svunit_testsuite__vivado.sv
perl -0777 -i -pe 's/begin\n.*list_of_suites.find().*\n\s+pass_cnt = match\.size\(\);\n\s+end/pass_cnt = 0;\n  foreach (list_of_suites[i])\n\    if (list_of_suites[i].get_results() == PASS) pass_cnt++;\n/g' ${TARGET_DIR}/svunit_testrunner__vivado.sv

# Create ephemeral copy of svunit_pkg.sv in run directory
cp ${SVUNIT_INSTALL}/svunit_base/svunit_pkg.sv ${TARGET_DIR}/svunit_pkg.sv

# Modify svunit_pkg to refer to modified versions of svunit_testsuite and svunit_testrunner classes
sed -i 's:svunit_testsuite:\svunit_testsuite__vivado:'   ${TARGET_DIR}/svunit_pkg.sv
sed -i 's:svunit_testrunner:\svunit_testrunner__vivado:' ${TARGET_DIR}/svunit_pkg.sv

# Modify file list to refer to modified svunit_pkg
sed -i "s:^.*svunit_pkg.sv:${TARGET_DIR}/svunit_pkg.sv:g" ${TARGET_DIR}/.svunit.f

# Remove direct references to ephemeral source files; should be referenced
# in package file only to avoid compile errors
sed -i '/^\.svunit_testsuite\.sv.*$/d'  ${TARGET_DIR}/.svunit.f
sed -i '/^\.svunit_testrunner\.sv.*$/d' ${TARGET_DIR}/.svunit.f

# ISSUE 2 Resolution
# ------------------------
# Create ephemeral copy of XmlElement.svh in run directory.
cp ${SVUNIT_INSTALL}/svunit_base/junit-xml/XmlElement.svh ${TARGET_DIR}/XmlElement__vivado.svh

# Modify XmlElement class
## Change 'get_start_tag_contents' so that it only inspects and returns attributes (and not the tag)
sed -i 's/string result = tag/string result = ""/g' ${TARGET_DIR}/XmlElement__vivado.svh
## Change XML string emitter function accordingly
sed -i "s/\"%s<%s>\", indent, get_start_tag_contents/\"%s<%s%s>\", indent, tag, get_start_tag_contents/g" ${TARGET_DIR}/XmlElement__vivado.svh

# Create ephemeral copy of junit_xml package in run directory (also add _pkg suffix since _pkg source files are identified as packages and compiled first)
cp ${SVUNIT_INSTALL}/svunit_base/junit-xml/junit_xml.sv ${TARGET_DIR}/junit_xml_pkg.sv

# Modify junit_xml_pkg to refer to modified versions of XmlElement class
sed -i 's:`include "XmlElement:`include "XmlElement__vivado:g' ${TARGET_DIR}/junit_xml_pkg.sv

# Modify file list to refer to modified junit_xml
sed -i "s:^.*junit_xml.sv:${TARGET_DIR}/junit_xml_pkg.sv:g" ${TARGET_DIR}/.svunit.f

