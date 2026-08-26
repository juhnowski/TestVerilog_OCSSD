import cocotb
from cocotb.triggers import RisingEdge
from cocotb.clock import Clock
from tests.test_nvme_parser import make_nvme_vector # Переиспользуем генератор команд

@cocotb.test()
async def test_complete_ocssd_flow(dut):
    """Сквозной тест: Дверной звонок -> Симуляция DMA -> Извлечение PPA адреса"""

    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Инициализация
    dut.rst.value = 1
    dut.s_axil_awvalid.value = 0
    dut.s_axil_wvalid.value = 0
    dut.s_axil_bready.value = 1
    dut.dma_cmd_valid.value = 0
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)

    # Шаг 1: Драйвер Linux LightNVM пишет в Doorbell регистр (Адрес 0x1000)
    dut.s_axil_awaddr.value = 0x1000
    dut.s_axil_wdata.value = 1  # Записали хвост очереди
    dut.s_axil_awvalid.value = 1
    dut.s_axil_wvalid.value = 1
    await RisingEdge(dut.clk)
    dut.s_axil_awvalid.value = 0
    dut.s_axil_wvalid.value = 0
    await RisingEdge(dut.clk)

    # Шаг 2: Контроллер принял звонок. Симулируем ответный ход DMA движка:
    # Передаем 64-байтную команду. Нацеливаемся на: Канал 2, Die 0, Чанк 1024, Страница 7
    ocssd_cmd = make_nvme_vector(
        opcode=0x01, prp1=0x10000000, prp2=0x0,
        channel=2, lun=0, chunk=1024, page=7
    )
    
    dut.dma_cmd_data.value = ocssd_cmd
    dut.dma_cmd_valid.value = 1
    await RisingEdge(dut.clk)
    dut.dma_cmd_valid.value = 0
    await RisingEdge(dut.clk)

    # Шаг 3: Проверяем, что на физическом уровне (на выходах к Flash) появились нужные сигналы
    assert dut.flash_cmd_valid.value == 1, "Ошибка: Сигнал валидности команды флеш-памяти не выставился!"
    assert dut.flash_channel.value == 2
    assert dut.flash_chunk.value == 1024
    assert dut.flash_page.value == 7

    dut._log.info("🔥 [ТРИУМФ] Сквозной цикл завершен! Адресация Open-Channel SSD работает на системном уровне.")
