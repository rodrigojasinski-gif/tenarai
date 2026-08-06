prompt altpart_supplier_number|country_abbr|altpart_supplier_name|address_line1|address_line2|city|state_abbr|zip_code|primary_phone|secondary_phone|create_date|delete_date|delete_reason_code|oem_discount_flag|data_provider_skey|data_provider_name|price_program_skey|price_program|price_program_desc
 SELECT altpart_supplier_number || '|' || country_abbr || '|' ||
                   altpart_supplier_name || '|' || address_line1 || '|' ||
                   address_line2 || '|' || city || '|' || state_abbr || '|' ||
                   zip_code || '|' || primary_phone || '|' ||
                   secondary_phone || '|' || create_date || '|' ||
                   delete_date || '|' || delete_reason_code || '|' ||
                   oem_discount_flag || '|' || t.data_provider_skey || '|' ||
                   adp.data_provider_name || '|' || t.price_program_skey || '|' ||
                   app.price_program || '|' || price_program_desc
              FROM race.altpart_supplier t,
                   altpart_data_provider adp,
                   altpart_price_program app
             WHERE t.data_provider_skey = adp.data_provider_skey
               AND t.price_program_skey = app.price_program_skey;