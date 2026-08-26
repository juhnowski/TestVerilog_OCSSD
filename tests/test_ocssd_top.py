import cocotb
from cocotb.triggers import RisingEdge
from cocotb.clock import Clock
from tests.test_nvme_parser import make_nvme_vector

@cocotb.test()
async def test_complete_ocssd_flow(dut):
    """Сквозной тест: Дверной звонок -> Симуляция DMA -> Извлечение PPA адреса"""

    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    # Инициализация
    dut.rst.value = 1
    dut.s_axil_awvalid.value = 0
    dut.s_axil_wvalid.value = 0
    dut.s_axil_bready.value = 1
    dut.pcie_dma_valid.value = 0
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)

    # Шаг 1: Драйвер Linux LightNVM пишет в Doorbell регистр (Адрес 0x1000)
    dut.s_axil_awaddr.value = 0x1000
    dut.s_axil_wdata.value = 1
    dut.s_axil_awvalid.value = 1
    dut.s_axil_wvalid.value = 1
    await RisingEdge(dut.clk)
    dut.s_axil_awvalid.value = 0
    dut.s_axil_wvalid.value = 0
    await RisingEdge(dut.clk)

    # Шаг 2: Симулируем ответный ход DMA движка
    ocssd_cmd = make_nvme_vector(
        opcode=0x01, prp1=0x10000000, prp2=0x0,
        channel=2, lun=0, chunk=1024, page=7
    )
    
    dut.pcie_dma_data.value = ocssd_cmd
    dut.pcie_dma_valid.value = 1
    await RisingEdge(dut.clk)
    dut.pcie_dma_valid.value = 0
    
    # ФИКС КОНВЕЙЕРА: Ждем 2 такта, чтобы данные прошли сквозь Mover и Parser
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    # Шаг 3: Проверяем, что на физическом уровне появились нужные сигналы
    assert dut.flash_cmd_valid.value == 1, "Ошибка: конвейер не выдал валидный флаг"
    assert dut.flash_channel.value == 2
    assert dut.flash_chunk.value == 1024
    assert dut.flash_page.value == 7

    dut._log.info("🔥 [Успех] Сквозной цикл завершен! Адресация Open-Channel SSD работает на системном уровне.")
