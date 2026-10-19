`ifdef JTFRAME_SRAM
    output    [16:0]  sram_addr,
    output    [15:0]  sram_din,
    input     [15:0]  sram_dout,
    output            sram_wen,
    output    [ 1:0]  sram_dsn,
    input             sram_ok,
`endif
    input cen_pcm, // 6000 = 49153840*7/57346 Hz 
    input cen_c30, // 3071999 = 49153840*3339/53426 Hz 

    // Audio channels
    output signed [12:0] cus30_l,
    output signed [12:0] cus30_r,
    // Memory ports
`ifdef JTFRAME_SDRAM_XL
    input   [23:0]  prog_addr,
`elsif JTFRAME_SDRAM_LARGE
    input   [22:0]  prog_addr,
`else
    input   [21:0]  prog_addr,
`endif
    input   [ 7:0]  prog_data,
    input           prog_we,
    input   [ 1:0]  prog_ba,
`ifdef JTFRAME_SDRAM_XL
    input   [26:0]  ioctl_addr,
`else
    input   [25:0]  ioctl_addr,
`endif
    input           prom_we,
`ifdef JTFRAME_HEADER
    input           header,
`endif
`ifdef JTFRAME_IOCTL_RD
    input           ioctl_wr,
    output   [ 7:0] ioctl_din,
    input    [ 7:0] ioctl_dout, `endif
    input           ioctl_ram,
    input           ioctl_cart,
    // Explicit ports
    output   [9:0] rgb_addr,
    input   [7:0] bpal_data,
    output   [11:1] vram0_addr,
    input   [15:0] vram0_dout,
    input   [15:0] fg_dout,
    output   [11:1] vram1_addr,
    input   [15:0] vram1_dout,
    output   [12:1] oram_addr,
    input   [7:0] sndram_dout,
    input   [7:0] mcu_data,
    input   [7:0] rgpal_data,
    input   [7:0] objpal_data,
    output   [7:0] cpu_dout,
    output   [9:0] scr0pal_addr,
    output   [9:0] scr1pal_addr,
    input   [15:0] oram_dout,
    output   [11:0] sndram_addr,
    output   [11:0] mcu_addr,
    input   [7:0] scr0pal_data,
    input   [7:0] scr1pal_data,
    output   [9:0] objpal_addr,
    input   [15:0] bg_dout,
    input   [15:0] olut_dout,
    output   [7:0] sndram_din,
    output    sndram_we,
    // Buses to BRAM

    
    
    
    
    
    
    output   [ 1:0] bg_we, // Dual port for bg
    
    output   [ 1:0] fg_we, // Dual port for fg
    
    output   [ 1:0] olut_we, // Dual port for olut
    
    
    // Buses to SDRAM
    input    [ 7:0] main_data,
    output          main_cs,
    output   [16:0] main_addr,
    input           main_ok,

    input    [ 7:0] mcusub_data,
    output          mcusub_cs,
    output   [12:0] mcusub_addr,
    input           mcusub_ok,

    input    [15:0] scr0_data,
    output          scr0_cs,
    output   [12:1] scr0_addr,
    input           scr0_ok,

    input    [15:0] scr1_data,
    output          scr1_cs,
    output   [12:1] scr1_addr,
    input           scr1_ok,

    input    [31:0] obj_data,
    output          obj_cs,
    output   [15:2] obj_addr,
    input           obj_ok
