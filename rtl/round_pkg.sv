// ============================================================================
// Package:     round_pkg
// Description: Defines the IEEE-754 rounding modes as an enumerated type.
// ============================================================================

package round_pkg;
    typedef enum logic [2:0] {
        IEEE_near        = 3'b000,
        IEEE_zero        = 3'b001,
        IEEE_ninf        = 3'b010,
        IEEE_pinf        = 3'b011,
        IEEE_near_maxMag = 3'b100
    } round_mode_t;
endpackage