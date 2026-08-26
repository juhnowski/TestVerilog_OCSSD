# ==============================================================================
# Enterprise Regression Makefile для Open-Channel SSD Контроллера
# ==============================================================================

SIM ?= icarus
TOPLEVEL_LANG ?= verilog

# Указываем все RTL-файлы, участвующие в проекте
VERILOG_SOURCES += $(PWD)/src/nvme_regs.v
VERILOG_SOURCES += $(PWD)/src/nvme_parser.v
VERILOG_SOURCES += $(PWD)/src/ocssd_top.v

# Топ-модуль для симулятора (должен содержать в себе все порты и подмодули)
TOPLEVEL = ocssd_top

# РЕГРЕССИЯ: Прописываем через запятую все Python-тесты для автоматического рана
COCOTB_TEST_MODULES = tests.test_nvme_regs,tests.test_nvme_parser,tests.test_ocssd_top

# Автоматический дампинг сигналов во всех тестах для GTKWave
COCOTB_WAVES = 1

# Подключаем стандартные правила сборки Cocotb
include $(shell cocotb-config --makefiles)/Makefile.sim

# Дополнительный таргет для быстрой очистки мусора симуляции
.PHONY: clean_all
clean_all: clean
	rm -rf sim_build/
	rm -f results.xml
	rm -f *.vcd *.fst
	@echo "✨ Папка проекта полностью очищена от артефактов симуляции."
