//////////////////////////////////////////////////////////////////////////////////
// Engineer: Mike Field <hamster@snap.net.nz>
// 
// Description: Controller for the OV7670 camera - transfers registers to the 
//              camera over an I2C like bus
// Adapted for Nexys4 DDR
//////////////////////////////////////////////////////////////////////////////////
module ov7670_controller(
    input  wire        clk,
    input  wire        resend,
    output wire        config_finished,
    output wire        sioc,
    inout  wire        siod,
    output wire        reset,
    output wire        pwdn,
    output reg         xclk
);

    wire [15:0] command;
    wire        finished;
    wire        taken;
    wire        send;
    reg         sys_clk = 1'b0;
    
    parameter camera_address = 8'h42; // Device write ID - see top of page 11 of data sheet
    
    assign config_finished = finished;
    assign send = ~finished;
    assign reset = 1'b1;  // Normal mode
    assign pwdn  = 1'b0;  // Power device up
    assign xclk  = sys_clk;
    
    i2c_sender inst_i2c_sender(
        .clk   (clk),
        .taken (taken),
        .siod  (siod),
        .sioc  (sioc),
        .send  (send),
        .id    (camera_address),
        .reg_addr (command[15:8]),
        .value (command[7:0])
    );

    ov7670_registers inst_ov7670_registers(
        .clk      (clk),
        .advance  (taken),
        .command  (command),
        .finished (finished),
        .resend   (resend)
    );

    always @(posedge clk) begin
        sys_clk <= ~sys_clk;
    end
endmodule

