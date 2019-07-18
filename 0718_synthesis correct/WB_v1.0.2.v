`define ISA_EXC_NO_EXC	   5'h10	// No exception
`define ISA_EXC_INT	   	   5'h00	// Interuption
`define ISA_EXC_RI 		   5'h0a	// Reserve
`define ISA_EXC_OV                5'h0c	// Arithmetic overflow
`define ISA_EXC_ADEL            5'h04	// Aligned Data Error of Load
`define ISA_EXC_ADES	           5'h05	// Aligned Data Error of Read
`define ISA_EXC_SYS	           5'h08	// System Call
`define ISA_EXC_BP                5'h09	// Break Point

`define ISA_OP_LB   	   6'h20 // 
`define ISA_OP_LBU		   6'h24 // 
`define ISA_OP_LH		   6'h21 // 
`define ISA_OP_LHU		   6'h25 // 
`define ISA_OP_LW		   6'h23 // 
`define ISA_OP_SB		   6'h28 // 
`define ISA_OP_SH		   6'h29 // 
`define ISA_OP_SW		   6'h2b // 
	
/*********       ISA      define       ************/
`define ISA_EXC_ERET               5'h0d
/*********       Internal define        ************/
`define WordAddrBus_2way			63:0
`define WordAddrBus_way0           31:0
`define WordAddrBus_way1          63:32
`define AluOpBus_2way              11:0
`define AluOpBus_way0               5:0
`define AluOpBus_way1              11:6
`define WordDataBus_2way           63:0
`define WordDataBus_way0           31:0
`define WordDataBus_way1          63:32
`define DestAddr                    4:0
`define DestAddr_2way               9:0
`define DestAddr_way0               4:0
`define DestAddr_way1               9:5
`define isbrflag_2way               1:0
`define MemOpBus_2way               3:0
`define CtrlOpBus_2way              3:0
`define RegAddrBus_2way             9:0
`define IsaExpBus_2way              9:0
`define IsaExpBus_way0              4:0
`define IsaExpBus_way1              9:5
`define UnCache2WayBus		         1:0 
`define UnCacheCheckWay0	       31:16
`define UnCacheCheckWay1	       63:48
`define DestValid_2way              1:0
`define FUen                        3:0
`define FUen_MUL                    2
`define FUen_DIV                    3
`define BranchCond_2Way             1:0    
`define En2Bus                      1:0
`define PtabaddrBus_2way		     9:0
`define PtabdataBus_2way		   128:0
`define PtabdataBus_way0		    63:0
`define PtabdataBus_way1		  127:64
`define Ptabnextpc_way0	        31:0
`define Ptabnextpc_way1	       95:64
`define Delotflag_2Way              1:0    
`define FUselect_2way               3:0
`define 	RwenBus_2way             7:0
`define 	RwenBus_way0             3:0
`define 	RwenBus_way1             7:4
`define     offset_way0             1:0
`define     offset_way1           33:32
module write_back_to_register(
	input clk,
	input rst_,
	input flush,
	
	//----EX---//
    input [`WordDataBus_2way] alu_result,
	input [`WordDataBus_2way] mul_result,
	input [`WordDataBus_2way] div_result,
	input [`BranchCond_2Way]  ex_branchcond,
	input [`BranchCond_2Way]  ex_bp_result,
	input [`WordDataBus_2way] ex_wr_data,		
	input [`RwenBus_2way]     ex_rwen,
	input [`DestAddr_2way]	  ex_Dest_out,
	input [`DestValid_2way]	  ex_Dest_valid,
	input [`DestValid_2way]	  ex_Dest_data_valid,
	input [`Delotflag_2Way]   ex_delot_flag,
	input [`FUselect_2way]    ex_fu_select,
	input [`WordAddrBus_2way] ex_pc,
	input [`AluOpBus_2way]	  ex_op,
	input [`IsaExpBus_2way]   ex_exp_code,
	input [`UnCache2WayBus]   uncacheable,
	output reg       wb_allin,
	
	//----register-file----//
	output reg [4:0] write_addr0,
	output reg [4:0] write_addr1,
	output reg write_addr0_valid,
	output reg write_addr1_valid,
	output reg [31:0] write_data0,
	output reg [31:0] write_data1,
	output reg [63:0] write_hilo_data,
	output reg write_hilo_enable,
	
	//----store_buffer----//
	input store_buffer_allow_in,
	output reg [31:0] in_store_data,
	output reg [31:0] in_store_addr,
	output reg [3:0]  in_store_rwen,
	output reg        in_store_uncache,
	output reg        in_valid,
	
	//----cache-----//
	input        store_buffer_hit,
	input [31:0] store_buffer_load_data,
	input        load_mem_data_ok,
	input        load_mem_addr_ok,
	input        load_uncache_rd_data,
	input [31:0] load_mem_rd_data,
	
	output reg [31:0] store_buffer_load_addr,
	output reg        store_buffer_search_enanble,
	output reg [3:0]  load_mem_rwen,
	output reg        load_mem_rw,
	output reg        load_mem_en,
	output reg [31:0] load_mem_addr,	
	output reg        load_uncache_en,
	
	// ysr jia de
	output reg [31:0] wb_cp0_wdata_1,
	output reg [31:0] wb_cp0_wdata_0,
	output reg [31:0]  wb_cp0_waddr_1,
	output reg [31:0]  wb_cp0_waddr_0,
	output wire         wb_cp0_we,
	output  wire [31:0] wb_pc

);
	
	wire [4:0] inst0_exe_code;
	wire [4:0] inst1_exe_code;
	wire inst0_retire_enable;
	wire inst1_retire_enable;
	reg inst0_exe_detect;
	reg inst1_exe_detect;
	reg [`WordDataBus] load_data; //fresh
//----exe detect----//	
assign inst1_exe_code = ex_exp_code[9:5];
assign inst0_exe_code = ex_exp_code[4:0];
assign inst0_retire_enable = ~inst0_exe_detect;
assign inst1_retire_enable = ((inst0_retire_enable)&&(!inst1_exe_detect))? 1'b1 : 1'b0;

always @(*)begin
	case (inst0_exe_code)
		`ISA_EXC_NO_EXC: inst0_exe_detect = 1'b0;
		`ISA_EXC_INT,`ISA_EXC_RI,`ISA_EXC_OV,`ISA_EXC_ADEL,`ISA_EXC_ADES,`ISA_EXC_SYS,`ISA_EXC_BP: inst0_exe_detect = 1'b1;
		default: inst0_exe_detect = 1'b1;
	endcase
	
	case (inst1_exe_code)
		`ISA_EXC_NO_EXC: inst1_exe_detect = 1'b0;
		`ISA_EXC_INT,`ISA_EXC_RI,`ISA_EXC_OV,`ISA_EXC_ADEL,`ISA_EXC_ADES,`ISA_EXC_SYS,`ISA_EXC_BP: inst1_exe_detect = 1'b1;
		default: inst1_exe_detect = 1'b1;
	endcase	
end

//----write_data_to_register----//
wire [1:0] inst0_fu_select;
wire [1:0] inst1_fu_select;
wire [4:0] inst0_write_addr;
wire [4:0] inst1_write_addr;
wire       inst0_write_addr_valid;
wire       inst1_write_addr_valid;

wire [31:0] alu0_result;
wire [31:0] alu1_result;  //fresh

assign alu0_result = alu_result[31:0];
assign alu1_result = alu_result[63:32];

assign inst0_fu_select = ex_fu_select[1:0];
assign inst1_fu_select = ex_fu_select[3:2];

assign inst0_write_addr = ex_Dest_out[4:0];
assign inst1_write_addr = ex_Dest_out[9:5];

assign inst0_write_addr_valid = ex_Dest_valid[0];
assign inst1_write_addr_valid = ex_Dest_valid[1];

always @(*)begin
	if((inst0_retire_enable)&&(inst1_retire_enable))begin
	
		if(inst0_load_store_detect == 2'b00)begin
			write_addr0 = (inst0_write_addr_valid)? inst0_write_addr : 5'b0;
			write_addr0_valid = inst0_write_addr_valid;
			write_data0 = (inst0_fu_select == 2'b00)? alu0_result :
			              (inst0_fu_select == 2'b01)? alu1_result : 32'b0;
		end
		else if(inst0_load_detect)begin
			write_addr0       = inst0_write_addr;
			write_addr0_valid = inst0_write_addr_valid;
			write_data0       = load_data;
		end
		else begin
			write_addr0       = 5'b0;
			write_addr0_valid = 1'b0;
			write_data0       = 32'b0;
		end		
		
		if(inst1_load_store_detect == 2'b00)begin	
			write_addr1 = (inst1_write_addr_valid)? inst1_write_addr : 5'b0;
			write_addr1_valid = inst1_write_addr_valid;
			write_data1 = (inst1_fu_select == 2'b00)? alu0_result :
			              (inst1_fu_select == 2'b01)? alu1_result : 32'b0;
		end		
		else if(inst1_load_detect)begin
			write_addr1       = inst1_write_addr;
			write_addr1_valid = inst1_write_addr_valid;
			write_data1       = load_data;
		end
		else begin
			write_addr1       = 5'b0;
			write_addr1_valid = 1'b0;
			write_data1       = 32'b0;
		end
		
		write_hilo_enable = ((inst1_fu_select == 2'b10)||(inst1_fu_select == 2'b11)||(inst0_fu_select == 2'b10)||(inst0_fu_select == 2'b11))? 1'b1 : 1'b0;
		write_hilo_data = (inst1_fu_select == 2'b10)? mul_result : 
						  (inst1_fu_select == 2'b11)? div_result : 
						  (inst0_fu_select == 2'b10)? mul_result : 
						  (inst0_fu_select == 2'b10)? div_result : 64'b0;
		
	end
	else if((inst0_retire_enable)&&(!inst1_retire_enable))begin
	
		if(inst0_load_store_detect == 2'b00)begin
			write_addr0 = (inst0_write_addr_valid)? inst0_write_addr : 5'b0;
			write_addr0_valid = inst0_write_addr_valid;
			write_data0 = (inst0_fu_select == 2'b00)? alu0_result :
			              (inst0_fu_select == 2'b01)? alu1_result : 32'b0;
		end
		else if(inst0_load_detect)begin
			write_addr0       = inst0_write_addr;
			write_addr0_valid = inst0_write_addr_valid;
			write_data0       = load_data;
		end
		else begin
			write_addr0       = 5'b0;
			write_addr0_valid = 1'b0;
			write_data0       = 32'b0;
		end			
	
		write_hilo_enable = ((inst0_fu_select == 2'b10)||(inst0_fu_select == 2'b11))? 1'b1 : 1'b0;
		write_hilo_data = (inst0_fu_select == 2'b10)? mul_result : 
						  (inst0_fu_select == 2'b10)? div_result : 64'b0;
			
	end
	else begin
		write_addr0       = 5'b0;
		write_addr0_valid = 1'b0;
		write_data0       = 32'b0;
		
		write_addr1       = 5'b0;
		write_addr1_valid = 1'b0;
		write_data1       = 32'b0;
		
		write_hilo_enable = 1'b0;
		write_hilo_data   = 64'b0;
	end
end


//----load and store detect----//
wire [5:0] inst0_op;
wire [5:0] inst1_op;
assign inst0_op = ex_op[5:0];
assign inst1_op = ex_op[11:6];

reg [1:0] inst0_load_store_detect;
reg [1:0] inst1_load_store_detect;
wire inst0_load_detect;
wire inst1_load_detect;
wire inst0_store_detect;
wire inst1_store_detect;

assign inst0_load_detect  = inst0_load_store_detect[0];
assign inst1_load_detect  = inst1_load_store_detect[0];
assign inst0_store_detect = inst0_load_store_detect[1];
assign inst1_store_detect = inst1_load_store_detect[1];

always @(*)begin
	case (inst0_op)
		`ISA_OP_LB : inst0_load_store_detect = 2'b01;//01 <- load 
		`ISA_OP_LBU: inst0_load_store_detect = 2'b01;//10 <- store
		`ISA_OP_LH : inst0_load_store_detect = 2'b01;
		`ISA_OP_LHU: inst0_load_store_detect = 2'b01;
		`ISA_OP_LW : inst0_load_store_detect = 2'b01;
		`ISA_OP_SB : inst0_load_store_detect = 2'b10;
		`ISA_OP_SH : inst0_load_store_detect = 2'b10;
		`ISA_OP_SW : inst0_load_store_detect = 2'b10;
		default    : inst0_load_store_detect = 2'b00;
	endcase
	
	case (inst1_op)
		`ISA_OP_LB : inst1_load_store_detect = 2'b01;//01 <- load 
		`ISA_OP_LBU: inst1_load_store_detect = 2'b01;//10 <- store
		`ISA_OP_LH : inst1_load_store_detect = 2'b01;
		`ISA_OP_LHU: inst1_load_store_detect = 2'b01;
		`ISA_OP_LW : inst1_load_store_detect = 2'b01;
		`ISA_OP_SB : inst1_load_store_detect = 2'b10;
		`ISA_OP_SH : inst1_load_store_detect = 2'b10;
		`ISA_OP_SW : inst1_load_store_detect = 2'b10;
		default    : inst1_load_store_detect = 2'b00;
	endcase
end


//----load data from mem or cache----//
always @(*)begin
	if((inst0_retire_enable)&&(inst0_load_detect))begin
		store_buffer_load_addr = (inst0_fu_select == 2'b00)? alu0_result  : (inst0_fu_select == 2'b01)? alu1_result  : 32'b0;
		store_buffer_search_enanble = 1'b1;
	end
	else if((inst1_retire_enable)&&(inst1_load_detect))begin
		store_buffer_load_addr = (inst1_fu_select == 2'b00)? alu0_result  : (inst1_fu_select == 2'b01)? alu1_result  : 32'b0;
		store_buffer_search_enanble = 1'b1;
	end
	else begin
		store_buffer_load_addr = 32'b0;
		store_buffer_search_enanble = 1'b0;
	end
end


always@(*)begin
	if(store_buffer_search_enanble)begin
		load_mem_addr = (!store_buffer_hit)? store_buffer_load_addr: 32'b0;
		load_mem_rwen = ((!store_buffer_hit)&&(inst0_fu_select == 2'b00))? alu0_ex_rwen : ((!store_buffer_hit)&&(inst0_fu_select == 2'b01))? alu1_ex_rwen : 4'b0;
		load_mem_rw   = ~store_buffer_hit;
		load_mem_en   = ~store_buffer_hit;	
	end
	else begin
		load_mem_addr = 32'b0;
		load_mem_rwen = 4'b0;
		load_mem_rw   = 1'b0;
		load_mem_en   = 1'b0;
	end
end

always@(*)begin
	if((inst0_load_detect)&&(inst1_load_detect))begin
		load_data = (store_buffer_hit)? store_buffer_load_data : (load_mem_data_ok)? load_mem_rd_data : 32'b0;
	end
	else begin
		load_data = 32'b0;
	end
end

always @(posedge clk)begin
	if((inst0_load_detect)||(inst1_load_detect))begin
		wb_allin <= (store_buffer_hit)? 1'b1 : (load_mem_data_ok)? 1'b1 : 1'b0;
	end
	else if ((inst0_store_detect)||(inst1_store_detect))begin
		wb_allin <= store_buffer_allow_in;
	end
	else begin
		wb_allin <= 1'b1;
	end
end

//----data to store_buffer----//
wire [31:0] alu0_wr_data;
wire [31:0] alu1_wr_data;
wire [3:0]  alu0_ex_rwen;
wire [3:0]  alu1_ex_rwen;
wire        alu0_uncacheable;
wire        alu1_uncacheable;


assign alu0_wr_data = ex_wr_data[31:0];
assign alu1_wr_data = ex_wr_data[63:32];

assign alu0_ex_rwen = ex_rwen[3:0];
assign alu1_ex_rwen = ex_rwen[7:4];

assign alu0_uncacheable = uncacheable[0];
assign alu1_uncacheable = uncacheable[1];
always @(*)begin
	if((inst0_retire_enable)&&(inst0_store_detect))begin
		in_store_data    = (inst0_fu_select == 2'b00)? alu0_wr_data : (inst0_fu_select == 2'b01)? alu1_wr_data : 32'b0;
		in_store_addr    = (inst0_fu_select == 2'b00)? alu0_result  : (inst0_fu_select == 2'b01)? alu1_result  : 32'b0;
		in_store_rwen    = (inst0_fu_select == 2'b00)? alu0_ex_rwen : (inst0_fu_select == 2'b01)? alu1_ex_rwen : 32'b0;
		in_store_uncache = (inst0_fu_select == 2'b00)? alu0_uncacheable : (inst0_fu_select == 2'b01)? alu1_uncacheable : 32'b0;
		in_valid         = 	1'b1;
	end
	else if((inst1_retire_enable)&&(inst1_store_detect))begin
		in_store_data    = (inst1_fu_select == 2'b00)? alu0_wr_data : (inst0_fu_select == 2'b01)? alu1_wr_data : 32'b0;
		in_store_addr    = (inst1_fu_select == 2'b00)? alu0_result  : (inst0_fu_select == 2'b01)? alu1_result  : 32'b0;
		in_store_rwen    = (inst1_fu_select == 2'b00)? alu0_ex_rwen : (inst0_fu_select == 2'b01)? alu1_ex_rwen : 32'b0;
		in_store_uncache = (inst1_fu_select == 2'b00)? alu0_uncacheable : (inst0_fu_select == 2'b01)? alu1_uncacheable : 32'b0;
		in_valid         = 	1'b1;
	end
	else begin
		in_store_data    = 32'b0;
		in_store_addr    = 32'b0;
		in_store_rwen    = 32'b0;
		in_store_uncache = 32'b0;
		in_valid         = 1'b0;
	end


end

endmodule