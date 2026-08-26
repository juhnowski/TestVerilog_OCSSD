SIM ?= icarus
TOPLEVEL_LANG ?= verilog

# Добавляем оба файла в симуляцию
VERILOG_SOURCES += $(PWD)/src/nvme_regs.v
VERILOG_SOURCES += $(PWD)/src/nvme_parser.v

# Тестируем теперь парсер
TOPLEVEL = nvme_parser
COCOTB_TEST_MODULES = tests.test_nvme_parser

COCOTB_WAVES = 1

include $(shell cocotb-config --makefiles)/Makefile.sim
