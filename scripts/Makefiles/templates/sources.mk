# ----------------------------------------------------
# Sources
# ----------------------------------------------------
# Source files comprising the component being compiled must be specified,
# either explicitly (using SRC_FILES/INC_DIRS/SRC_LIST_FILES) or implicitly
# (see NOTE below).
#
# NOTE: In addition to all explicitly listed files (below), all source/header
# files in $(SRC_DIR) and $(INC_DIR) will be automatically included.
# By default, SRC_DIR=./src and INC_DIR=./include, so locating source
# (and header) files in ./src (and ./include) is sufficient.

# Source files comprising the component being compiled can be listed explicitly
# using SRC_FILES. Typically only files that lie outside of $(SRC_DIR) would be
# included here, since all source files in $(SRC_DIR) are included automatically
# (see NOTE above).
#
# Source files for other components that are dependencies of this component
# should not be listed here, as these are handled as SUBCOMPONENTS dependencies
# (see dependencies.mk).
SRC_FILES=

# Include directories required to compile the component can be listed explictly
# using INC_DIRS. Again, typically only include directories other than $(INCLUDE_DIR)
# would be listed since $(INCLUDE_DIR) is automatically handled.
INC_DIRS=

# Additionally, include all sources (and include directories) as described in the
# file listings (.f files) listed in SRC_LIST_FILES. Same guidance applies with respect
# to auto-included sources and dependency handling.
SRC_LIST_FILES=

