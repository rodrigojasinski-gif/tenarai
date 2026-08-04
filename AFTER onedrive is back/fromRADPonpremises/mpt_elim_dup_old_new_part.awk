################################################################################
#                                                                              #
# This "awk" file will read a sorted file and eliminated duplicate records     #
# on a pre-specified method.                                                   #
#                                                                              #
################################################################################

################################################################################
# Beginning: Field setup and initial input record read. This section is        #
#            performed once.                                                   #
################################################################################
 BEGIN {
     In_tran_cd_pos = 1
     In_tran_cd_len = 1
     In_old_part_num_pos = 7
     In_old_part_num_len = 25
     In_new_part_num_pos = 32
     In_new_part_num_len = 25

     Blanks = sprintf("%s", " ")
     while (length(Blanks) < 187)
     {
         Blanks = Blanks Blanks
     }
     getline                                            # Read first line
     PrevRcd = substr($0 Blanks,1,187)                  # Set PrevRcd to first line
 }
 {
################################################################################
# BODY: This section drops duplicate records.  The first is saved and each     #
#       duplicate that follows is dropped.  There are currently two paths that #
#       can be followed:                                                       #
#          1) tran_cd, old_part_number, new_part_number or                     #
#          2) tran_cd, old_part_number                                         #
#       This section is performed while input records exist.                   #
################################################################################
     CurrRcd = substr($0 Blanks,1,187)
     if (ENVIRON["sort_type"] == "tcd_old_part_new_part")
        if (substr(PrevRcd,In_tran_cd_pos,In_tran_cd_len)           == substr(CurrRcd,In_tran_cd_pos,In_tran_cd_len) &&
           (substr(PrevRcd,In_old_part_num_pos,In_old_part_num_len) == substr(CurrRcd,In_old_part_num_pos,In_old_part_num_len)) &&
           (substr(PrevRcd,In_new_part_num_pos,In_new_part_num_len) == substr(CurrRcd,In_new_part_num_pos,In_new_part_num_len)))
        {
           continue
        }
        else
        {
         print PrevRcd                                  # Print Previous Record
         PrevRcd = CurrRcd                              # Set PrevRcd to current record
        }
     else
     if (ENVIRON["sort_type"] == "tcd_old_part")
        if (substr(PrevRcd,In_tran_cd_pos,In_tran_cd_len)           == substr(CurrRcd,In_tran_cd_pos,In_tran_cd_len) &&
           (substr(PrevRcd,In_old_part_num_pos,In_old_part_num_len) == substr(CurrRcd,In_old_part_num_pos,In_old_part_num_len)))
        {
           continue
        }
        else
        {
         print PrevRcd                                  # Print Previous Record
         PrevRcd = CurrRcd                              # Set PrevRcd to current record
        }
 }
################################################################################
# Ending: Print final record. This section is performed once at the end.       #
################################################################################
 END {
     print PrevRcd                                      # Print last record
 }
