prompt oem_part_supplier_number|oem_part_supplier_country_abbr|oem_part_supplier_name|oem_part_number|altpart_description|altpart_number|altpart_supplier_number|altpart_reconditioned_flag|altpart_price|capa_certified_flag|oem_discount_flag|nsf_certified_flag
SELECT lpad(p.part_supplier_number, 3, '0') || '|' ||
                   p.part_supplier_country_abbr || '|' ||
                   ps.part_supplier_name || '|' || p.part_number || '|' ||
                   nvl(TRIM(t1.altpart_description), '') || '|' ||
                   t1.altpart_number || '|' || t1.altpart_supplier_number || '|' ||
                   t1.altpart_reconditioned_flag || '|' ||
                   TRIM(to_char(t1.altpart_price, '9999999999.0000')) || '|' ||
                   t1.capa_certified_flag || '|' || t1.oem_discount_flag || '|' ||
                   t1.nsf_certified_flag
  FROM race.part_altpart_xref t1,
       part                   p,
       part_supplier          ps
 WHERE t1.part_skey = p.part_skey
   AND p.part_supplier_number = ps.part_supplier_number
	 AND p.part_supplier_country_abbr IN ('US', 'CA')
	 and ps.part_supplier_number < 100
   and ps.part_supplier_number not in ('006','007','010','011','015', '077','098','099')
   and ps.part_supplier_number not in ('051','071','072','073','074','075','078'); 
