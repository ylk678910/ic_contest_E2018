module LCD_CTRL(clk,
                reset,
                cmd,
                cmd_valid,
                IROM_Q,
                IROM_rd,
                IROM_A,
                IRAM_valid,
                IRAM_D,
                IRAM_A,
                busy,
                done);
    input clk;
    input reset;
    input [3:0] cmd;
    input cmd_valid;
    input [7:0] IROM_Q;
    output IROM_rd;
    output [5:0] IROM_A;
    output IRAM_valid;
    output [7:0] IRAM_D;
    output [5:0] IRAM_A;
    output busy;
    output done;
    
    localparam TRUE  = 1'b1;
    localparam FALSE = 1'b0;
    
    localparam WRITE              = 4'h0;
    localparam SHIFT_UP           = 4'h1;
    localparam SHIFT_DOWN         = 4'h2;
    localparam SHIFT_LEFT         = 4'h3;
    localparam SHIFT_RIGHT        = 4'h4;
    localparam MAX                = 4'h5;
    localparam MIN                = 4'h6;
    localparam AVG                = 4'h7;
    localparam COUNTERCLOCKWISE_R = 4'h8;
    localparam CLOCKWISE_R        = 4'h9;
    localparam MIRROR_X           = 4'ha;
    localparam MIRROR_Y           = 4'hb;
    localparam WAIT_CMD           = 4'hc;
    localparam STORE_PIXEL        = 4'hd;
    
    reg storeing_flg, cmd_cmp_flg;
    
    //busy control
    reg busy_tmp;
    assign busy = busy_tmp;
    always @(posedge clk) begin
        if (reset) begin
            busy_tmp <= TRUE;
        end
        else begin
            if (storeing_flg || cmd_valid) begin
                busy_tmp <= TRUE;
            end
            else if (cmd_cmp_flg) begin
                busy_tmp <= FALSE;
            end
            else begin
                busy_tmp <= busy_tmp;
            end
        end
    end
    
    //store pixel
    reg IROM_rd_tmp;
    reg [5:0] IROM_A_tmp;
    reg [7:0] pixel_mem[63:0];
    assign IROM_rd = IROM_rd_tmp;
    assign IROM_A  = IROM_A_tmp;
    always @(posedge clk) begin
        if (reset) begin
            IROM_rd_tmp <= TRUE;
        end
        else begin
            if (IROM_A_tmp == 6'd63) begin
                IROM_rd_tmp <= FALSE;
            end
            else begin
                IROM_rd_tmp <= IROM_rd_tmp;
            end
        end
    end
    always @(posedge clk) begin
        if (reset) begin
            IROM_A_tmp <= 6'd0;
        end
        else begin
            if (IROM_rd_tmp) begin
                IROM_A_tmp <= IROM_A_tmp + 6'd1;
            end
            else begin
                IROM_A_tmp <= 6'd0;
            end
        end
    end
    always @(*) begin
        storeing_flg = IROM_rd_tmp;
    end
    
    //cmd control
    reg [1:0] times;
    reg [5:0] pixel_ptr;
    reg [3:0] cur_state, next_state;
    always @(posedge clk) begin
        if (reset) begin
            cur_state <= STORE_PIXEL;
        end
        else begin
            cur_state <= next_state;
        end
    end
    
    always @(*) begin
        case(cur_state)
            STORE_PIXEL        : begin
                next_state = (IROM_A_tmp == 6'd63) ? WAIT_CMD : STORE_PIXEL;
            end
            WAIT_CMD           : begin
                next_state = (cmd_valid && !busy) ? cmd : WAIT_CMD;
            end
            WRITE              : begin
                next_state = (pixel_ptr == 6'd63) ? WAIT_CMD : WRITE;
            end
            SHIFT_UP           : begin
                next_state = WAIT_CMD;
            end
            SHIFT_DOWN         : begin
                next_state = WAIT_CMD;
            end
            SHIFT_LEFT         : begin
                next_state = WAIT_CMD;
            end
            SHIFT_RIGHT        : begin
                next_state = WAIT_CMD;
            end
            MAX                : begin
                next_state = (times == 2'd2) ? WAIT_CMD : MAX;
            end
            MIN                : begin
                next_state = (times == 2'd2) ? WAIT_CMD : MIN;
            end
            AVG                : begin
                next_state = (times == 2'd3) ? WAIT_CMD : AVG;
            end
            COUNTERCLOCKWISE_R : begin
                next_state = (times == 2'd3) ? WAIT_CMD : COUNTERCLOCKWISE_R;
            end
            CLOCKWISE_R        : begin
                next_state = (times == 2'd3) ? WAIT_CMD : CLOCKWISE_R;
            end
            MIRROR_X           : begin
                next_state = (times == 2'd3) ? WAIT_CMD : MIRROR_X;
            end
            MIRROR_Y           : begin
                next_state = (times == 2'd3) ? WAIT_CMD : MIRROR_Y;
            end
            default begin
                next_state = WAIT_CMD;
            end
        endcase
    end
    
    always @(*) begin
        cmd_cmp_flg = (cur_state == WAIT_CMD) ? TRUE : FALSE;
    end
    
    reg [2:0] loca_x, loca_y; //range 1~7
    reg IRAM_valid_tmp;
    reg [7:0] IRAM_D_tmp;
    reg [5:0] IRAM_A_tmp;
    integer i;
    wire [5:0] location_y_shift  = loca_y * 6'd8;
    wire [5:0] location3         = location_y_shift + loca_x;
    wire [5:0] location0         = location3 - 6'd9;
    wire [5:0] location1         = location3 - 6'd8;
    wire [5:0] location2         = location3 - 6'd1;
    wire [7:0] now_op_l_u        = pixel_mem[location0];  //left & upper
    wire [7:0] now_op_r_u        = pixel_mem[location1];  //right & upper
    wire [7:0] now_op_l_l        = pixel_mem[location2];  //left & lower
    wire [7:0] now_op_r_l        = pixel_mem[location3];  //right & lower
    wire cmp_0                   = (now_op_l_u > now_op_r_u) ? TRUE : FALSE;
    wire cmp_1                   = (now_op_l_l > now_op_r_l) ? TRUE : FALSE;
    wire cmp_2                   = ((cmp_0 ? now_op_l_u : now_op_r_u) > (cmp_1 ? now_op_l_l : now_op_r_l)) ? TRUE : FALSE;
    wire cmp_3                   = ((cmp_0 ? now_op_r_u : now_op_l_u) < (cmp_1 ? now_op_r_l : now_op_l_l)) ? TRUE : FALSE;
    wire [5:0] loca_change_max_0 = cmp_2 ? (cmp_0 ? location1 : location0) : location0;
    wire [5:0] loca_change_max_1 = cmp_2 ? location2 : location1;
    wire [5:0] loca_change_max_2 = cmp_2 ? location3 : (cmp_1 ? location3 : location2);
    wire [7:0] max               = cmp_2 ? (cmp_0 ? now_op_l_u : now_op_r_u) : (cmp_1 ? now_op_l_l : now_op_r_l);
    wire [5:0] loca_change_min_0 = cmp_3 ? (cmp_0 ? location0 : location1) : location0 ;
    wire [5:0] loca_change_min_1 = cmp_3 ? location2 : location1;
    wire [5:0] loca_change_min_2 = cmp_3 ? location3 : (cmp_1 ? location1 : location3);
    wire [7:0] min               = cmp_3 ? (cmp_0 ? now_op_r_u : now_op_l_u) : (cmp_1 ? now_op_r_l : now_op_l_l);
    wire [9:0] total             = pixel_mem[location0] + pixel_mem[location1] + pixel_mem[location2] + pixel_mem[location3];
    
    assign IRAM_D     = IRAM_D_tmp;
    assign IRAM_valid = IRAM_valid_tmp;
    assign IRAM_A     = IRAM_A_tmp;
    
    reg done_tmp, done_tmp1;
    assign done = done_tmp1;
    always @(posedge clk) begin
        done_tmp1 <= done_tmp;
    end
    always @(posedge clk) begin
        if (reset) begin
            for(i = 0; i<64; i = i+1) begin
                pixel_mem[i] <= 8'd0;
            end
            IRAM_valid_tmp <= FALSE;
            IRAM_D_tmp     <= 8'd0;
            IRAM_A_tmp     <= 6'd0;
            pixel_ptr      <= 6'd0;
            loca_x         <= 3'd4;
            loca_y         <= 3'd4;
            times          <= 2'd0;
            done_tmp       <= FALSE;
        end
        else begin
            case(cur_state)
                STORE_PIXEL        : begin
                    pixel_mem[IROM_A_tmp] <= IROM_Q;
                end
                WAIT_CMD        : begin
                    IRAM_valid_tmp <= FALSE;
                    IRAM_D_tmp     <= 8'd0;
                    IRAM_A_tmp     <= 6'd0;
                    pixel_ptr      <= 6'd0;
                    loca_x         <= loca_x;
                    loca_y         <= loca_y;
                    times          <= 2'd0;
                end
                WRITE              : begin
                    pixel_ptr      <= pixel_ptr + 6'd1;
                    IRAM_valid_tmp <= TRUE;
                    IRAM_D_tmp     <= pixel_mem[pixel_ptr];
                    IRAM_A_tmp     <= pixel_ptr;
                    if (pixel_ptr == 6'd63) begin
                        done_tmp <= TRUE;
                    end
                end
                SHIFT_UP           : begin
                    if (loca_y == 3'd1) begin
                        loca_y <= loca_y;
                    end
                    else begin
                        loca_y <= loca_y - 3'd1;
                    end
                end
                SHIFT_DOWN         : begin
                    if (loca_y == 3'd7) begin
                        loca_y <= loca_y;
                    end
                    else begin
                        loca_y <= loca_y + 3'd1;
                    end
                end
                SHIFT_LEFT         : begin
                    if (loca_x == 3'd1) begin
                        loca_x <= loca_x;
                    end
                    else begin
                        loca_x <= loca_x - 3'd1;
                    end
                end
                SHIFT_RIGHT        : begin
                    if (loca_x == 3'd7) begin
                        loca_x <= loca_x;
                    end
                    else begin
                        loca_x <= loca_x + 3'd1;
                    end
                end
                MAX                : begin
                    times          <= times + 2'd1;
                    IRAM_valid_tmp <= TRUE;
                    IRAM_D_tmp     <= max;
                    case(times)
                        2'd0: begin
                            IRAM_A_tmp                   <= loca_change_max_0;
                            pixel_mem[loca_change_max_0] <= max;
                            pixel_mem[loca_change_max_1] <= max;
                            pixel_mem[loca_change_max_2] <= max;
                        end
                        2'd1: begin
                            IRAM_A_tmp <= loca_change_max_1;
                        end
                        2'd2: begin
                            IRAM_A_tmp <= loca_change_max_2;
                        end
                        default begin
                            
                        end
                    endcase
                end
                MIN                : begin
                    times          <= times + 2'd1;
                    IRAM_valid_tmp <= TRUE;
                    IRAM_D_tmp     <= min;
                    case(times)
                        2'd0: begin
                            IRAM_A_tmp                   <= loca_change_min_0;
                            pixel_mem[loca_change_min_0] <= min;
                            pixel_mem[loca_change_min_1] <= min;
                            pixel_mem[loca_change_min_2] <= min;
                        end
                        2'd1: begin
                            IRAM_A_tmp <= loca_change_min_1;
                        end
                        2'd2: begin
                            IRAM_A_tmp <= loca_change_min_2;
                        end
                        default begin
                            
                        end
                    endcase
                end
                AVG                : begin
                    times          <= times + 2'd1;
                    IRAM_valid_tmp <= TRUE;
                    IRAM_D_tmp     <= total[9:2];
                    case(times)
                        2'd0: begin
                            pixel_mem[location0] <= total[9:2];
                            pixel_mem[location1] <= total[9:2];
                            pixel_mem[location2] <= total[9:2];
                            pixel_mem[location3] <= total[9:2];
                            IRAM_A_tmp           <= location0;
                        end
                        2'd1: begin
                            IRAM_A_tmp <= location1;
                        end
                        2'd2: begin
                            IRAM_A_tmp <= location2;
                        end
                        2'd3: begin
                            IRAM_A_tmp <= location3;
                        end
                        default begin
                            
                        end
                    endcase
                end
                COUNTERCLOCKWISE_R : begin
                    times          <= times + 2'd1;
                    IRAM_valid_tmp <= TRUE;
                    case(times)
                        2'd0: begin
                            pixel_mem[location0] <= pixel_mem[location1];
                            pixel_mem[location1] <= pixel_mem[location3];
                            pixel_mem[location2] <= pixel_mem[location0];
                            pixel_mem[location3] <= pixel_mem[location2];
                            
                            IRAM_D_tmp <= pixel_mem[location1];
                            IRAM_A_tmp <= location0;
                        end
                        2'd1: begin
                            IRAM_D_tmp <= pixel_mem[location1];
                            IRAM_A_tmp <= location1;
                        end
                        2'd2: begin
                            IRAM_D_tmp <= pixel_mem[location2];
                            IRAM_A_tmp <= location2;
                        end
                        2'd3: begin
                            IRAM_D_tmp <= pixel_mem[location3];
                            IRAM_A_tmp <= location3;
                        end
                        default begin
                            
                        end
                    endcase
                end
                CLOCKWISE_R        : begin
                    times          <= times + 2'd1;
                    IRAM_valid_tmp <= TRUE;
                    case(times)
                        2'd0: begin
                            pixel_mem[location0] <= pixel_mem[location2];
                            pixel_mem[location1] <= pixel_mem[location0];
                            pixel_mem[location2] <= pixel_mem[location3];
                            pixel_mem[location3] <= pixel_mem[location1];
                            
                            IRAM_D_tmp <= pixel_mem[location2];
                            IRAM_A_tmp <= location0;
                        end
                        2'd1: begin
                            IRAM_D_tmp <= pixel_mem[location1];
                            IRAM_A_tmp <= location1;
                        end
                        2'd2: begin
                            IRAM_D_tmp <= pixel_mem[location2];
                            IRAM_A_tmp <= location2;
                        end
                        2'd3: begin
                            IRAM_D_tmp <= pixel_mem[location3];
                            IRAM_A_tmp <= location3;
                        end
                        default begin
                            
                        end
                    endcase
                end
                MIRROR_X           : begin
                    times          <= times + 2'd1;
                    IRAM_valid_tmp <= TRUE;
                    case(times)
                        2'd0: begin
                            pixel_mem[location0] <= pixel_mem[location2];
                            pixel_mem[location1] <= pixel_mem[location3];
                            pixel_mem[location2] <= pixel_mem[location0];
                            pixel_mem[location3] <= pixel_mem[location1];
                            
                            IRAM_D_tmp <= pixel_mem[location2];
                            IRAM_A_tmp <= location0;
                        end
                        2'd1: begin
                            IRAM_D_tmp <= pixel_mem[location1];
                            IRAM_A_tmp <= location1;
                        end
                        2'd2: begin
                            IRAM_D_tmp <= pixel_mem[location2];
                            IRAM_A_tmp <= location2;
                        end
                        2'd3: begin
                            IRAM_D_tmp <= pixel_mem[location3];
                            IRAM_A_tmp <= location3;
                        end
                        default begin
                            
                        end
                    endcase
                end
                MIRROR_Y           : begin
                    times          <= times + 2'd1;
                    IRAM_valid_tmp <= TRUE;
                    case(times)
                        2'd0: begin
                            pixel_mem[location0] <= pixel_mem[location1];
                            pixel_mem[location1] <= pixel_mem[location0];
                            pixel_mem[location2] <= pixel_mem[location3];
                            pixel_mem[location3] <= pixel_mem[location2];
                            
                            IRAM_D_tmp <= pixel_mem[location1];
                            IRAM_A_tmp <= location0;
                        end
                        2'd1: begin
                            IRAM_D_tmp <= pixel_mem[location1];
                            IRAM_A_tmp <= location1;
                        end
                        2'd2: begin
                            IRAM_D_tmp <= pixel_mem[location2];
                            IRAM_A_tmp <= location2;
                        end
                        2'd3: begin
                            IRAM_D_tmp <= pixel_mem[location3];
                            IRAM_A_tmp <= location3;
                        end
                        default begin
                            
                        end
                    endcase
                end
                default begin
                    //do nothing
                end
            endcase
        end
    end
    
endmodule
    
    
    
