module fifo(input clk, rst, wr, rd,
            input [7:0] din, output reg [7:0] dout,
            output empty, full);
  
  reg [3:0] wr_ptr = 0, rd_ptr = 0;
  reg [4:0] cnt = 0;
  reg [7:0] mem [15:0];
 
  always @(posedge clk)
    begin
      if (rst == 1'b1)
        begin
          wr_ptr <= 0;
          rd_ptr <= 0;
          cnt  <= 0;
        end
      else if (wr && !full)
        begin
          mem[wr_ptr] <= din;
          wr_ptr      <= wr_ptr + 1;
          cnt       <= cnt + 1;
        end
      else if (rd && !empty)
        begin
          dout <= mem[rd_ptr];
          rd_ptr <= rd_ptr + 1;
          cnt  <= cnt - 1;
        end
    end
 
  assign empty = (cnt == 0) ? 1'b1 : 1'b0;
  assign full  = (cnt == 16) ? 1'b1 : 1'b0;
 
endmodule

/////////////////////////////////////////////////////////////////////////////////////////////////////////////INTERFACE//////////////////////////////////////

interface fifo_inf;
  logic clk, rd, wr;
  logic full, empty;
  logic [7:0] d_in;
  logic [7:0] d_out;
  logic rst;
endinterface
