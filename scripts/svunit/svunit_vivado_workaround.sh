#!/bin/sh
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
#   Forward class typedef reference in svunit_filter.svh causes tool error:
#
#   ERROR: [VRFC 10-3358] forward typedef 'filter_for_single_pattern' is already fully defined
#
#   The workaround below makes ephemeral copies of the svunit_filter.svh and
#   svunit_pkg.sv files, and removes the forward typedef. This is fine anyway
#   since the package ensures that the filter_for_single_pattern class is always
#   defined before svunit_filter.
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
# Create ephemeral copies of svunit_filter.svh
cp ${SVUNIT_INSTALL}/svunit_base/svunit_filter.svh ${TARGET_DIR}/svunit_filter__vivado.svh

# Delete forward typedef reference for svunit_
sed -i '/typedef class filter_for_single_pattern/d' ${TARGET_DIR}/svunit_filter__vivado.svh

# Create ephemeral copy of svunit_pkg.sv in run directory
cp ${SVUNIT_INSTALL}/svunit_base/svunit_pkg.sv ${TARGET_DIR}/svunit_pkg.sv

# Modify svunit_pkg to refer to modified versions of svunit_testsuite and svunit_testrunner classes
sed -i 's:svunit_filter.svh:\svunit_filter__vivado.svh:'   ${TARGET_DIR}/svunit_pkg.sv

# Modify file list to refer to modified svunit_pkg
sed -i "s:^.*svunit_pkg.sv:${TARGET_DIR}/svunit_pkg.sv:g" ${TARGET_DIR}/.svunit.f

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

