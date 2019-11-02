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

// divide 8bit number by 4bit number
// INPUT:
//   rr0 - high word of dividend, rr1 - low word of dividend, rr2 - divisor
// OUTPUT:
//   rr0 - quotient, rr1 - reminder, CARRY flag would be set in case of overflow (quotient > 15)
// REGISTERS MODIFIED:
//   rr3 - temporal quotient
//   rr6 - zero
div8bitBy4bit:
  CLB
  XCH rr3
  CLB
  XCH rr6
div8bitBy4bit_subtract:
  CLC
  LD rr1
  SUB rr2
  XCH rr1
  CMC
  LD rr0
  SUB rr6
  XCH rr0
  JCN nc, div8bitBy4bit_return
  ISZ rr3, div8bitBy4bit_subtract
  // overflow occurs
  BBL 0
div8bitBy4bit_return:
  LD rr1
  ADD rr2
  XCH rr1
  LD rr3
  XCH rr0
  CLC
  BBL 0

// get word count for number (detected by 0 at most significant word)
// INPUT:
//   rr1 - index for last character in memory allocated for number + 1
//   rr2 - max possible length of number + 1
// OUTPUT:
//   rr2 - word count
div_buf_by_numerator_number_len:
  LDM 0xF
  XCH rr0
div_buf_by_numerator_number_len_check_prev_word:
  LD rr1
  DAC
  XCH rr1
  LD rr2
  DAC
  XCH rr2
  SRC r0
  RDM
  JCN z, div_buf_by_numerator_number_len_check_prev_word
  CLC
  BBL 0

// check if dividend bigger or equal than divisor
// OUTPUT:
//   CARRY is set if dividend is bigger or equal than divisor
div_buf_by_numerator_is_dividend_bigger_or_equal_than_divisor:
  FIM r0, 0xF0
  FIM r1, 0xF5
  LDM 0xB
  XCH rr5
  STC
div_buf_by_numerator_is_dividend_bigger_or_equal_than_divisor_next_word:
  SRC r0
  RDM
  SRC r1
  CMC
  SBM
  INC rr1
  INC rr3
  ISZ rr5, div_buf_by_numerator_is_dividend_bigger_or_equal_than_divisor_next_word
  BBL 0

// divide N-word by 1-word
// REGISTER MODIFIED:
//   rr6/rr7 - dividend digit RAM address
//   rr2 - divisor
// INPUT:
//   dividend - bank #7, register #F, main characters [0..4], LSW at #0 character
//   divisor - bank #7, register #F, main characters [5..9]
// OUTPUT:
//   quotient - rr8/rr9
//   reminder - bank #7, register #F, main characters [0..4]
// NOTES:
//   quotient is always 1 or 2 digits, so we know that if dividend is 3-word number, then MSW < divisor
div_buf_by_numerator_one_word_divisor:
  // load divisor
  FIM r3, 0xF5
  SRC r3
  RDM
  XCH rr2
  // calculate MSW for quotient
  LDM 2
  XCH rr7
  SRC r3
  RDM
  XCH rr0
  LDM 0
  WRM
  LDM 1
  XCH rr7
  SRC r3
  RDM
  XCH rr1
  LDM 0
  WRM
  // call div8bitBy4bit(dividend[2], dividend[1], divisor)
  JMS div8bitBy4bit
  // rr0 - quotient, rr1 - reminder
  LD rr0
  XCH rr9
  // calculate LSW for quotient
  LD rr1
  XCH rr0
  FIM r3, 0xF0
  SRC r3
  RDM
  XCH rr1
  // call div8bitBy4bit(reminder, dividend[0], divisor)
  JMS div8bitBy4bit
  // rr0 - quotient, rr1 - reminder
  LD rr0
  XCH rr8
  LD rr1
  WRM
  BBL 0

// determine on how many bits we need to shift divisor left to set MSB to 1
// OUTPUT:
//   shift value - rr6
div_buf_by_numerator_normalize_get_shift_value:
  LDM 0x0
  XCH rr6
  // read MSW for divisor
  FIM r0, 0xF4
  LD rr11
  ADD rr1
  XCH rr1
  SRC r0
  RDM
  XCH rr5
  LDM 0x7
  SUB rr5
  JCN nc, div_buf_by_numerator_normalize_get_shift_value_return
  INC rr6
  LDM 0x3
  SUB rr5
  JCN nc, div_buf_by_numerator_normalize_get_shift_value_return
  INC rr6
  LDM 0x1
  SUB rr5
  JCN nc, div_buf_by_numerator_normalize_get_shift_value_return
  INC rr6
div_buf_by_numerator_normalize_get_shift_value_return:
  CLC
  BBL 0

// shift left 4bit number
// INPUT:
//   rr6 - shift value
//   rr3 - value
// OUTPUT:
//   rr3 - shifter value
shift_left:
  LD rr6
  CMA
  IAC
  XCH rr5
  LD rr3
shift_left_bit:
  RAL
  CLC
  ISZ rr5, shift_left_bit
  XCH rr3
  BBL 0

// shift right 4bit number
// INPUT:
//   rr7 - shift value
//   rr4 - value
// OUTPUT:
//   rr4 - shifter value
shift_right:
  LD rr7
  CMA
  IAC
  XCH rr5
  LD rr4
shift_right_bit:
  RAR
  CLC
  ISZ rr5, shift_right_bit
  XCH rr4
  BBL 0

// shift left multiword number
// INPUT:
//   rr6 - shift value
//   rr7 - (4 - shift value)
//   rr1 - (character index in memory for MSW shifting number) + 1
//   rr2 - number of words
div_buf_by_numerator_shift_number_left:
  LDM 0xF
  XCH rr0
  LD rr2
  CMA
  XCH rr2
div_buf_by_numerator_shift_number_left_shift_digit:
  // shift right next digit, some bits would be transferred to current difit
  LD rr1
  DAC
  XCH rr1
  SRC r0
  RDM
  XCH rr4
  JMS shift_right
  // shift left current digit
  INC rr1
  SRC r0
  RDM
  XCH rr3
  JMS shift_left
  LD rr3
  ADD rr4
  WRM
  LD rr1
  DAC
  XCH rr1
  ISZ rr2, div_buf_by_numerator_shift_number_left_shift_digit
  // shift left LSW
  SRC r0
  RDM
  XCH rr3
  JMS shift_left
  LD rr3
  WRM
  BBL 0

// multiply 1-word number by 1-word number, output is 2-word
// INPUT:
//   rr0 - multiplier
//   rr1 - multiplicand
// OUTPUT:
//   rr2 - low word
//   rr3 - high word
mul4bitBy4bit:
  FIM r1, 0x00
  LD rr1
  JCN z, mul4bitBy4bit_return
  CMA
  IAC
  XCH rr1
mul4bitBy4bit_add:
  LD rr2
  ADD rr0
  XCH rr2
  LDM 0
  ADD rr3
  XCH rr3
  ISZ rr1, mul4bitBy4bit_add
mul4bitBy4bit_return:
  BBL 0

// get single quotient digit at specified position
// INPUT:
//   rr7 - quotient digit idx
//   rr10 - number of words for dividend
//   rr11 - number of words for divisor
//   dividend - bank #7, register #F, main characters [0..4], LSW at #0 character
//   divisor - bank #7, register #F, main characters [5..9]
// OUTPUT:
//   rr6 - quotient digit
// REGISTER MODIFIED:
//   rr0/rr1/rr2/rr3/rr4/rr5
//   rr8 - temporal variable, we can use it because it would be overwritten by low quotient digit after call
div_buf_by_numerator_get_quotient_digit:
  FIM r2, 0xF4
  LD rr11
  ADD rr5
  XCH rr5
  SRC r2
  RDM
  // divisor[divisorDigits - 1]
  XCH rr2
  LD rr11
  DAC
  CLC
  ADD rr7
  XCH rr5
  SRC r2
  RDM
  // dividend[divisorDigits + quotentDigitIdx - 1]
  XCH rr1
  INC rr5
  SRC r2
  RDM
  // dividend[divisorDigits + quotentDigitIdx]
  XCH rr0
  JMS div8bitBy4bit
  LD rr1
  XCH rr8
  LD rr0
  XCH rr6
  // quotient digit should be in range [0..F]
  JCN nc, div_buf_by_numerator_get_quotient_digit_quotient_is_not_overflown
  LDM 0xF
  XCH rr6
  JUN div_buf_by_numerator_get_quotient_digit_mulsub
div_buf_by_numerator_get_quotient_digit_quotient_is_not_overflown:
  LDM 3
  ADD rr11
  XCH rr5
  SRC r2
  // divisor[divisorDigits - 2]
  RDM
  XCH rr1
  LD rr6
  XCH rr0
  JMS mul4bitBy4bit
  LD rr8
  SUB rr3
  JCN nc, div_buf_by_numerator_get_quotient_digit_rough_tune_estimated_quotient
  JCN nz, div_buf_by_numerator_get_quotient_digit_mulsub
  // we have carry flag there, so it would be added to rr7, take it into account
  LDM 3
  XCH rr0
  LD rr11
  ADD rr7
  SUB rr0
  CLC
  XCH rr5
  SRC r2
  // dividend[divisorDigits + quotentDigitIdx - 2]
  RDM
  SUB rr2
  JCN c, div_buf_by_numerator_get_quotient_digit_mulsub
div_buf_by_numerator_get_quotient_digit_rough_tune_estimated_quotient:
  LD rr6
  DAC
  CLC
  XCH rr6
  LDM 4
  ADD rr11
  XCH rr5
  SRC r2
  // divisor[divisorDigits - 1]
  RDM
  ADD rr8
  XCH rr8
  JCN nc, div_buf_by_numerator_get_quotient_digit_quotient_is_not_overflown
div_buf_by_numerator_get_quotient_digit_mulsub:
  // rr4 - carry
  // rr5 - digit idx
  // rr8 - loop iterator
  LDM 0
  XCH rr4
  LDM 0
  XCH rr5
  LD rr11
  CMA
  IAC
  XCH rr8
div_buf_by_numerator_get_quotient_digit_mulsub_digit:
  FIM r0, 0xF5
  LDM 0x5
  ADD rr5
  XCH rr1
  SRC r0
  // divisor[divisorDigitIdx]
  RDM
  XCH rr1
  LD rr6
  XCH rr0
  JMS mul4bitBy4bit
  // rr2 = product[0], rr3 = product[1]
  FIM r0, 0xF0
  LD rr5
  ADD rr7
  XCH rr1
  SRC r0
  // dividend[divisorDigitIdx + quotentDigitIdx]
  RDM
  SUB rr4
  XCH rr0
  CMC
  TCC
  XCH rr4
  LD rr0
  SUB rr2
  CMC
  JCN nc, div_buf_by_numerator_get_quotient_digit_mulsub_digit_no_more_carry
  INC rr4
  CLC
div_buf_by_numerator_get_quotient_digit_mulsub_digit_no_more_carry:
  WRM
  LD rr4
  ADD rr3
  XCH rr4
  INC rr5
  ISZ rr8, div_buf_by_numerator_get_quotient_digit_mulsub_digit
div_buf_by_numerator_get_quotient_digit_mulsub_last_digit:
  FIM r0, 0xF0
  LD rr11
  ADD rr7
  XCH rr1
  SRC r0
  // dividend[dividendDigitIdx]
  RDM
  SUB rr4
  CMC
  WRM
  JCN nc, div_buf_by_numerator_get_quotient_digit_return
  // compensate if current reminder is negative now
  LD rr6
  DAC
  XCH rr6
  // rr4 - carry
  // rr5 - digit idx
  // rr8 - loop iterator
  LDM 0
  XCH rr4
  LDM 0
  XCH rr5
  LD rr11
  CMA
  IAC
  XCH rr8
div_buf_by_numerator_get_quotient_digit_add_digit:
  FIM r0, 0xF0
  LDM 0x5
  ADD rr5
  XCH rr1
  SRC r0
  // divisor[divisorDigitIdx]
  RDM
  XCH rr2
  LD rr5
  ADD rr7
  XCH rr1
  SRC r0
  // dividend[divisorDigitIdx + quotentDigitIdx]
  RDM
  ADD rr2
  XCH rr3
  TCC
  XCH rr0
  LD rr3
  ADD rr4
  WRM
  TCC
  ADD rr0
  XCH rr4
  INC rr5
  ISZ rr8, div_buf_by_numerator_get_quotient_digit_add_digit
div_buf_by_numerator_get_quotient_digit_add_digit_last_digit:
  FIM r0, 0xF0
  LD rr11
  ADD rr7
  XCH rr1
  SRC r0
  // dividend[dividendDigitIdx]
  RDM
  ADD rr4
  WRM
  CLC
div_buf_by_numerator_get_quotient_digit_return:
  BBL 0

// shift right multiword number
// INPUT:
//   rr7 - shift value
//   rr6 - (4 - shift value)
//   rr1 - character index in memory for LSW
//   rr2 - number of words
div_buf_by_numerator_shift_number_right:
  LDM 0xF
  XCH rr0
  LD rr2
  CMA
  IAC
  XCH rr2
div_buf_by_numerator_shift_number_right_digit:
  SRC r0
  RDM
  XCH rr4
  JMS shift_right
  INC rr1
  SRC r0
  RDM
  XCH rr3
  JMS shift_left
  LD rr1
  DAC
  XCH rr1
  SRC r0
  CLC
  LD rr3
  ADD rr4
  WRM
  INC rr1
  ISZ rr2, div_buf_by_numerator_shift_number_right_digit
  BBL 0

// divide N-word number from buffer by M-word number
// INPUT:
//   dividend - bank #7, register #F, main characters [0..4], LSW at #0 character
//   divisor - bank #7, register #F, main characters [5..9]
// OUTPUT:
//   quotient - rr8/rr9
//   reminder - bank #7, register #F, main characters [0..4]
// REGISTER UNMODIFIED:
//   rr12/rr13/rr14/rr15
// REGISTER MODIFIED:
//   rr10 - number of words for dividend
//   rr11 - number of words for divisor
div_buf_by_numerator:
  // get word count for dividend
  LDM 0x5
  XCH rr1
  LDM 0x6
  XCH rr2
  JMS div_buf_by_numerator_number_len
  LD rr2
  XCH rr10
  // get word count for divisor
  LDM 0xA
  XCH rr1
  LDM 0x6
  XCH rr2
  JMS div_buf_by_numerator_number_len
  LD rr2
  XCH rr11
  // check if dividend >= divisor, otherwise return quotient = 0
  JMS div_buf_by_numerator_is_dividend_bigger_or_equal_than_divisor
  JCN c, div_buf_by_numerator_dividend_is_bigger_or_equal_than_divisor
  FIM r4, 0x00
  BBL 0
div_buf_by_numerator_dividend_is_bigger_or_equal_than_divisor:
  // check if we have 4bit divisor, in that case we use faster and simpler calculations
  CLC
  LDM 1
  SUB rr11
  JCN z, div_buf_by_numerator_one_word_divisor
  // shift divisor and dividend to X bits to make sure that MSB for divisor is set
  // in that case we can estimate quotient digit with high probability to match real digit
  JMS div_buf_by_numerator_normalize_get_shift_value
  FIM r0, 0xF9
  SRC r0
  LD rr6
  WRM
  JCN z, div_buf_by_numerator_normalize_finish
  LDM 4
  SUB rr6
  CLC
  XCH rr7
  LD rr10
  XCH rr2
  LDM 0
  ADD rr2
  XCH rr1
  JMS div_buf_by_numerator_shift_number_left
  LD rr11
  XCH rr2
  LDM 5
  ADD rr2
  XCH rr1
  JMS div_buf_by_numerator_shift_number_left
div_buf_by_numerator_normalize_finish:
  LD rr10
  SUB rr11
  CLC
  JCN z, div_buf_by_numerator_get_lsw_for_quotient
  // 2nd digit for quotient, if necessary
  LDM 1
  XCH rr7
  JMS div_buf_by_numerator_get_quotient_digit
  LD rr6
  XCH rr9
div_buf_by_numerator_get_lsw_for_quotient:
  // 1st digit for quotient
  LDM 0
  XCH rr7
  JMS div_buf_by_numerator_get_quotient_digit
  LD rr6
  XCH rr8
  // denormalization
  FIM r0, 0xF9
  SRC r0
  RDM
  JCN z, div_buf_by_numerator_return
  XCH rr7
  LDM 4
  SUB rr7
  CLC
  XCH rr6
  LDM 0x0
  XCH rr1
  LD rr11
  XCH rr2
  JMS div_buf_by_numerator_shift_number_right
  LDM 0x5
  XCH rr1
  LD rr11
  XCH rr2
  JMS div_buf_by_numerator_shift_number_right
  FIM r0, 0xF9
  SRC r0
  LDM 0x0
  WRM
div_buf_by_numerator_return:
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
