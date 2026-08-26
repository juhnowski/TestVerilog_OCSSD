import cocotb
from cocotb.triggers import RisingEdge
from cocotb.clock import Clock

def make_nvme_vector(opcode, prp1, prp2, channel, lun, chunk, page):
    """Вспомогательная функция для сборки 512-битного вектора команды"""
    cmd = bytearray(64)
    
    # Записываем Opcode (Byte 0)
    cmd[0] = opcode
    
    # Записываем PRP1 (Bytes 24-31)
    for i in range(8):
        cmd[24 + i] = (prp1 >> (8 * i)) & 0xFF
        
    # Записываем PRP2 (Bytes 32-39)
    for i in range(8):
        cmd[32 + i] = (prp2 >> (8 * i)) & 0xFF

    # Записываем OCSSD PPA геометрию в Dword 14-15 (Bytes 56-61)
    cmd[56] = page & 0xFF
    cmd[57] = (page >> 8) & 0xFF
    cmd[58] = chunk & 0xFF
    cmd[59] = (chunk >> 8) & 0xFF
    cmd[60] = lun
    cmd[61] = channel

    # Превращаем байты в одно большое число для Cocotb (Little Endian)
    value = 0
    for i, b in enumerate(cmd):
        value |= b << (8 * i)
    return value

@cocotb.test()
async def test_parser_ocssd_command(dut):
    """Проверяем, что парсер верно извлекает PPA адреса Open-Channel"""

    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Сброс
    dut.rst.value = 1
    dut.cmd_valid.value = 0
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)

    # Формируем тестовую команду: 
    # Opcode=0x01 (Запись), PRP1=0xCAFE0000, Канал=3, Кристалл=1, Чанк=512, Страница=64
    test_vector = make_nvme_vector(
        opcode=0x01, 
        prp1=0xCAFE0000, 
        prp2=0x0, 
        channel=3, 
        lun=1, 
        chunk=512, 
        page=64
    )

    # Подаем на вход парсера
    dut.cmd_data.value = test_vector
    dut.cmd_valid.value = 1
    await RisingEdge(dut.clk)
    dut.cmd_valid.value = 0
    await RisingEdge(dut.clk)

    # Проверяем распаковку
    assert dut.cmd_opcode.value == 0x01
    # ФИКС: Убран лишний префикс 0x
    assert dut.cmd_prp1.value == 0xCAFE0000
    assert dut.ppa_channel.value == 3
    assert dut.ppa_lun.value == 1
    assert dut.ppa_chunk.value == 512
    assert dut.ppa_page.value == 64
    
    dut._log.info("🔥 [Успех] Команда Open-Channel успешно распарсена! Железо видит геометрию NAND.")
