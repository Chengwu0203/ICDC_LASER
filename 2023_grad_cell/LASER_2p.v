module LASER (
input               CLK,
input               RST,
input [3:0]         X,
input [3:0]         Y,
output reg [3:0]    C1X,
output reg [3:0]    C1Y,
output reg [3:0]    C2X,
output reg [3:0]    C2Y,
output reg          DONE);

parameter IDLE      = 3'd0,
          IN_DATA   = 3'd1,
          CIRCLE1   = 3'd2,
          CIRCLE2   = 3'd3,
          ROUND     = 3'd4,
          FINISH    = 3'd5,
          DELAY     = 3'd6;

// VAR
reg [3:0] array_x [0:39];
reg [3:0] array_y [0:39];
reg [2:0] cs, ns;
reg [5:0] i_cnt;    // IN CNT
reg [2:0] r_cnt;    // ROUND CNT
reg [3:0] pos_x1, pos_x2;
reg [4:0] pos_y1, pos_y2; // fake center

wire      in_circle1, in_circle2, in_circle3, in_circle4;

reg [5:0] max_tmp, circle1_max, circle2_max;

integer i;

// CHECK
check U0( .X(pos_x1), .Y(pos_y1[3:0]), .x(array_x[i_cnt]), .y(array_y[i_cnt]), .in_circle(in_circle1));
check U1( .X(pos_x1), .Y(pos_y1[3:0]), .x(array_x[20 + i_cnt]), .y(array_y[20 + i_cnt]), .in_circle(in_circle2));
check U2( .X(pos_x2), .Y(pos_y2[3:0]), .x(array_x[i_cnt]), .y(array_y[i_cnt]), .in_circle(in_circle3));
check U3( .X(pos_x2), .Y(pos_y2[3:0]), .x(array_x[20 + i_cnt]), .y(array_y[20 + i_cnt]), .in_circle(in_circle4));

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
        CIRCLE1:    ns <= (pos_y1[4]) ? ROUND : CIRCLE1;
        CIRCLE2:    ns <= (pos_y2[4]) ? ROUND : CIRCLE2;
        ROUND:      ns <= (r_cnt == 3) ? FINISH :(r_cnt[0]) ? CIRCLE1 : CIRCLE2;
        FINISH:     ns <= DELAY;
        default:    ns <= IDLE;
    endcase
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
            CIRCLE1, CIRCLE2:begin
                if(i_cnt == 6'd19)begin
                    i_cnt <= 6'd0;
                end
                else begin
                    i_cnt <= i_cnt + 6'd1;
                end
            end
            DELAY:      i_cnt <= 6'd1;
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
            DELAY:begin
                array_x[0] <= X;
                array_y[0] <= Y;
                for(i=1;i<40;i=i+1)begin
                    array_x[i] <= 4'd0;
                    array_y[i] <= 4'd0;
                end
            end
        endcase
    end
end

// POS
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
                if(r_cnt)begin
                    { pos_y2, pos_x2} <= { C2Y, C2X};
                end
                //
                if(i_cnt == 6'd19)begin
                    { pos_y1, pos_x1} <= { pos_y1, pos_x1} + 9'd1;
                end
            end
            CIRCLE2:begin
                { pos_y1, pos_x1} <= { C1Y, C1X};
                //
                if(i_cnt == 6'd19)begin
                    { pos_y2, pos_x2} <= { pos_y2, pos_x2} + 9'd1;
                end
            end
            DELAY:begin
                { pos_y1, pos_x1} <= 9'd0;
                { pos_y2, pos_x2} <= 9'd0;
            end
        endcase
    end
end

// MAX
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
                if(r_cnt)begin
                max_tmp <= max_tmp + (in_circle1 | in_circle3) + (in_circle2 | in_circle4);
                end
                else begin
                    max_tmp <= max_tmp + in_circle1 + in_circle2;
                end
                if(i_cnt == 6'd19)begin
                    max_tmp <= 6'd0;
                    if(r_cnt)begin
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
                max_tmp <= max_tmp + (in_circle1 | in_circle3) + (in_circle2 | in_circle4);
                if(i_cnt == 6'd19)begin
                    max_tmp <= 6'd0;
                    if(r_cnt[2:1])begin
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
            DELAY:begin
                max_tmp <= 6'd0;
                circle1_max <= 6'd0;
                circle2_max <= 6'd0;
                {C1Y, C1X} <= 8'd0;
                {C2Y, C2X} <= 8'd0;
            end
        endcase
    end
end

// ROUND CNT
always @(posedge CLK)begin
    if(RST)begin
        r_cnt <= 3'd0;
    end
    else begin
        case(cs)
            IDLE:   r_cnt <= 3'd0;
            ROUND:  r_cnt <= r_cnt + 3'd1;
            DELAY:  r_cnt <= 3'd0;
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

module check( X, Y, x, y, in_circle);

input [3:0] X, Y;
input [3:0] x, y;
output in_circle;

wire [3:0] ax, ay;
wire [8:0] distance;
wire [7:0] pow2_r;

assign ax = (X > x) ? (X - x) : (x - X);
assign ay = (Y > y) ? (Y - y) : (y - Y);
assign distance = ( ax * ax ) + ( ay * ay );
assign in_circle = (distance <= 16) ? (1'd1) : (1'd0);

endmodule
