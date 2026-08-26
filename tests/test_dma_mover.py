import cocotb
from cocotb.triggers import RisingEdge, ReadOnly
from cocotb.clock import Clock

@cocotb.test()
async def test_dma_data_capture(dut):
    """Проверяем захват 64 байт данных из PCIe DMA канала во внутренний буфер"""

    mover = dut.u_dma_mover

    cocotb.start_soon(Clock(mover.clk, 10, unit="ns").start())

    # Инициализация портов
    mover.rst.value = 1
    mover.pcie_dma_valid.value = 0
    await RisingEdge(mover.clk)
    mover.rst.value = 0
    await RisingEdge(mover.clk)

    # Имитируем падение 64-байтной команды с PCIe шины
    test_cmd = (0xCAFE_BABE << 256) | 0xDEAD_BEEF
    mover.pcie_dma_data.value = test_cmd
    mover.pcie_dma_valid.value = 1
    await RisingEdge(mover.clk)
    mover.pcie_dma_valid.value = 0
    
    # Переходим в фазу ReadOnly, чтобы симулятор успел обновить неблокирующие присваивания (<=)
    await ReadOnly()

    # Проверяем фиксацию в буфере
    assert mover.out_cmd_valid.value == 1, "Ошибка: Data Mover не защелкнул флаг валидности"
    assert mover.out_cmd_data.value == test_cmd, "Ошибка: Данные в буфере не совпадают"

    mover._log.info("🔥 [Успех] Регрессионный тест буфера DMA пройден!")
