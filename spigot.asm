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
