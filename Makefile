SIM ?= icarus
TOPLEVEL_LANG ?= verilog

# Все исходники
VERILOG_SOURCES += $(PWD)/src/nvme_regs.v
VERILOG_SOURCES += $(PWD)/src/nvme_parser.v
VERILOG_SOURCES += $(PWD)/src/queue_arbiter.v
VERILOG_SOURCES += $(PWD)/src/ocssd_top.v

# ФИКС РЕГРЕССИИ: Возвращаем топ-модуль проекта
TOPLEVEL = ocssd_top

# Все 4 теста в одной обойме
COCOTB_TEST_MODULES = tests.test_nvme_regs,tests.test_nvme_parser,tests.test_ocssd_top,tests.test_queue_arbiter

COCOTB_WAVES = 1

include $(shell cocotb-config --makefiles)/Makefile.sim

.PHONY: clean_all
clean_all: clean
	rm -rf sim_build/
	rm -f results.xml
	rm -f *.vcd *.fst
