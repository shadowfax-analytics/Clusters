SELECT 
case b.city
when 'GGN' then 'Gurgaon'
when 'BOM' then 'Mumbai'
when 'DEL' then 'Delhi'
when 'BLR' then 'Bangalore'
when 'NOIDA' then 'Noida' end as City, b.cluster_name ,a.id  , a.target_date,a.target_value,a.target_achieved,case a.target_status 
when 0 then 'Not Achieved'
when 1 then 'Achieved' 
end as traget_status 

,b.current_manager 
FROM coreengine_target a , coreengine_cluster b 
 where
 a.cluster_id=b.id and 
 b.cluster_name not like "%Test%" and 
 month(a.target_date)=12
 order by a.target_date