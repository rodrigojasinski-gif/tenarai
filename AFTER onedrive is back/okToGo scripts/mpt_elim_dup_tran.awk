###############################################################################################
#
#  Input:  Standard Mitchell Reformat File be sorted by "OLD PART NUMBER"
#
#  Output: ONLY ONE Transaction Record will be output for a group of "OLD PART NUMBERS"
#          The output records is determined by the hierarch of transaction codes.
#          Transaction code hierarchy:  A, C, N, P, D (meaning A has priority over C,N,P,D
#                                                              C has priority over N,P,D
#                                                              N has priority over P,D
#                                                              P has priority over D
#                                                              D
#          Example Input:
#                    +-------------+-----------------+
#                    | Transaction | Old Part Number |
#                    +-------------+-----------------+
#                    |      A      |       1         |
#                    |      P      |       1         |
#                    |      P      |       2         |
#                    |      N      |       2         |
#                    |      C      |       3         |
#                    |      D      |       3         |
#                    |      P      |       3         |
#                    |      A      |       3         |
#                    |      D      |       4         |
#                    |      P      |       5         |
#                    |      D      |       5         |
#                    +-------------+-----------------+
#          Example Output:
#                    +-------------+-----------------+
#                    | Transaction | Old Part Number |
#                    +-------------+-----------------+
#                    |      A      |       1         |
#                    |      N      |       2         |
#                    |      A      |       3         |
#                    |      D      |       4         |
#                    |      P      |       5         |
#                    +-------------+-----------------+
###############################################################################################
 BEGIN {
     Key1Pos = 7
     Key1Len = 25

     Blanks = sprintf("%s", " ")
     while (length(Blanks) < 187)
     {
         Blanks = Blanks Blanks
     }
     getline                                            # Read first line
     PrevRcd = substr($0 Blanks,1,187)                  # Set PrevRcd to first line
 }

 {
     CurrRcd = substr($0 Blanks,1,187)
     if (substr(PrevRcd,Key1Pos,Key1Len) == substr(CurrRcd,Key1Pos,Key1Len))
     {
         if (substr(PrevRcd,1,1) == "A")                # Test PrevRcd for type A
         {
             next #continue

         } else
         if (substr(PrevRcd,1,1) == "C")                # Test PrevRcd for type C
         {
             if (index("A",substr(CurrRcd,1,1)) > 0)    # Test current record for type A
             {
                 PrevRcd = CurrRcd                      # Save  current A record
             }
         } else
         if (substr(PrevRcd,1,1) == "N")                # Test PrevRcd for type N
         {
             if (index("AC",substr(CurrRcd,1,1)) > 0)   # Test current record for type A or C
             {
                 PrevRcd = CurrRcd                      # Save  current A or C record
             }
         } else
         if (substr(PrevRcd,1,1) == "P")                # Test PrevRcd for type P
         {
             if (index("ACN",substr(CurrRcd,1,1)) > 0)  # Test current record for type A, C, or N
             {
                 PrevRcd = CurrRcd                      # Save  current A, C, or N record
             }
         } else
         if (substr(PrevRcd,1,1) == "D")                # Test PrevRcd for type D
         {
             if (index("ACNP",substr(CurrRcd,1,1)) > 0) # Test current record for type A,C N, or P
             {
                 PrevRcd = CurrRcd                      # Save  current A, C, N or P record
             }
         }
     } else {
         print PrevRcd                                  # Print Previous Record
         PrevRcd = CurrRcd                              # Set PrevRcd to current record
     }
 }

 END {
     print PrevRcd                                      # Print last record
 }
