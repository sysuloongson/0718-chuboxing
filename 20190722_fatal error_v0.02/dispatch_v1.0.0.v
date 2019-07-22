`timescale 1ns / 1ns
`include "isa.h"
`include "cpu.h"


module dispatch(
input clk,
input rst_,
input flush,

//----from issue_queue----//
input [106:0] inst0_to_dispatch,
input [106:0] inst1_to_dispatch,

//---- output to issue_queue----//
output reg [1:0]  issue_enable,

input ex_allin,

//----------- output to EX -----------//
output reg        inst0_to_fu_delot_flag,
output reg        inst1_to_fu_delot_flag,
output reg [4:0]  inst0_to_fu_dst,
output reg [4:0]  inst1_to_fu_dst,
output reg [5:0]  inst0_to_fu_meaning,
output reg [5:0]  inst1_to_fu_meaning,
output reg [4:0]  inst0_to_fu_exe_code,
output reg [4:0]  inst1_to_fu_exe_code,
output reg [4:0]  inst0_to_fu_ptab_addr,
output reg [4:0]  inst1_to_fu_ptab_addr,
output reg [31:0] inst0_to_fu_pc,
output reg [31:0] inst1_to_fu_pc,
output reg        inst0_to_fu_valid,
output reg        inst1_to_fu_valid,



output reg [4:0]  inst0_to_fu_src0,
output reg [4:0]  inst0_to_fu_src1,
output reg [4:0]  inst1_to_fu_src0,
output reg [4:0]  inst1_to_fu_src1,
output reg [31:0] inst0_to_fu_imme,
output reg [31:0] inst1_to_fu_imme,
output reg [5:0]  inst0_to_fu_data_valid,
output reg [5:0]  inst1_to_fu_data_valid

);

//----dispatch data from issue_queue----//
wire [31:0] inst0_pc;
wire [31:0] inst0_imme;
wire [4:0]  inst0_dst;
wire [4:0]  inst0_src0;
wire [4:0]  inst0_src1;
wire [3:0]  inst0_type;
wire [5:0]  inst0_meaning;
wire [4:0]  inst0_ptab_addr;
wire [4:0]  inst0_exe_code;

wire        inst0_delot_flag;
wire        inst0_item_busy;
wire [5:0]  inst0_data_valid;
wire [5:0]  inst1_data_valid;

wire [31:0] inst1_pc;
wire [31:0] inst1_imme;
wire [4:0]  inst1_dst;
wire [4:0]  inst1_src0;
wire [4:0]  inst1_src1;
wire [3:0]  inst1_type;
wire [5:0]  inst1_meaning;
wire [4:0]  inst1_ptab_addr;
wire [4:0]  inst1_exe_code;

wire        inst1_delot_flag;
wire        inst1_item_busy;


//----conflict_detect----//
reg inst0_load_store_detect;
reg inst1_load_store_detect;




wire inst0_issue_enable;
wire inst1_issue_enable;


assign inst0_issue_enable = ex_allin & inst0_item_busy;
assign inst1_issue_enable = (inst0_issue_enable & inst1_item_busy & ( !inst0_load_store_detect )&  (!inst1_load_store_detect))? 1'b1 :
                            (inst0_issue_enable & inst1_item_busy &  (!inst0_load_store_detect) &   (inst1_load_store_detect))? 1'b1 :
                            (inst0_issue_enable & inst1_item_busy &   inst0_load_store_detect & (!inst1_load_store_detect))? 1'b1 :
                            (inst0_issue_enable & inst1_item_busy &   inst0_load_store_detect &   inst1_load_store_detect)? 1'b0 : 1'b0;

//----arbitrate----//


always@(*)begin
	if((inst0_issue_enable)&&(inst1_issue_enable))begin
		issue_enable = 2'b10;
	end
	else if((inst0_issue_enable)&&(!inst1_issue_enable))begin
		issue_enable = 2'b01;
	end
	else begin
		issue_enable = 2'b00;
	end
end

always @ (*)begin
	if(inst0_item_busy)begin
		case(inst0_meaning)
			`INSN_LB : inst0_load_store_detect = 1'b1;
			`INSN_LBU: inst0_load_store_detect = 1'b1;
			`INSN_LH : inst0_load_store_detect = 1'b1;
			`INSN_LHU: inst0_load_store_detect = 1'b1;
			`INSN_LW : inst0_load_store_detect = 1'b1;
			`INSN_SB : inst0_load_store_detect = 1'b1;
			`INSN_SH : inst0_load_store_detect = 1'b1;
			`INSN_SW : inst0_load_store_detect = 1'b1;
			default  : inst0_load_store_detect = 1'b0;
		endcase
	end
	else begin
		inst0_load_store_detect = 1'b0;
	end
	
	if(inst1_item_busy)begin
		case(inst0_meaning)
			`INSN_LB : inst1_load_store_detect = 1'b1;
			`INSN_LBU: inst1_load_store_detect = 1'b1;
			`INSN_LH : inst1_load_store_detect = 1'b1;
			`INSN_LHU: inst1_load_store_detect = 1'b1;
			`INSN_LW : inst1_load_store_detect = 1'b1;
			`INSN_SB : inst1_load_store_detect = 1'b1;
			`INSN_SH : inst1_load_store_detect = 1'b1;
			`INSN_SW : inst1_load_store_detect = 1'b1;
			default  : inst1_load_store_detect = 1'b0;
		endcase
	end
	else begin
		inst1_load_store_detect = 1'b0;
	end

	
end



//----input from issue_queue----//
//assign {inst0_pc,inst0_dst,inst0_src0,inst0_src1,inst0_imme,inst0_type,inst0_meaning,inst0_data_valid,inst0_ptab_addr,inst0_exe_code,inst0_delot_flag,inst0_item_busy} = inst0_to_dispatch;
//assign {inst1_pc,inst1_dst,inst1_src0,inst1_src1,inst1_imme,inst1_type,inst1_meaning,inst1_data_valid,inst1_ptab_addr,inst1_exe_code,inst1_delot_flag,inst1_item_busy} = inst1_to_dispatch;

assign inst0_pc         = inst0_to_dispatch [106:75];
assign inst0_dst        = inst0_to_dispatch [74:70];
assign inst0_src0       = inst0_to_dispatch [69:65];
assign inst0_src1       = inst0_to_dispatch [64:60];
assign inst0_imme       = inst0_to_dispatch [59:28];
assign inst0_type       = inst0_to_dispatch [27:24];
assign inst0_meaning    = inst0_to_dispatch [23:18];
assign inst0_data_valid = inst0_to_dispatch [17:12];
assign inst0_ptab_addr  = inst0_to_dispatch [11:7];
assign inst0_exe_code   = inst0_to_dispatch [6:2];
assign inst0_delot_flag = inst0_to_dispatch [1];
assign inst0_item_busy  = inst0_to_dispatch [0];


assign inst1_pc         = inst1_to_dispatch [106:75];
assign inst1_dst        = inst1_to_dispatch [74:70];
assign inst1_src0       = inst1_to_dispatch [69:65];
assign inst1_src1       = inst1_to_dispatch [64:60];
assign inst1_imme       = inst1_to_dispatch [59:28];
assign inst1_type       = inst1_to_dispatch [27:24];
assign inst1_meaning    = inst1_to_dispatch [23:18];
assign inst1_data_valid = inst1_to_dispatch [17:12];
assign inst1_ptab_addr  = inst1_to_dispatch [11:7];
assign inst1_exe_code   = inst1_to_dispatch [6:2];
assign inst1_delot_flag = inst1_to_dispatch [1];
assign inst1_item_busy  = inst1_to_dispatch [0];


/*
assign inst0_to_dispatch = {pc[0],dst[0],src0[0],src1[0],imme[0],type[0],inst_meaning[0],data_valid[0],ptab_addr[0],exe_code[0],delot_flag[0],item_busy[0]};
assign inst1_to_dispatch = {pc[1],dst[1],src0[1],src1[1],imme[1],type[1],inst_meaning[1],data_valid[1],ptab_addr[1],exe_code[1],delot_flag[1],item_busy[1]};
*/
always @ (posedge clk )begin
	if(!rst_)begin
		inst0_to_fu_pc 			  <= 32'b0;
		inst0_to_fu_ptab_addr     <= 5'b00000;
		inst0_to_fu_dst		      <= 5'b00000;
		inst0_to_fu_exe_code      <= 5'b00000;
		inst0_to_fu_imme	      <= 32'b0;
		inst0_to_fu_meaning       <= 6'b00000;
		inst0_to_fu_src0		  <= 5'b00000;
		inst0_to_fu_src1          <= 5'b00000;
		inst0_to_fu_data_valid    <= 6'b00000;
		inst0_to_fu_valid         <= 1'b0;
		inst0_to_fu_delot_flag    <= 1'b0;
	end
	else if(inst0_issue_enable)begin			
		inst0_to_fu_pc 				 <= inst0_pc;
		inst0_to_fu_ptab_addr        <= inst0_ptab_addr;
		inst0_to_fu_dst				 <= inst0_dst;
		inst0_to_fu_exe_code         <= inst0_exe_code;
		inst0_to_fu_imme			 <= inst0_imme;
		inst0_to_fu_meaning          <= inst0_meaning;
		inst0_to_fu_src0			 <= inst0_src0;
		inst0_to_fu_src1             <= inst0_src1;
		inst0_to_fu_data_valid       <= inst0_data_valid;
		inst0_to_fu_valid            <= inst0_item_busy;
		inst0_to_fu_delot_flag       <= inst0_delot_flag;
	end
	else begin
		inst0_to_fu_pc 			  <= 32'b0;
		inst0_to_fu_ptab_addr     <= 5'b00000;
		inst0_to_fu_dst		      <= 5'b00000;
		inst0_to_fu_exe_code      <= 5'b00000;
		inst0_to_fu_imme	      <= 32'b0;
		inst0_to_fu_meaning       <= 6'b00000;
		inst0_to_fu_src0		  <= 5'b00000;
		inst0_to_fu_src1          <= 5'b00000;
		inst0_to_fu_data_valid    <= 6'b00000;
		inst0_to_fu_valid         <= 1'b0;
		inst0_to_fu_delot_flag    <= 1'b0;
	end
	
	
	if(!rst_)begin
		inst1_to_fu_pc 			  <= 32'b0;
		inst1_to_fu_ptab_addr     <= 5'b00000;
		inst1_to_fu_dst           <= 5'b00000;
		inst1_to_fu_exe_code      <= 5'b00000;
		inst1_to_fu_imme          <= 32'b0;
		inst1_to_fu_meaning       <= 6'b00000;
		inst1_to_fu_src0		  <= 5'b00000;
		inst1_to_fu_src1          <= 5'b00000;
		inst1_to_fu_data_valid    <= 6'b00000;
		inst1_to_fu_valid         <= 1'b0;
		inst1_to_fu_delot_flag    <= 1'b0;
	end		
	else if(inst0_issue_enable)begin			
		inst1_to_fu_pc 				 <= inst1_pc;
		inst1_to_fu_ptab_addr        <= inst1_ptab_addr;
		inst1_to_fu_dst				 <= inst1_dst;
		inst1_to_fu_exe_code         <= inst1_exe_code;
		inst1_to_fu_imme			 <= inst1_imme;
		inst1_to_fu_meaning          <= inst1_meaning;
		inst1_to_fu_src0			 <= inst1_src0;
		inst1_to_fu_src1             <= inst1_src1;
		inst1_to_fu_data_valid       <= inst1_data_valid;
		inst1_to_fu_valid            <= inst1_item_busy;
		inst1_to_fu_delot_flag       <= inst1_delot_flag;
	end
	else begin
		inst1_to_fu_pc 			  <= 32'b0;
		inst1_to_fu_ptab_addr     <= 5'b00000;
		inst1_to_fu_dst           <= 5'b00000;
		inst1_to_fu_exe_code      <= 5'b00000;
		inst1_to_fu_imme          <= 32'b0;
		inst1_to_fu_meaning       <= 6'b00000;
		inst1_to_fu_src0		  <= 5'b00000;
		inst1_to_fu_src1          <= 5'b00000;
		inst1_to_fu_data_valid    <= 6'b00000;
		inst1_to_fu_valid         <= 1'b0;
		inst1_to_fu_delot_flag    <= 1'b0;
	end	
end






endmodule