prompt altpart_supplier_number|begin_zip_code|end_zip_code
  SELECT altpart_supplier_number || '|' || begin_zip_code || '|' ||
                   end_zip_code
              FROM race.altpart_supplier_zip_range az
             ORDER BY altpart_supplier_number,
                      begin_zip_code,
                      end_zip_code;