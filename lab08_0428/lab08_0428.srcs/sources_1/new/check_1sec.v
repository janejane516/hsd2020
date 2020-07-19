`timescale 1ns / 1ps

module check_1sec(
        input GCLK,
        input CENTER_PUSHBUTTON,
        output [7:0] LED
    );
    
    reg [31:0] cnt;
    reg [7:0] LED_tmp;
    
    always @(posedge GCLK) begin
        if(CENTER_PUSHBUTTON) begin
            cnt <= 32'd100000000;
            LED_tmp <= 0;
        end
        else if(cnt == 0) begin
            cnt <= 32'd100000000;
            LED_tmp <= LED_tmp + 1;
        end
        else begin
            cnt <= cnt - 1;
        end
    end
    
    assign LED = LED_tmp;
endmodule
