ifndef $(__FUNCS_MK__)
__FUNCS_MK__ := defined
# ----------------------------------------------------
# Common functions
# ----------------------------------------------------
__space := $(subst ,, )
__to_lower = $(shell echo $(1) | tr '[:upper:]' '[:lower:]')
__to_upper = $(shell echo $(1) | tr '[:lower:]' '[:upper:]')

# Uniquify list (but leave order untouched, by removing all duplicates after
# the first occurrence of a list element
# (built-in Makefile `sort` uniquifies list, but also sorts lexically)
uniq = $(if $(1),$(firstword $(1)) $(call uniq,$(filter-out $(firstword $(1)),$(1))))

endif # ifndef $(__FUNCS_MK__)
