/////////////////////////////////////////////////////////////////////
///////////////////////TRANSACTION///////////////////////////////////

class transaction;
  rand logic d_in;
  logic d_out;
  
  function transaction copy();
    copy = new();
    copy.d_in  = this.d_in;
    copy.d_out = this.d_out;
  endfunction
  
  function void display(input string tag);
    $display("[%0s] : D_IN : %0b  D_OUT : %0b", tag, d_in, d_out);
  endfunction 
  
endclass

////////////////////////////////////////////////////////////////////////////
////////////////////////////GENERATOR///////////////////////////////////////

class generator;
  transaction tr;
  mailbox #(transaction) mbx_g2d;
  mailbox #(transaction) mbx_g2s_ref;
  
  event scowrk;
  event done;
  int count;
  function new(mailbox #(transaction) mbx_g2d, mailbox #(transaction) mbx_g2s_ref);
    this.mbx_g2d      = mbx_g2d;
    this.mbx_g2s_ref = mbx_g2s_ref;
    tr = new();
endfunction 
  
  task run();
    repeat(count) begin
      assert(tr.randomize) else $error("[GEN] : RANDOMIZATION FAILED");
      mbx_g2d.put(tr.copy);
      mbx_g2s_ref.put(tr.copy);
      tr.display("GEN");
      @(scowrk);
    end
    ->done;
  endtask
endclass

/////////////////////////////////////////////////////////////////////////////
///////////////////////////////DRIVER////////////////////////////////////////
  
class driver;
  transaction tr;
  mailbox #(transaction) mbx_g2d;
 virtual d_ff_inf vif;
  
  function new(mailbox #(transaction) mbx_g2d);
    this.mbx_g2d = mbx_g2d;
  endfunction
  
  task reset();
    vif.rst <= 1'b1;
    repeat(5) @(posedge vif.clk);
    vif.rst <= 1'b0;
    $display("[DRV] : RESET DONE"); 
  endtask
    
  task run();
    forever begin
      mbx_g2d.get(tr); 
      vif.d_in <= tr.d_in; 
      @(posedge vif.clk);
      tr.display("DRV"); 
      vif.d_in <= 1'b0; 
      @(posedge vif.clk); 
    end
  endtask
  
endclass

///////////////////////////////////////////////////////////////////////////////
/////////////////////////////MONITOR///////////////////////////////////////////
  
 class monitor;
  transaction tr; 
   mailbox #(transaction) mbx_m2s;
  virtual d_ff_inf vif; 
  
   function new(mailbox #(transaction) mbx_m2s);
    this.mbx_m2s = mbx_m2s;
  endfunction
  
  task run();
    tr = new(); 
    forever begin
      repeat(2) @(posedge vif.clk); 
      tr.d_out = vif.d_out; 
      mbx_m2s.put(tr); 
      tr.display("MON"); 
    end
  endtask
  
endclass 

//////////////////////////////////////////////////////////////////////////////
///////////////////////////////SCOREBOARD/////////////////////////////////////
  
class scoreboard;
  transaction tr; 
  transaction tr_ref; 
  mailbox #(transaction) mbx_m2s; 
  mailbox #(transaction) mbx_ref; 
  event scowrk; 
 
  function new(mailbox #(transaction) mbx_m2s, mailbox #(transaction) mbx_ref);
    this.mbx_m2s = mbx_m2s; 
    this.mbx_ref = mbx_ref; 
endfunction
  
  task run();
    forever begin
      mbx_m2s.get(tr); 
      mbx_ref.get(tr_ref); 
      tr.display("SCO"); 
      tr_ref.display("REF"); 
      if (tr.d_out == tr_ref.d_in)
        $display("[SCO] : DATA MATCHED"); 
      else
        $display("[SCO] : DATA MISMATCHED");
        $display("----------------------------------------------------");
        ->scowrk; 
      end
  endtask
  
endclass

///////////////////////////////////////////////////////////////////////////////
//////////////////////////////ENVIRONMENT//////////////////////////////////////

class environment;
  generator  g_1; 
  driver     d_1; 
  monitor    m_1; 
  scoreboard s_1; 
  event next; 
  mailbox #(transaction) g2d_mbx; 
  mailbox #(transaction) m2s_mbx; 
  mailbox #(transaction) mbx_ref; 
  
  virtual d_ff_inf vif; 
 
  function new(virtual d_ff_inf vif);
    g2d_mbx = new(); 
    mbx_ref = new();  
    g_1 = new(g2d_mbx, mbx_ref); 
    d_1 = new(g2d_mbx); 
    m2s_mbx = new(); 
    m_1 = new(m2s_mbx); 
    s_1 = new(m2s_mbx, mbx_ref); 
    this.vif = vif; 
    d_1.vif = this.vif; 
    m_1.vif = this.vif; 
    g_1.scowrk = next; 
    s_1.scowrk = next; 
  endfunction
  
  task pre_test();
    d_1.reset(); 
  endtask
  
  task test();
    fork
      g_1.run(); 
      d_1.run(); 
      m_1.run(); 
      s_1.run(); 
    join_any
  endtask
  
  task post_test();
    wait(g_1.done.triggered); 
    $finish(); 
  endtask
  
  task run();
    pre_test(); 
    test(); 
    post_test(); 
  endtask
endclass
 
////////////////////////////////////////////////////////////////////////////////////////////////////////MODULE_TOP////////////////////////////////////////////
 
module tb;
  d_ff_inf vif(); 
 
  d_ff dut(vif); 
  
  initial begin
    vif.clk <= 0;
  end
  
  always #10 vif.clk <= ~vif.clk; 
  
  environment e_1; 
 
  initial begin
    e_1 = new(vif); 
    e_1.g_1.count = 60; 
    e_1.run(); 
  end
  
  initial begin
    $dumpfile("dump.vcd"); 
    $dumpvars; 
  end
endmodule
  
 
