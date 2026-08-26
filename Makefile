SIM ?= icarus
TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES += $(PWD)/src/nvme_regs.v

TOPLEVEL = nvme_regs
COCOTB_TEST_MODULES = tests.test_nvme_regs

# Стандартный флаг Cocotb для автоматической генерации волн (VCD/FST)
COCOTB_WAVES = 1

include $(shell cocotb-config --makefiles)/Makefile.sim
