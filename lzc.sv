// ============================================================================
// Module: lzc (Leading Zero Counter)
// Description: Scans a 27-bit input vector from MSB to LSB and counts the 
//              number of consecutive zeros before the first '1' is found.
// ============================================================================

module lzc(
    input  logic  [26:0] mant_in,
    output logic  [4:0]  zero_count    
);
    always_comb begin
        // Default assignment: start the count at 0 every time the input changes
        zero_count = 5'b0;
        
        // Scan from MSB (26) down to LSB (0)
        for(int i = 26; i >= 0; i--) begin
            if(mant_in[i] == 1'b0) begin
                zero_count ++;
            end else begin
                break;
            end
        end 
    end

endmodule