# Copyright Notice

ESnet SmartNIC Copyright (c) 2022, The Regents of the University of
California, through Lawrence Berkeley National Laboratory (subject to
receipt of any required approvals from the U.S. Dept. of Energy),
12574861 Canada Inc., Malleable Networks Inc., and Apical Networks, Inc.
All rights reserved.

If you have questions about your rights to use or distribute this software,
please contact Berkeley Lab's Intellectual Property Office at
IPO@lbl.gov.

NOTICE.  This Software was developed under funding from the U.S. Department
of Energy and the U.S. Government consequently retains certain rights.  As
such, the U.S. Government has been granted for itself and others acting on
its behalf a paid-up, nonexclusive, irrevocable, worldwide license in the
Software to reproduce, distribute copies to the public, prepare derivative
works, and perform publicly and display publicly, and to permit others to do so.



# ESnet FPGA library

This library contains general-purpose FPGA RTL design files and associated verification
suites, as well as standard Makefiles, scripts and tools for a structured FPGA design
methodology.

The ESnet FPGA library is made available in the hope that it will
be useful to the FPGA design community. Users should note that it is
made available on an "as-is" basis, and should not expect any
technical support or other assistance with building or using this
software. For more information, please refer to the LICENSE.md file in
the source code repository.

The developers of the ESnet FPGA library can be reached by email at smartnic@es.net.


# Directory Structure

```
esnet-fpga-library/
    ├── cfg/
    ├── config.mk
    ├── LICENSE.md
    ├── Makefile
    ├── paths.mk
    ├── README.md
    ├── scripts/
    ├── src/
    └── tools/

cfg/
  Contains configuration files for the FPGA library.

config.mk
  Sets environment variables.

LICENSE.md
  Contains the licensing terms and copyright notice for this repository.

Makefile
  Specifies default library setup.

paths.mk
  Describes paths to resources provided by the library.

README.md
  This README file.

scripts/
  Contains common Makefiles and Tcl scripts for maintaining a standard design directory
  structure and standard work flows for register map construction, RTL simulation and
  synthesis.

src/
  Contains RTL source and verification code for a number of standard FPGA design components,
  captured in System Verilog.

tools/
  Contains useful productivity tools for a structured FPGA design methodology. 

```
**NOTE: See lower level README files for more details.**



# Known Issues

- None to date.
