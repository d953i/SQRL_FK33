set_property BITSTREAM.CONFIG.CONFIGRATE 127.5 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]

set_property -dict { IOSTANDARD LVDS PACKAGE_PIN BC27 } 	[get_ports { SYSCLK0_200_N }];
set_property -dict { IOSTANDARD LVDS PACKAGE_PIN BC26 } 	[get_ports { SYSCLK0_200_P }];

set_property -dict { IOSTANDARD LVCMOS18 PACKAGE_PIN BB24 DRIVE 8  SLEW SLOW  } 	[get_ports { MAIN_I2C_SCL }];
set_property -dict { IOSTANDARD LVCMOS18 PACKAGE_PIN BA24 DRIVE 8  SLEW SLOW  } 	[get_ports { MAIN_I2C_SDA }];

set_property -dict { IOSTANDARD LVCMOS18 PACKAGE_PIN BD25 DRIVE 8  } 	[get_ports { GPIO_LED_0_LS }];
set_property -dict { IOSTANDARD LVCMOS18 PACKAGE_PIN BE26 DRIVE 8  } 	[get_ports { GPIO_LED_1_LS }];
set_property -dict { IOSTANDARD LVCMOS18 PACKAGE_PIN BD23 DRIVE 8  } 	[get_ports { GPIO_LED_2_LS }];
set_property -dict { IOSTANDARD LVCMOS18 PACKAGE_PIN BF26 DRIVE 8  } 	[get_ports { GPIO_LED_3_LS }];
set_property -dict { IOSTANDARD LVCMOS18 PACKAGE_PIN BC25 DRIVE 8  } 	[get_ports { GPIO_LED_4_LS }];
set_property -dict { IOSTANDARD LVCMOS18 PACKAGE_PIN BB26 DRIVE 8  } 	[get_ports { GPIO_LED_5_LS }];
set_property -dict { IOSTANDARD LVCMOS18 PACKAGE_PIN BB25 DRIVE 8  } 	[get_ports { GPIO_LED_6_LS }];

set_property -dict { IOSTANDARD LVCMOS18 PACKAGE_PIN BE24 }	[get_ports { PCIE_PERST }];
set_property -dict { PACKAGE_PIN AD8 } 	[get_ports { PCIE_100MHZ_CLK_N }];
set_property -dict { PACKAGE_PIN AD9 } 	[get_ports { PCIE_100MHZ_CLK_P }];

set_Property -dict { PACKAGE_PIN AL2 } 	[get_ports { PCIE_RX_P[0] }];
set_Property -dict { PACKAGE_PIN AL1 } 	[get_ports { PCIE_RX_N[0] }];
set_Property -dict { PACKAGE_PIN Y5 } 	[get_ports { PCIE_TX_P[0] }];
set_Property -dict { PACKAGE_PIN Y4 } 	[get_ports { PCIE_TX_N[0] }];

set_Property -dict { PACKAGE_PIN AM4 } 	[get_ports { PCIE_RX_P[1] }];
set_Property -dict { PACKAGE_PIN AM3 } 	[get_ports { PCIE_RX_N[1] }];
set_Property -dict { PACKAGE_PIN AA7 } 	[get_ports { PCIE_TX_P[1] }];
set_Property -dict { PACKAGE_PIN AA6 } 	[get_ports { PCIE_TX_N[1] }];

set_Property -dict { PACKAGE_PIN AK4 } 	[get_ports { PCIE_RX_P[2] }];
set_Property -dict { PACKAGE_PIN AK3 } 	[get_ports { PCIE_RX_N[2] }];
set_Property -dict { PACKAGE_PIN AB5 } 	[get_ports { PCIE_TX_P[2] }];
set_Property -dict { PACKAGE_PIN AB4 } 	[get_ports { PCIE_TX_N[2] }];

set_Property -dict { PACKAGE_PIN AN2 } 	[get_ports { PCIE_RX_P[3] }];
set_Property -dict { PACKAGE_PIN AN1 } 	[get_ports { PCIE_RX_N[3] }];
set_Property -dict { PACKAGE_PIN AC7 } 	[get_ports { PCIE_TX_P[3] }];
set_Property -dict { PACKAGE_PIN AC6 } 	[get_ports { PCIE_TX_N[3] }];

set_Property -dict { PACKAGE_PIN AP4 } 	[get_ports { PCIE_RX_P[4] }];
set_Property -dict { PACKAGE_PIN AP3 } 	[get_ports { PCIE_RX_N[4] }];
set_Property -dict { PACKAGE_PIN AD5 } 	[get_ports { PCIE_TX_P[4] }];
set_Property -dict { PACKAGE_PIN AD4 } 	[get_ports { PCIE_TX_N[4] }];

set_Property -dict { PACKAGE_PIN AR2 } 	[get_ports { PCIE_RX_P[5] }];
set_Property -dict { PACKAGE_PIN AR1 } 	[get_ports { PCIE_RX_N[5] }];
set_Property -dict { PACKAGE_PIN AF5 } 	[get_ports { PCIE_TX_P[5] }];
set_Property -dict { PACKAGE_PIN AF4 } 	[get_ports { PCIE_TX_N[5] }];

set_Property -dict { PACKAGE_PIN AT4 } 	[get_ports { PCIE_RX_P[6] }];
set_Property -dict { PACKAGE_PIN AT3 } 	[get_ports { PCIE_RX_N[6] }];
set_Property -dict { PACKAGE_PIN AE7 } 	[get_ports { PCIE_TX_P[6] }];
set_Property -dict { PACKAGE_PIN AE6 } 	[get_ports { PCIE_TX_N[6] }];

set_Property -dict { PACKAGE_PIN AU2 } 	[get_ports { PCIE_RX_P[7] }];
set_Property -dict { PACKAGE_PIN AU1 } 	[get_ports { PCIE_RX_N[7] }];
set_Property -dict { PACKAGE_PIN AH5 } 	[get_ports { PCIE_TX_P[7] }];
set_Property -dict { PACKAGE_PIN AH4 } 	[get_ports { PCIE_TX_N[7] }];

set_Property -dict { PACKAGE_PIN AV4 } 	[get_ports { PCIE_RX_P[8] }];
set_Property -dict { PACKAGE_PIN AV3 } 	[get_ports { PCIE_RX_N[8] }];
set_Property -dict { PACKAGE_PIN AG7 } 	[get_ports { PCIE_TX_P[8] }];
set_Property -dict { PACKAGE_PIN AG6 } 	[get_ports { PCIE_TX_N[8] }];

set_Property -dict { PACKAGE_PIN AW2 } 	[get_ports { PCIE_RX_P[9] }];
set_Property -dict { PACKAGE_PIN AW1 } 	[get_ports { PCIE_RX_N[9] }];
set_Property -dict { PACKAGE_PIN AJ7 } 	[get_ports { PCIE_TX_P[9] }];
set_Property -dict { PACKAGE_PIN AJ6 } 	[get_ports { PCIE_TX_N[9] }];

set_Property -dict { PACKAGE_PIN BA2 } 	[get_ports { PCIE_RX_P[10] }];
set_Property -dict { PACKAGE_PIN BA1 } 	[get_ports { PCIE_RX_N[10] }];
set_Property -dict { PACKAGE_PIN AL7 } 	[get_ports { PCIE_TX_P[10] }];
set_Property -dict { PACKAGE_PIN AL6 } 	[get_ports { PCIE_TX_N[10] }];

set_Property -dict { PACKAGE_PIN BC2 } 	[get_ports { PCIE_RX_P[11] }];
set_Property -dict { PACKAGE_PIN BC1 } 	[get_ports { PCIE_RX_N[11] }];
set_Property -dict { PACKAGE_PIN AM9 } 	[get_ports { PCIE_TX_P[11] }];
set_Property -dict { PACKAGE_PIN AM8 } 	[get_ports { PCIE_TX_N[11] }];

set_Property -dict { PACKAGE_PIN AY4 } 	[get_ports { PCIE_RX_P[12] }];
set_Property -dict { PACKAGE_PIN AY3 } 	[get_ports { PCIE_RX_N[12] }];
set_Property -dict { PACKAGE_PIN AN7 } 	[get_ports { PCIE_TX_P[12] }];
set_Property -dict { PACKAGE_PIN AN6 } 	[get_ports { PCIE_TX_N[12] }];

set_Property -dict { PACKAGE_PIN BB4 } 	[get_ports { PCIE_RX_P[13] }];
set_Property -dict { PACKAGE_PIN BB3 } 	[get_ports { PCIE_RX_N[13] }];
set_Property -dict { PACKAGE_PIN AP9 } 	[get_ports { PCIE_TX_P[13] }];
set_Property -dict { PACKAGE_PIN AP8 } 	[get_ports { PCIE_TX_N[13] }];

set_Property -dict { PACKAGE_PIN BD4 } 	[get_ports { PCIE_RX_P[14] }];
set_Property -dict { PACKAGE_PIN BD3 } 	[get_ports { PCIE_RX_N[14] }];
set_Property -dict { PACKAGE_PIN AR7 } 	[get_ports { PCIE_TX_P[14] }];
set_Property -dict { PACKAGE_PIN AR6 } 	[get_ports { PCIE_TX_N[14] }];

set_Property -dict { PACKAGE_PIN BE6 } 	[get_ports { PCIE_RX_P[15] }];
set_Property -dict { PACKAGE_PIN BE5 } 	[get_ports { PCIE_RX_N[15] }];
set_Property -dict { PACKAGE_PIN AT9 } 	[get_ports { PCIE_TX_P[15] }];
set_Property -dict { PACKAGE_PIN AT8 } 	[get_ports { PCIE_TX_N[15] }];
