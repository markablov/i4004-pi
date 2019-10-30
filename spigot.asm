// Initial array fill
//
// rr0 - RAM bank iterator
// rr1 - RAM bank index
// rr2 - RAM register index
// rr3 - RAM character index

  FIM r0, 0x80
process_bank:
  // select current bank
  LD rr1
  DCL
  // iterate from register #0
  CLB
  XCH rr2
process_register:
  // iterate from character #0
  CLB
  XCH rr3
process_character:
  // write 2 to selected bank/register/character set
  SRC r1
  LDM 2
  WRM
  ISZ rr3, process_character
  // write 2 to status characters at selected bank/register
  WR0
  WR1
  WR2
  WR3
  ISZ rr2, process_register
  INC rr1
  ISZ rr0, process_bank

// Main loop
//
// bank #7, reg #F, main characters 5, 6, 7 - pi digits in c-base loop iterator and numerator for corresponding digit
// rr8/rr9/rr10/rr11 - carry for pi digits in c-base
// rr12 - pre-computed digit, that could be corrected
// rr13 - count of 9s after pre-computed digit
// rr14/rr15 - amount of computed pi digits

  FIM r6, 0x00
  // compute 255 digits, not 256 ;)
  FIM r7, 0x10
main_loop:
  // set carry to zero
  FIM r4, 0x00
  FIM r5, 0x00

  // set initial numerator to 1701 == 0x006A5
  LDM 7
  DCL
  FIM r0, 0xF5
  SRC r0
  LDM 0x5
  WRM
  INC rr1
  SRC r0
  LDM 0xA
  WRM
  INC rr1
  SRC r0
  LDM 0x6
  WRM
  INC rr1
  SRC r0
  LDM 0x0
  WRM
  INC rr1
  SRC r0
  LDM 0x0
  WRM
normalization_loop:
  JMS get_denominator_by_numerator
  // rr5/rr6/rr7 would contain denominator
  JMS get_linear_address_by_index
  // rr0/rr1/rr2 would contain linear address
  JMS read_element_to_buffer
  JMS mul_buf_by_10
  JMS add_carry_to_buf
  JMS div_buf_by_numerator
  // rr8/rr9 would contain quotient
  JMS get_denominator_by_numerator
  // rr5/rr6/rr7 would contain denominator
  JMS get_linear_address_by_index
  // rr0/rr1/rr2 would contain linear address
  JMS write_buffer_to_element
  JMS mul_denominator_by_quotient
  // rr8/rr9/rr10/rr11 would contain quotient
  // decrease numerator by 2, and check if loop is done
  LDM 2
  XCH rr2
  LDM 0
  XCH rr3
  LDM 7
  DCL
  FIM r0, 0xF5
  SRC r0
  RDM
  CMC
  SUB rr2
  WRM
  INC rr1
  SRC r0
  RDM
  CMC
  SUB rr3
  WRM
  INC rr1
  SRC r0
  RDM
  SUB rr3
  WRM
  JCN c, normalization_loop

  // carry could be in range [0..19], so only rr8/rr9 contains data
  LD rr9
  XCH rr0
  LD rr8
  XCH rr1
  LDM 10
  XCH rr2
  // div carry by 10, rr0 would be first digit of carry (0 or 1), rr1 - 2nd digit
  JMS div8bitBy4bit
  // check if first digit of carry is 1, then we need to print X0000 instead of X9999, coz of cascade carry
  LD rr0
  JCN z, carry_first_digit_is_zero
  LDM 0
  JUN set_printed_digit_instead_of_nines
carry_first_digit_is_zero:
  LDM 9
set_printed_digit_instead_of_nines:
  XCH rr6
  // check if digit is 9
  LDM 9
  SUB rr1
  JCN nz, next_digit_is_not_nine
  INC rr13
  JUN main_loop
next_digit_is_not_nine:
  LD rr0
  ADD rr12
  XCH rr0
  // update nextDigit before calling function, because rr1 could be updated in subroutine
  LD rr1
  XCH rr12
  JMS send_computed_digit
  ISZ rr14, digit_is_printed
  ISZ rr15, digit_is_printed
  JUN work_is_done
digit_is_printed:
  // now print buffered 9s
  CLB
  SUB rr13
  JCN z, nines_are_printed
  XCH rr13
print_nine:
  LD rr6
  XCH rr0
  JMS send_computed_digit
  ISZ rr14, nine_is_printed
  ISZ rr15, nine_is_printed
  JUN work_is_done
nine_is_printed:
  ISZ rr13, print_nine
nines_are_printed:
  JUN main_loop
work_is_done:
  // halt
  JUN work_is_done


div8bitBy4bit:
  BBL 0

div_buf_by_numerator:
  BBL 0

get_denominator_by_numerator:
  BBL 0

get_linear_address_by_index:
  BBL 0

read_element_to_buffer:
  BBL 0

mul_buf_by_10:
  BBL 0

add_carry_to_buf:
  BBL 0

write_buffer_to_element:
  BBL 0

mul_denominator_by_quotient:
  BBL 0

send_computed_digit:
  BBL 0
