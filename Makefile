SIM ?= icarus
TOPLEVEL_LANG ?= verilog

# Все файлы проекта
VERILOG_SOURCES += $(PWD)/src/nvme_regs.v
VERILOG_SOURCES += $(PWD)/src/nvme_parser.v
VERILOG_SOURCES += $(PWD)/src/queue_arbiter.v
VERILOG_SOURCES += $(PWD)/src/dma_data_mover.v
VERILOG_SOURCES += $(PWD)/src/onfi_chan_ctrl.v
VERILOG_SOURCES += $(PWD)/src/ocssd_top.v

# Глобальный топ-уровень для всей пачки тестов
TOPLEVEL = ocssd_top

# Сквозная обойма тестов регрессии (включая верификацию Data Path Варианта А)
COCOTB_TEST_MODULES = tests.test_nvme_regs,tests.test_nvme_parser,tests.test_ocssd_top,tests.test_queue_arbiter,tests.test_dma_mover,tests.test_onfi_ctrl,tests.test_onfi_data_path

COCOTB_WAVES = 1

include $(shell cocotb-config --makefiles)/Makefile.sim

.PHONY: clean_all
clean_all: clean
	rm -rf sim_build/
	rm -f results.xml
	rm -f *.vcd *.fst
