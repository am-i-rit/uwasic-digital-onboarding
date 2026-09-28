`default_nettype none

// module should serially receive 16-bit write commands and update appropriate registers
module spi_peripheral (
    input wire clk, // internal clock (10 MHz)
    input wire sclk, // external clock
    input wire rst_n, // reset_n (low to reset)
    input wire copi, // takes in the output from controller
    input wire ncs, // chip select

    output reg [7:0] en_reg_out_7_0, // register for the outputs first 8 bits
    output reg [7:0] en_reg_out_15_8, // register for the outputs second 8 bits
    output reg [7:0] en_reg_pwm_7_0,
    output reg [7:0] en_reg_pwm_15_8,
    output reg [7:0] pwm_duty_cycle // basically % of pwm period where output is high??
);

    localparam [6:0] max_address = 7'h04; // maximum valid register address

    // registers for synchronization
    reg ncs_sync1;
    reg ncs_sync2;
    reg ncs_prev; // for edge detection
    reg copi_sync1;
    reg copi_sync2;
    reg sclk_sync1;
    reg sclk_sync2;
    reg sclk_prev; // for edge detection

    // synchonization block 
    always @(posedge clk or negedge rst_n) begin // happens when clk 0 -> 1 or rst_n 1 -> 0
        if (!rst_n) begin
            ncs_sync1 <= 1; ncs_sync2 <= 1; ncs_prev <= 1;
            copi_sync1 <= 0; copi_sync2 <= 0;
            sclk_sync1 <= 0; sclk_sync2 <= 0; sclk_prev <= 0;
        end
        else begin
            ncs_sync1 <= ncs; ncs_sync2 <= ncs_sync1; ncs_prev <= ncs_sync2;
            copi_sync1 <= copi; copi_sync2 <= copi_sync1;
            sclk_sync1 <= sclk; sclk_sync2 <= sclk_sync1; sclk_prev <= sclk_sync2;
        end
    end

    // wires for rising/falling edges so we can make transactions
    wire ncs_rise = (ncs_sync2 && !ncs_prev);
    wire ncs_fall = (ncs_prev && !ncs_sync2);
    wire sclk_rise = (sclk_sync2 && !sclk_prev);

    reg [15:0] bit_storage;  // stores the 16 received bits
    reg [4:0] bit_count; // represents 0 through 16

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // reset transaction state and output regs
            bit_count <= 5'd0;
            bit_storage <= 16'd0;

            en_reg_out_7_0  <= 8'h00;
            en_reg_out_15_8 <= 8'h00;
            en_reg_pwm_7_0  <= 8'h00;
            en_reg_pwm_15_8 <= 8'h00;
            pwm_duty_cycle  <= 8'h00;

        end 
        else if (ncs_fall) begin
            // begin new transaction
            bit_count <= 5'd0;
            bit_storage <= 16'd0;

        end 
        else if (!ncs_sync2 && sclk_rise) begin
            // read bit stored in copi and add to storage register
            bit_storage <= {bit_storage[14:0], copi_sync2};
            bit_count <= bit_count + 1'b1;

        end 
        else if (ncs_rise) begin
            if (bit_count == 5'd16) begin // if we've received all 16 bits in message
                if (bit_storage[15] && 
                    (bit_storage[14:8] <= max_address)) begin

                    case (bit_storage[14:8])
                        7'h00: en_reg_out_7_0 <= bit_storage[7:0];
                        7'h01: en_reg_out_15_8 <= bit_storage[7:0];
                        7'h02: en_reg_pwm_7_0 <= bit_storage[7:0];
                        7'h03: en_reg_pwm_15_8 <= bit_storage[7:0];
                        7'h04: pwm_duty_cycle <= bit_storage[7:0];
                        default: ; // just being safe, in theory this shouldn't even be accessible
                    endcase
                end
            end
        end
    end

endmodule



