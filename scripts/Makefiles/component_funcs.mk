# ----------------------------------------------------
# Common functions
# ----------------------------------------------------
include $(SCRIPTS_ROOT)/Makefiles/funcs.mk

# ----------------------------------------------------
# Component reference functions
# ----------------------------------------------------
# Component refs should be lower-case only, and should be in form a.b.c (i.e. not a.b.c. or .a.b.c)
normalize_component_ref = $(call get_component_ref_from_parts,$(call get_component_parts_from_ref,$(call __to_lower,$(1))))

# Conversion functions (all take single argument which is implicit in function name)
get_component_num_parts_from_ref = $(words $(call get_component_parts_from_ref,$(1)))
get_component_parts_from_ref = $(strip $(subst ., ,$(1)))
get_component_parts_from_path = $(strip $(subst /, ,$(subst .,~,$(1))))
get_component_ref_from_parts = $(subst $(__space),.,$(1))
get_component_ref_from_path = $(call normalize_component_ref,$(subst /,.,$(subst .,~,$(1))))
get_component_ref_from_name = $(call normalize_component_ref,$(subst $(__space)$(__space),.,$(1)))
get_component_name_from_ref = $(subst .,__,$(call normalize_component_ref,$(1)))
get_component_path_from_ref = $(subst ~,.,$(subst .,/,$(call normalize_component_ref,$(1))))
get_subcomponent_from_ref   = $(lastword $(call get_component_parts_from_ref,$(1)))
get_component_base_from_ref = $(call get_component_ref_from_parts,$(wordlist 1,$(shell echo $$(( $(call get_component_num_parts_from_ref,$(1)) - 1 ))),$(call get_component_parts_from_ref,$(1))))
get_component_base_path_from_ref = $(call get_component_path_from_ref,$(call get_component_base_from_ref,$(1)))

# Regio component identification functions
# - regio-generated RTL and verif libraries will have references looking like
#   *.regio.rtl and *.regio.verif, respectively.
# - since these libraries are auto-generated, they can't be compiled without
#   first running regio; this is accomplished by executing the compile at the
#   *.reg scope which requires special handling
__component_is_base_regio = $(filter regio,$(lastword $(call get_component_parts_from_ref,$(call get_component_base_from_ref,$(1)))))
__subcomponent_is_rtl_verif = $(filter $(call get_subcomponent_from_ref,$(1)),rtl verif)
is_regio_component = $(and $(call __component_is_base_regio,$(1)),$(call __subcomponent_is_rtl_verif,$(1)))

# Determine source path; handle regio as special case
get_component_src_path_from_ref = $(strip $(if $(call is_regio_component,$(1)),\
	$(call get_component_base_path_from_ref,$(1)),\
	$(call get_component_path_from_ref,$(1))\
))

# IP component identification
is_ip_component = $(or $(filter $(call get_subcomponent_from_ref,$(1)),ip), $(filter $(call get_subcomponent_from_ref,$(1)),bd))
is_build_component = $(filter $(call get_component_parts_from_ref,$(1)),build)

# Determine output path; handle ip as special case
get_component_out_path_from_ref = $(strip $(if $(or $(call is_ip_component,$(1)), $(call is_build_component,$(1))),\
	$(2)/$(call get_component_path_from_ref,$(1))/$(3),\
	$(2)/$(call get_component_path_from_ref,$(1))\
))

# ----------------------------------------------------
# Library reference functions
# -----------------------------------------------
lib_separator := @

# Function: __lib_name_from_spec
# Given name=path spec (specified as only parameter), return library name
__lib_name_from_spec = $(firstword $(subst =, ,$(1)))
# Function: __lib_path_from_spec
# Given name=path spec (specified as only parameter), return library path
__lib_path_from_spec = $(lastword $(subst =, ,$(1)))

# Function: get_libs
# Return list of all specified libraries.
get_libs = $(foreach libspec,$(LIBRARIES),$(call __lib_name_from_spec,$(libspec)))

# Function: __get_lib_name
# Echoes library name if library name (specified as only parameter) is defined
get_lib_name = $(filter $(1),$(foreach libspec,$(LIBRARIES),$(call __lib_name_from_spec,$(libspec))))

# Function: __get_lib_path
# Returns path to library name (specified as only parameter)
__get_lib_path = $(strip $(foreach libspec, $(LIBRARIES), $(if $(filter $(1),$(call __lib_name_from_spec,$(libspec))),$(call __lib_path_from_spec,$(libspec)),)))

# Function get_lib_path
# Returns path to library name (specified as only parameter), or path to local library if not
get_lib_path = $(or $(call __get_lib_path,$(call get_lib_name,$(1))),$(SRC_ROOT))

# Function: __get_lib_parts_from_ref
# Split component reference into library reference and base component reference parts
__get_lib_parts_from_ref = $(subst $(lib_separator), ,$(1))

# Function: __get_ref_from_lib_parts
__get_ref_from_lib_parts = $(subst $(__space),$(lib_separator),$(1))

# Function get_lib_from_ref
get_lib_from_ref = $(and $(word 2,$(call __get_lib_parts_from_ref,$(1))),$(lastword $(call __get_lib_parts_from_ref,$(1))))

# Function: pop_lib_from_ref
pop_lib_from_ref = $(call __get_ref_from_lib_parts,$(subst <END>,,$(filter-out $(call get_lib_from_ref,$(1)<END>),$(call __get_lib_parts_from_ref,$(1)<END>))))

# Function: get reference without library
get_ref_without_lib = $(firstword $(call __get_lib_parts_from_ref,$(1)))

# Function: get path from ref
reverse = $(if $(1),$(call reverse,$(wordlist 2,$(words $(1)),$(1)))) $(firstword $(1))
get_lib_component_path_from_ref = $(call get_component_path_from_ref,$(call get_component_ref_from_parts,$(call reverse,$(call __get_lib_parts_from_ref,$(1)))))

# Function: get output path from ref
get_lib_component_out_path_from_ref = $(strip $(if $(call is_ip_component,$(1)),\
	$(2)/$(call get_lib_component_path_from_ref,$(1))/$(3),\
	$(2)/$(call get_lib_component_path_from_ref,$(1))\
))
