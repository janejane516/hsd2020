`timescale 1ns / 1ps

module sw2led(
        input [7:0] SW,
        output [7:0] LD
    );
    assign LD = SW;
endmodule
