# ESnet FPGA library

This library contains general-purpose FPGA RTL design files and associated verification
suites, as well as standard Makefiles, scripts and tools for a structured FPGA design
methodology.

# Directory Structure

```
esnet-fpga-library/
    ├── scripts/
    ├── src/
    ├── tools/
    ├── paths.mk
    └── README.md

scripts/
  Contains common Makefiles and Tcl scripts for maintaining a standard design directory
  structure and standard work flows for register map construction, RTL simulation and
  synthesis.

src/
  Contains RTL source and verification code for a number of standard FPGA design components,
  captured in System Verilog.

tools/
  Contains useful productivity tools for a structured FPGA design methodology. 

paths.mk  - Sets environment variables for standard pathnames.
README.md - This README file.

```
**NOTE: See lower level README files for more details.**




# Known Issues

- None to date.

