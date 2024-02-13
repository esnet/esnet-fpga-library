# ----------------------------------------------------
# Common functions
# ----------------------------------------------------
__space := $(subst ,, )
__to_lower = $(shell echo $(1) | tr '[:upper:]' '[:lower:]')

# Uniquify list (but leave order untouched, by removing all duplicates after
# the first occurrence of a list element
# (built-in Makefile `sort` uniquifies list, but also sorts lexically)
uniq = $(if $(1),$(firstword $(1)) $(call uniq,$(filter-out $(firstword $(1)),$(1))))



