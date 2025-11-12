// I2C LCD Controller with robust initialization
module lcd_test_top (
    input wire clk,
    input wire rst,
    inout wire sda,
    output wire scl,
    output wire [15:0] led
);

    localparam I2C_ADDR = 7'27;  // I2C address for LCD (try 0x27 if this doesn't work)
    
    // State machine
    localparam IDLE = 0, INIT = 1, WRITE = 2, DONE = 3;
    reg [1:0] state;
    reg [31:0] delay_cnt;
    reg [7:0] step_cnt;
    
    // I2C control
    reg i2c_ena;
    reg [7:0] i2c_data_wr;
    wire i2c_busy;
    wire i2c_ack_error;
    reg prev_busy;
    wire i2c_done = prev_busy & ~i2c_busy;
    
    // Message
    reg [7:0] message [0:31];
    initial begin
        message[0]="H"; message[1]="e"; message[2]="l"; message[3]="l";
        message[4]="o"; message[5]=" "; message[6]="F"; message[7]="P";
        message[8]="G"; message[9]="A"; message[10]="!"; message[11]=" ";
        message[12]=" "; message[13]=" "; message[14]=" "; message[15]=" ";
        message[16]="A"; message[17]="d"; message[18]="d"; message[19]="r";
        message[20]=":"; message[21]=" "; message[22]="0"; message[23]="x";
        message[24]="2"; message[25]="0"; message[26]=" "; message[27]=" ";
        message[28]=" "; message[29]=" "; message[30]=" "; message[31]=" ";
    end
    
    // Debug LEDs
    assign led[1:0] = state;
    assign led[9:2] = step_cnt;
    assign led[10] = i2c_ena;
    assign led[11] = prev_busy;
    assign led[12] = i2c_busy;
    assign led[13] = i2c_ack_error;
    assign led[14] = (delay_cnt[23]); // Slow blink
    assign led[15] = (state == DONE);
    
    // Send 4-bit command via I2C
    task send_nibble;
        input [3:0] data;
        input rs;
        input en;
        begin
            i2c_data_wr <= {data, 1'b1, en, 1'b0, rs}; // backlight=1, rw=0
            i2c_ena <= 1;
        end
    endtask
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            delay_cnt <= 0;
            step_cnt <= 0;
            i2c_ena <= 0;
            prev_busy <= 0;
        end else begin
            prev_busy <= i2c_busy;
            
            case (state)
                IDLE: begin
                    if (delay_cnt < 150_000_000)  // 1.5 second startup
                        delay_cnt <= delay_cnt + 1;
                    else begin
                        state <= INIT;
                        delay_cnt <= 0;
                        step_cnt <= 0;
                    end
                end
                
                INIT: begin
                    if (!i2c_busy && !i2c_ena) begin
                        case (step_cnt)
                            // Initial reset sequence
                            0: begin send_nibble(4'h3, 0, 1); step_cnt <= step_cnt + 1; end
                            1: begin send_nibble(4'h3, 0, 0); step_cnt <= step_cnt + 1; end
                            2: begin 
                                if (delay_cnt < 50_000_000) delay_cnt <= delay_cnt + 1;  // 500ms
                                else begin delay_cnt <= 0; step_cnt <= step_cnt + 1; end
                            end
                            
                            3: begin send_nibble(4'h3, 0, 1); step_cnt <= step_cnt + 1; end
                            4: begin send_nibble(4'h3, 0, 0); step_cnt <= step_cnt + 1; end
                            5: begin 
                                if (delay_cnt < 10_000_000) delay_cnt <= delay_cnt + 1;  // 100ms
                                else begin delay_cnt <= 0; step_cnt <= step_cnt + 1; end
                            end
                            
                            6: begin send_nibble(4'h3, 0, 1); step_cnt <= step_cnt + 1; end
                            7: begin send_nibble(4'h3, 0, 0); step_cnt <= step_cnt + 1; end
                            8: begin 
                                if (delay_cnt < 5_000_000) delay_cnt <= delay_cnt + 1;  // 50ms
                                else begin delay_cnt <= 0; step_cnt <= step_cnt + 1; end
                            end
                            
                            // Set 4-bit mode
                            9: begin send_nibble(4'h2, 0, 1); step_cnt <= step_cnt + 1; end
                            10: begin send_nibble(4'h2, 0, 0); step_cnt <= step_cnt + 1; end
                            11: begin 
                                if (delay_cnt < 5_000_000) delay_cnt <= delay_cnt + 1;
                                else begin delay_cnt <= 0; step_cnt <= step_cnt + 1; end
                            end
                            
                            // Function set: 4-bit, 2 lines, 5x8 (0x28)
                            12: begin send_nibble(4'h2, 0, 1); step_cnt <= step_cnt + 1; end
                            13: begin send_nibble(4'h2, 0, 0); step_cnt <= step_cnt + 1; end
                            14: begin send_nibble(4'h8, 0, 1); step_cnt <= step_cnt + 1; end
                            15: begin send_nibble(4'h8, 0, 0); step_cnt <= step_cnt + 1; end
                            16: begin 
                                if (delay_cnt < 2_000_000) delay_cnt <= delay_cnt + 1;
                                else begin delay_cnt <= 0; step_cnt <= step_cnt + 1; end
                            end
                            
                            // Display control: Display on, cursor off (0x0C)
                            17: begin send_nibble(4'h0, 0, 1); step_cnt <= step_cnt + 1; end
                            18: begin send_nibble(4'h0, 0, 0); step_cnt <= step_cnt + 1; end
                            19: begin send_nibble(4'hC, 0, 1); step_cnt <= step_cnt + 1; end
                            20: begin send_nibble(4'hC, 0, 0); step_cnt <= step_cnt + 1; end
                            21: begin 
                                if (delay_cnt < 2_000_000) delay_cnt <= delay_cnt + 1;
                                else begin delay_cnt <= 0; step_cnt <= step_cnt + 1; end
                            end
                            
                            // Clear display (0x01)
                            22: begin send_nibble(4'h0, 0, 1); step_cnt <= step_cnt + 1; end
                            23: begin send_nibble(4'h0, 0, 0); step_cnt <= step_cnt + 1; end
                            24: begin send_nibble(4'h1, 0, 1); step_cnt <= step_cnt + 1; end
                            25: begin send_nibble(4'h1, 0, 0); step_cnt <= step_cnt + 1; end
                            26: begin 
                                if (delay_cnt < 20_000_000) delay_cnt <= delay_cnt + 1;  // 200ms for clear
                                else begin delay_cnt <= 0; step_cnt <= step_cnt + 1; end
                            end
                            
                            // Entry mode: Increment, no shift (0x06)
                            27: begin send_nibble(4'h0, 0, 1); step_cnt <= step_cnt + 1; end
                            28: begin send_nibble(4'h0, 0, 0); step_cnt <= step_cnt + 1; end
                            29: begin send_nibble(4'h6, 0, 1); step_cnt <= step_cnt + 1; end
                            30: begin send_nibble(4'h6, 0, 0); step_cnt <= step_cnt + 1; end
                            31: begin 
                                if (delay_cnt < 2_000_000) delay_cnt <= delay_cnt + 1;
                                else begin 
                                    delay_cnt <= 0; 
                                    step_cnt <= 0;
                                    state <= WRITE;
                                end
                            end
                            
                            default: state <= WRITE;
                        endcase
                    end
                    
                    if (i2c_busy) i2c_ena <= 0;
                end
                
                WRITE: begin
                    if (!i2c_busy && !i2c_ena) begin
                        if (step_cnt < 64) begin  // 32 chars * 2 nibbles = 64
                            case (step_cnt[0])
                                0: begin  // High nibble with EN high
                                    send_nibble(message[step_cnt[6:1]][7:4], 1, 1);
                                    step_cnt <= step_cnt + 1;
                                end
                                1: begin  // High nibble with EN low, then low nibble
                                    if (step_cnt[1]) begin
                                        send_nibble(message[step_cnt[6:1]][7:4], 1, 0);
                                    end else begin
                                        send_nibble(message[step_cnt[6:1]][3:0], 1, 1);
                                    end
                                    step_cnt <= step_cnt + 1;
                                end
                            endcase
                        end else if (step_cnt == 64) begin
                            // Move to line 2 (0xC0)
                            send_nibble(4'hC, 0, 1);
                            step_cnt <= step_cnt + 1;
                        end else if (step_cnt == 65) begin
                            send_nibble(4'hC, 0, 0);
                            step_cnt <= step_cnt + 1;
                        end else if (step_cnt == 66) begin
                            send_nibble(4'h0, 0, 1);
                            step_cnt <= step_cnt + 1;
                        end else if (step_cnt == 67) begin
                            send_nibble(4'h0, 0, 0);
                            step_cnt <= 68;
                        end else if (step_cnt < 132) begin  // Another 32 chars * 2
                            case (step_cnt[0])
                                0: begin
                                    send_nibble(message[(step_cnt-68)>>1][7:4], 1, 1);
                                    step_cnt <= step_cnt + 1;
                                end
                                1: begin
                                    if (step_cnt[1]) begin
                                        send_nibble(message[(step_cnt-68)>>1][7:4], 1, 0);
                                    end else begin
                                        send_nibble(message[(step_cnt-68)>>1][3:0], 1, 1);
                                    end
                                    step_cnt <= step_cnt + 1;
                                end
                            endcase
                        end else begin
                            state <= DONE;
                        end
                    end
                    
                    if (i2c_busy) i2c_ena <= 0;
                end
                
                DONE: begin
                    i2c_ena <= 0;
                end
            endcase
        end
    end
    
    // I2C master
    i2c_master #(
        .input_clk(100_000_000), 
        .bus_clk(50_000)  // Slower 50kHz
    ) i2c (
        .clk(clk),
        .reset_n(~rst),
        .ena(i2c_ena),
        .addr(I2C_ADDR),
        .rw(1'b0),
        .data_wr(i2c_data_wr),
        .busy(i2c_busy),
        .ack_error(i2c_ack_error),
        .sda(sda),
        .scl(scl)
    );

endmodule

// I2C Master Controller
module i2c_master #(
    parameter input_clk = 100_000_000,
    parameter bus_clk = 100_000
)(
    input clk,
    input reset_n,
    input ena,
    input [6:0] addr,
    input rw,
    input [7:0] data_wr,
    output reg busy,
    output reg ack_error,
    inout sda,
    output scl
);

    localparam divider = (input_clk/bus_clk)/4;
    
    localparam READY = 0, START = 1, COMMAND = 2, SLV_ACK1 = 3;
    localparam WR = 4, SLV_ACK2 = 5, STOP = 6;
    
    reg [2:0] state;
    reg [15:0] count;
    reg scl_clk;
    reg scl_ena;
    reg sda_int;
    reg sda_ena_n;
    reg [7:0] addr_rw;
    reg [7:0] data_tx;
    reg [2:0] bit_cnt;
    wire sda_in;
    
    assign scl = (scl_ena == 1'b0) ? 1'b1 : scl_clk;
    assign sda = (sda_ena_n == 1'b0) ? sda_int : 1'bz;
    assign sda_in = sda;
    
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            count <= 0;
            scl_clk <= 1'b1;
        end else begin
            if (count == divider - 1) begin
                count <= 0;
                scl_clk <= ~scl_clk;
            end else begin
                count <= count + 1;
            end
        end
    end
    
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= READY;
            busy <= 1'b0;
            scl_ena <= 1'b0;
            sda_int <= 1'b1;
            sda_ena_n <= 1'b1;
            ack_error <= 1'b0;
            bit_cnt <= 7;
        end else begin
            if (count == divider - 1) begin
                case (state)
                    READY: begin
                        if (ena) begin
                            busy <= 1'b1;
                            addr_rw <= {addr, rw};
                            data_tx <= data_wr;
                            state <= START;
                        end else begin
                            busy <= 1'b0;
                            scl_ena <= 1'b0;
                        end
                    end
                    
                    START: begin
                        busy <= 1'b1;
                        scl_ena <= 1'b1;
                        sda_ena_n <= 1'b0;
                        sda_int <= 1'b0;
                        ack_error <= 1'b0;
                        state <= COMMAND;
                        bit_cnt <= 7;
                    end
                    
                    COMMAND: begin
                        sda_int <= addr_rw[bit_cnt];
                        if (bit_cnt == 0) begin
                            bit_cnt <= 7;
                            state <= SLV_ACK1;
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end
                    
                    SLV_ACK1: begin
                        sda_ena_n <= 1'b1;
                        ack_error <= sda_in;
                        if (rw == 1'b0) begin
                            state <= WR;
                        end else begin
                            state <= STOP;
                        end
                    end
                    
                    WR: begin
                        busy <= 1'b1;
                        sda_ena_n <= 1'b0;
                        sda_int <= data_tx[bit_cnt];
                        if (bit_cnt == 0) begin
                            bit_cnt <= 7;
                            state <= SLV_ACK2;
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end
                    
                    SLV_ACK2: begin
                        sda_ena_n <= 1'b1;
                        state <= STOP;
                    end
                    
                    STOP: begin
                        busy <= 1'b0;
                        sda_ena_n <= 1'b0;
                        sda_int <= 1'b1;
                        state <= READY;
                    end
                endcase
            end
        end
    end

endmodule
