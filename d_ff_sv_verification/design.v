// Code your design here
module d_ff(d_ff_inf vif);
  always @(posedge vif.clk)
    begin
      if (vif.rst == 1'b1)
        vif.d_out <= 1'b0;
      else 
        vif.d_out <= vif.d_in;
    end

endmodule 

///////////////////////////////////////////////////////////////////////////
//////////////////////////////INTERFACE////////////////////////////////////

interface d_ff_inf;
  logic clk;
  logic rst;
  logic d_in;
  logic d_out;
  
endinterface