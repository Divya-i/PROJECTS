///////////////////////////////////////////////////////////////////////////////////////////////////////////TRANSACTION////////////////////////////////////////

class transaction;
  rand bit oprtr;
  bit rd, wr;
  bit full,empty;
  bit [7:0] d_in;
  bit [7:0] d_out;
 
  constraint oprtr_cntrl { oprtr dist { 1 :/ 50, 0 : /50};}
  
endclass

 
///////////////////////////////////////////////////////////////////////////////////////////////////////////GENERATOR//////////////////////////////////////////
 
class generator;
  
  transaction tr;
  mailbox #(transaction) mbx_g2d;
  
  int count = 0;
  int i = 0;
  
  event next;
  event done;
  
  function new(mailbox #(transaction) mbx_g2d);
    this.mbx_g2d = mbx_g2d;
    tr = new();
    endfunction 
  
 
  task run(); 
    repeat (count) begin
      assert (tr.randomize) else $error("Randomization failed");
      i++;
      mbx_g2d.put(tr);
      $display("[GEN] : oprtr : %0d iteration : %0d", tr.oprtr, i);
      @(next);
    end
    -> done;
  endtask
  
endclass

/////////////////////////////////////////////////////////////////////////////////////////////////////////////DRIVER///////////////////////////////////////////
 
class driver;
  
  virtual fifo_inf finf;     
  mailbox #(transaction) mbx_g2d;  
  transaction data_c;       
 
  function new(mailbox #(transaction) mbx_g2d);
    this.mbx_g2d = mbx_g2d;
  endfunction; 
 
  task reset();
    finf.rst     <= 1'b1;
    finf.rd      <= 1'b0;
    finf.wr      <= 1'b0;
    finf.d_in    <= 0;
    repeat (5) @(posedge finf.clk);
    finf.rst <= 1'b0;
    $display("[DRV] : Reset Done");
    $display("------------------------------------------");
  endtask
   
  task write();
    @(posedge finf.clk);
    finf.rst <= 1'b0;
    finf.rd <= 1'b0;
    finf.wr <= 1'b1;
    finf.d_in <= $urandom_range(1, 20);
    @(posedge finf.clk);
    finf.wr <= 1'b0;
    $display("[DRV] : DATA WRITE  data : %0d", finf.d_in);  
    @(posedge finf.clk);
  endtask
  
  task read();  
    @(posedge finf.clk);
    finf.rst <= 1'b0;
    finf.rd  <= 1'b1;
    finf.wr  <= 1'b0;
    @(posedge finf.clk);
    finf.rd <= 1'b0;      
    $display("[DRV] : DATA READ");  
    @(posedge finf.clk);
  endtask
  
  task run();
    forever begin
      mbx_g2d.get(data_c);  
      if (data_c.oprtr == 1'b1)
        write();
      else
        read();
    end
  endtask
  
endclass
 
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////MONITOR//////////////////////////////////

class monitor;

  virtual fifo_inf finf;
  mailbox #(transaction) mbx_m2s;
  transaction tr;

  function new(mailbox #(transaction) mbx_m2s);
    this.mbx_m2s = mbx_m2s;
  endfunction;

  task run();
    tr = new();

    forever begin
      repeat (2) @(posedge finf.clk);
      tr.wr = finf.wr;
      tr.rd = finf.rd;
      tr.d_in = finf.d_in;
      tr.full = finf.full;
      tr.empty = finf.empty;
      @(posedge finf.clk);

      tr.d_out = finf.d_out;

      mbx_m2s.put(tr);
      $display("[MON] : Wr:%0d rd:%0d din:%0d dout:%0d full:%0d empty:%0d", tr.wr, tr.rd, tr.d_in, tr.d_out, tr.full, tr.empty);
    end

  endtask

endclass

 
/////////////////////////////////////////////////////////////////////////////////////////////////////////////SCOREBOARD///////////////////////////////////////



class scoreboard;
  
  mailbox #(transaction) mbx; 
  transaction tr;         
  event next;
  bit [7:0] din[$];       
  bit [7:0] temp;         
  int err = 0;            
  
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;     
  endfunction;
 
  task run();
    forever begin
      mbx.get(tr);
      $display("[SCO] : Wr:%0d rd:%0d din:%0d dout:%0d full:%0d empty:%0d", tr.wr, tr.rd, tr.d_in, tr.d_out, tr.full, tr.empty);
      
      if (tr.wr == 1'b1) begin
        if (tr.full == 1'b0) begin
          din.push_front(tr.d_in);
          $display("[SCO] : DATA STORED IN QUEUE :%0d", tr.d_in);
        end
        else begin
          $display("[SCO] : FIFO is full");
        end
        $display("--------------------------------------"); 
      end
    
      if (tr.rd == 1'b1) begin
        if (tr.empty == 1'b0) begin  
          temp = din.pop_back();
          
          if (tr.d_out == temp)
            $display("[SCO] : DATA MATCH");
          else begin
            $error("[SCO] : DATA MISMATCH");
            err++;
          end
        end
        else begin
          $display("[SCO] : FIFO IS EMPTY");
        end
        
        $display("--------------------------------------"); 
      end
      
      -> next;
    end
  endtask
  
endclass


 
////////////////////////////////////////////////////////////////////////////////////////////////////////////////ENVIRONMENT///////////////////////////////////
 
class environment;
 
  generator g_1;
  driver d_1;
  monitor m_1;
  scoreboard s_1;
  mailbox #(transaction) g2d_mbx;  
  mailbox #(transaction) m2s_mbx;  
  event next_tgs;
  virtual fifo_inf finf;
  
  function new(virtual fifo_inf finf);
    g2d_mbx = new();
    g_1 = new(g2d_mbx);
    d_1 = new(g2d_mbx);
    m2s_mbx = new();
    m_1 = new(m2s_mbx);
    s_1 = new(m2s_mbx);
    this.finf = finf;
    d_1.finf = this.finf;
    m_1.finf = this.finf;
    g_1.next = next_tgs;
    s_1.next = next_tgs;
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
    $display("---------------------------------------------");
    $display("Error Count :%0d", s_1.err);
    $display("---------------------------------------------");
    $finish();
  endtask
  
  task run();
    pre_test();
    test();
    post_test();
  endtask
  
endclass
 
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////MODULE_TOP///////////////////////////////////
 
module tb;
    
  fifo_inf finf();
  fifo dut (finf.clk, finf.rst, finf.wr, finf.rd, finf.d_in, finf.d_out, finf.empty, finf.full);
    
  initial begin
    finf.clk <= 0;
  end
    
  always #10 finf.clk <= ~finf.clk;
    
  environment e_1;
    
  initial begin
    e_1 = new(finf);
    e_1.g_1.count = 20;
    e_1.run();
  end
    
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end
   
endmodule