module LASER (
input CLK,
input RST,
input [3:0] X,
input [3:0] Y,
output reg [3:0] C1X,
output reg [3:0] C1Y,
output reg [3:0] C2X,
output reg [3:0] C2Y,
output reg DONE);

parameter IDLE      = 0,
          IN_DATA   = 1,
          CIRCLE1   = 2,
          CIRCLE2   = 3,
          ROUND     = 4,
          FINISH    = 5,
          DELAY     = 6;

// VAR
reg [3:0] array_x [0:39];
reg [3:0] array_y [0:39];
reg [4:0] cs, ns;
reg [5:0] i_cnt;
reg [2:0] cnt;

reg [3:0] pos_x1, pos_x2;
reg [4:0] pos_y1, pos_y2; // fake center

integer i;

// STATE
always @(posedge CLK)begin
    if(RST)begin
        cs <= IDLE;
    end
    else begin
        cs <= ns;
    end
end

always @(*)begin
    case(cs)
        IDLE:       ns <= IN_DATA;
        IN_DATA:    ns <= (i_cnt == 6'd39) ? CIRCLE1 : IN_DATA;
        CIRCLE1:    ns <= (pos_y1[4]) ? CIRCLE2 : CIRCLE1;
        CIRCLE2:    ns <= (pos_y2[4]) ? ROUND : CIRCLE2;
        ROUND:      ns <= (cnt == 3) ? FINISH : CIRCLE1;
        FINISH:     ns <= DELAY;
        default:    ns <= IDLE;
    endcase
end

wire [3:0] ax, ay;
wire [8:0] distance_1;
wire [3:0] bx, by;
wire [8:0] distance_2;

reg [5:0] max_tmp, circle1_max, circle2_max;

assign ax = (pos_x1 > array_x[i_cnt]) ? (pos_x1 - array_x[i_cnt]) : (array_x[i_cnt] - pos_x1);
assign ay = (pos_y1 > array_y[i_cnt]) ? (pos_y1 - array_y[i_cnt]) : (array_y[i_cnt] - pos_y1);
assign distance_1 = ( ax * ax ) + ( ay * ay );
assign in_circle_1 = (distance_1 <= 16) ? (1) : (0);

assign bx = (pos_x2 > array_x[i_cnt]) ? (pos_x2 - array_x[i_cnt]) : (array_x[i_cnt] - pos_x2);
assign by = (pos_y2 > array_y[i_cnt]) ? (pos_y2 - array_y[i_cnt]) : (array_y[i_cnt] - pos_y2);
assign distance_2 = ( bx * bx ) + ( by * by );
assign in_circle_2 = (distance_2 <= 16) ? (1) : (0);

always @(posedge CLK)begin
    if(RST)begin
        { pos_y1, pos_x1} <= 9'd0;
        { pos_y2, pos_x2} <= 9'd0;
    end
    else begin
        case(cs)
            IDLE:begin
                { pos_y1, pos_x1} <= 9'd0;
                { pos_y2, pos_x2} <= 9'd0;
            end
            CIRCLE1:begin
                if(cnt)begin
                    { pos_y2, pos_x2} <= { C2Y, C2X};
                end
                if(i_cnt == 6'd39)begin
                    { pos_y1, pos_x1} <= { pos_y1, pos_x1} + 9'd1;
                end
            end
            CIRCLE2:begin
                { pos_y1, pos_x1} <= { C1Y, C1X};
                if(i_cnt == 6'd39)begin
                    { pos_y2, pos_x2} <= { pos_y2, pos_x2} + 9'd1;
                end
            end
        endcase
    end
end

always @(posedge CLK)begin
    if(RST)begin
        max_tmp <= 6'd0;
        circle1_max <= 6'd0;
        circle2_max <= 6'd0;
        {C1Y, C1X} <= 8'd0;
        {C2Y, C2X} <= 8'd0;
    end
    else begin
        case(cs)
            IDLE:begin
                max_tmp <= 6'd0;
                circle1_max <= 6'd0;
                circle2_max <= 6'd0;
                {C1Y, C1X} <= 8'd0;
                {C2Y, C2X} <= 8'd0;
            end
            CIRCLE1:begin
                if(cnt)begin
                    max_tmp <= max_tmp + (in_circle_1 | in_circle_2);
                end
                else begin
                    max_tmp <= max_tmp + in_circle_1;
                end
                if(i_cnt == 6'd39)begin
                    max_tmp <= 6'd0;
                    if(cnt)begin
                        if(max_tmp >= circle1_max)begin
                            circle1_max <= max_tmp;
                            {C1Y, C1X} <= {pos_y1[3:0], pos_x1};
                        end
                    end
                    else begin
                        if(max_tmp > circle1_max)begin
                            circle1_max <= max_tmp;
                            {C1Y, C1X} <= {pos_y1[3:0], pos_x1};
                        end
                    end
                end
            end
            CIRCLE2:begin
                max_tmp <= max_tmp + (in_circle_1 | in_circle_2);
                if(i_cnt == 6'd39)begin
                    max_tmp <= 6'd0;
                    if(cnt)begin
                        if(max_tmp >= circle2_max)begin
                            circle2_max <= max_tmp;
                            {C2Y, C2X} <= {pos_y2[3:0], pos_x2};
                        end
                    end
                    else begin
                        if(max_tmp > circle2_max)begin
                            circle2_max <= max_tmp;
                            {C2Y, C2X} <= {pos_y2[3:0], pos_x2};
                        end
                    end
                end
            end
        endcase
    end
end

always @(posedge CLK)begin
    if(RST)begin
        cnt <= 3'd0;
    end
    else begin
        case(cs)
            ROUND:  cnt <= cnt + 3'd1;
            FINISH: cnt <= 3'd0;
        endcase
    end
end

// IN_CNT
always @(posedge CLK)begin
    if(RST)begin
        i_cnt <= 6'd1;
    end
    else begin
        case(cs)
            IDLE:       i_cnt <= 6'd1;
            IN_DATA:begin
                if(i_cnt == 6'd39)begin
                    i_cnt <= 6'd0;
                end
                else begin
                    i_cnt <= i_cnt + 6'd1;
                end
            end
            CIRCLE1:begin
                if(i_cnt == 6'd39)begin
                    i_cnt <= 6'd0;
                end
                else begin
                    i_cnt <= i_cnt + 6'd1;
                end
            end
            CIRCLE2:begin
                if(i_cnt == 6'd39)begin
                    i_cnt <= 6'd0;
                end
                else begin
                    i_cnt <= i_cnt + 6'd1;
                end
            end
        endcase
    end
end

// IN_DATA
always @(posedge CLK)begin
    if(RST)begin
        for(i=0;i<40;i=i+1)begin
            array_x[i] <= 4'd0;
            array_y[i] <= 4'd0;
        end
    end
    else begin
        case(cs)
            IDLE:begin
                array_x[0] <= X;
                array_y[0] <= Y;
                for(i=1;i<40;i=i+1)begin
                    array_x[i] <= 4'd0;
                    array_y[i] <= 4'd0;
                end
            end
            IN_DATA:begin
                array_x[i_cnt] <= X;
                array_y[i_cnt] <= Y;
            end
        endcase
    end
end

// DONE
always @(posedge CLK)begin
    if(RST)begin
        DONE <= 1'd0;
    end
    else begin
        case(cs)
            FINISH:     DONE <= 1'd1;
            default:    DONE <= 1'd0;
        endcase
    end
end

endmodule
