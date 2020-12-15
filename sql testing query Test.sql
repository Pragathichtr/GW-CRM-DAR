select * from 
( 
WITH Latest_Work_Order AS 
    ( SELECT parent_bus_interact_id, max(child_bus_interact_id) as latest_work_order_id FROM chtr.t_bus_interact_related GROUP BY Parent_Bus_Interact_Id ), 
      Work_Order_Info AS ( SELECT to_char(wo.create_dttm, 'mm/dd/yyyy hh:mm:ss') AS SOLO_ORDER_CREATED_DT, wo.work_order_id, service_address_id, wo.create_dttm, dbroot , 
      DATA_SOURCE_TYPE_DESC, SOURCE_SYSTEM_NAME, BILLING_STATION_LEVEL_0_CD, DB_INSTANCE_ID, CREATED_BY, wo.data_source_type_cd, to_char(wo.MODIFIED_DTTM , 'mm/dd/yyyy hh:mm:ss') AS SOLO_LAST_CHANGE_DT, 
      wos.WORK_ORDER_STATUS_CD , ds.BILLING_STATION_LEVEL_0_CD AS BILLER_SITE, wosh.WORK_ORDER_SCHEDULE_DT, wow.WORK_ORDER_WINDOW_DESC, 
      CASE WHEN wo.data_source_type_cd = '100' THEN 'CSG_TWC' 
           WHEN wo.data_source_type_cd = 'VNT' THEN 'CSG_CHR' 
           WHEN wo.data_source_type_cd = '101' THEN 'ICOMS_East' 
           WHEN wo.data_source_type_cd = '102' THEN 'ICOMS_KC' 
           WHEN wo.data_source_type_cd = '103' THEN 'ICOMS_NAT' 
           WHEN wo.data_source_type_cd IN ('104','105','106','107') THEN 'ICOMS_Midwest' 
           WHEN wo.data_source_type_cd = '108' THEN 'ICOMS_BHN' 
           WHEN wo.data_source_type_cd = '109' THEN 'ICOMS_BHNBUS' 
      ELSE wo.data_source_type_cd END AS biller 
         FROM 
         (select data_source_type_cd, work_order_class_cd, work_order_id, service_address_id, w.create_dttm, w.CREATED_BY , W.MODIFIED_DTTM 
         FROM chtr.t_work_order w 
         WHERE work_order_class_cd NOT IN ('T', 'TC', 'Z', 'SR') 
         AND TRUNC(create_dttm) >= add_months(sysdate,-1) and record_stat='A') wo 
         INNER JOIN (select WORK_ORDER_ID, WORK_ORDER_STATUS_CD, DATA_SOURCE_TYPE_CD from chtr.t_work_order_status) wos 
            ON wos.WORK_ORDER_ID = wo.WORK_ORDER_ID and wos.DATA_SOURCE_TYPE_CD =wo.DATA_SOURCE_TYPE_CD 
         INNER JOIN (select data_source_type_cd, DBROOT , DATA_SOURCE_TYPE_DESC, SOURCE_SYSTEM_NAME, BILLING_STATION_LEVEL_0_CD, DB_INSTANCE_ID from chtr.t_data_source_type_cd) ds 
            ON wo.data_source_type_cd = ds.data_source_type_cd 
         LEFT JOIN (select WORK_ORDER_ID, WORK_ORDER_SCHEDULE_DT , WORK_ORDER_WINDOW_CD, DATA_SOURCE_TYPE_CD from chtr.t_work_order_schedule) wosh 
            ON wosh.WORK_ORDER_ID = wo.WORK_ORDER_ID and wosh.DATA_SOURCE_TYPE_CD =wo.DATA_SOURCE_TYPE_CD 
        LEFT JOIN (select WORK_ORDER_WINDOW_CD, WORK_ORDER_WINDOW_DESC from chtr.t_work_order_window_cd) wow 
            ON wow.WORK_ORDER_WINDOW_CD = wosh.WORK_ORDER_WINDOW_CD 
            ) 
            SELECT distinct biller, BILLER_ACCOUNT_NUMBER, SOLO_ACCOUNT_NAME, SOLO_ADDRESS_LINE1, SOLO_ADDRESS_LINE2, SOLO_CITY, SOLO_STATE, SOLO_ZIP , SOLO_CREATED_BY, 
            BILLER_ORDER_NUMBER , BILLERSITE , SOLO_ORDER_STATUS , SOLO_ORDER_STATUS_DESC , SOLO_SCHEDULE_DATE, SOLO_SCHEDULE_TIME_SLOT, CREATED_DATE, CUST_TYP_CUS 
            FROM             
            ( SELECT biller,a.account_num as BILLER_ACCOUNT_NUMBER, a.ACCOUNT_NM as SOLO_ACCOUNT_NAME, va.SERVICE_ADDRESS_LINE_1 as SOLO_ADDRESS_LINE1, va.SERVICE_ADDRESS_LINE_2 as SOLO_ADDRESS_LINE2, 
            va.SERVICE_ADDRESS_CITY as SOLO_CITY, va.SERVICE_ADDRESS_STATE as SOLO_STATE, va.SERVICE_ADDRESS_POSTAL_CODE as SOLO_ZIP, wo.CREATED_BY as SOLO_CREATED_BY, wo.BILLER_SITE as BILLERSITE, 
            pos.PRODUCT_ORDER_STATUS_CD as SOLO_ORDER_STATUS, wo.WORK_ORDER_SCHEDULE_DT as SOLO_SCHEDULE_DATE, wo.WORK_ORDER_WINDOW_DESC as SOLO_SCHEDULE_TIME_SLOT, bi.SOURCE_SYSTEM_ID as BILLER_ORDER_NUMBER, 
            to_char(wo.create_dttm, 'mm/dd/yyyy') AS CREATED_DATE, A.ACCOUNT_TYPE_CD AS CUST_TYP_CUS, 
            CASE WHEN pos.PRODUCT_ORDER_STATUS_CD IN ('O','_') THEN 'OPEN' 
                 WHEN pos.PRODUCT_ORDER_STATUS_CD IN ('C','CP') THEN 'COMPLETE' 
                 WHEN pos.PRODUCT_ORDER_STATUS_CD IN ('X','CN') THEN 'CANCELLED' 
                 WHEN pos.PRODUCT_ORDER_STATUS_CD = 'R' THEN 'RESCHEDULED' 
                 WHEN pos.PRODUCT_ORDER_STATUS_CD = 'H' THEN 'HELD' 
            ELSE pos.PRODUCT_ORDER_STATUS_CD END AS SOLO_ORDER_STATUS_DESC
            FROM chtr.t_bus_interact bi INNER JOIN Latest_Work_Order lwo ON bi.bus_interact_id = lwo.parent_bus_interact_id 
            INNER JOIN chtr.t_prod_order po ON bi.bus_interact_id = po.product_order_id 
            INNER JOIN chtr.t_prod_order_status pos ON bi.bus_interact_id = pos.product_order_id 
            INNER JOIN Work_Order_Info wo ON lwo.latest_work_order_id = wo.work_order_id 
            INNER JOIN chtr.t_bus_interact_party_role bipr ON bipr.bus_interact_id = wo.work_order_id AND bipr.party_role_cd = 'CUST' 
            INNER JOIN chtr.t_party_account pa ON pa.party_id = bipr.party_id 
            INNER JOIN chtr.t_account a ON a.account_id = pa.account_id 
            INNER JOIN chtr.t_service_address sa ON sa.service_address_id = wo.service_address_id 
            INNER JOIN chtr.vw_account_detail va ON va.account_id = a.account_id 
            WHERE bi.source_channel = 'G' 
                 AND (PRODUCT_ORDER_STATUS_CD IN ('C','X') 
                 AND TRUNC(po.ACTUAL_COMPLETION_DTTM) <= TRUNC(SYSDATE - 2) OR PRODUCT_ORDER_STATUS_CD NOT IN ('C','X')) 
          )A1 ORDER BY biller, BILLERSITE, BILLER_ORDER_NUMBER 
)
                 
                 
