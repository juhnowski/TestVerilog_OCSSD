SIM ?= icarus
TOPLEVEL_LANG ?= verilog

# Полный стек файлов
VERILOG_SOURCES += $(PWD)/src/nvme_regs.v
VERILOG_SOURCES += $(PWD)/src/nvme_parser.v
VERILOG_SOURCES += $(PWD)/src/queue_arbiter.v
VERILOG_SOURCES += $(PWD)/src/dma_data_mover.v
VERILOG_SOURCES += $(PWD)/src/ocssd_top.v

# Глобальный топ-уровень
TOPLEVEL = ocssd_top

# Полная обойма из 5 тестов для непрерывного регресса
COCOTB_TEST_MODULES = tests.test_nvme_regs,tests.test_nvme_parser,tests.test_ocssd_top,tests.test_queue_arbiter,tests.test_dma_mover

COCOTB_WAVES = 1

include $(shell cocotb-config --makefiles)/Makefile.sim

.PHONY: clean_all
clean_all: clean
	rm -rf sim_build/
	rm -f results.xml
	rm -f *.vcd *.fst
