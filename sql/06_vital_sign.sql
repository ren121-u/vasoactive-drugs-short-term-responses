with
    -- Preparation table for vital signs
    vital_sign_table as (
        select
            icu_stay_id, 
            active_ingredient_name,
            main_start_time,
            hr,
            invasive_mbp as map,
            time,
        from `medicu-beta.latest_one_icu.vital_measurements`
        inner join `medicu-production.research_vasoactive_drugs_short_term_responses_2025.101_time_fixed_vasoactive_drug_rate` using (icu_stay_id)
    ),
    -- Calculate the median HR and MAP over the 10 minutes before drug initiation
    median_values_pre as (
        select distinct
            icu_stay_id,
            active_ingredient_name,
            percentile_cont(hr, 0.5) over (partition by icu_stay_id, active_ingredient_name) as hr_pre,
            percentile_cont(map, 0.5) over (partition by icu_stay_id, active_ingredient_name) as map_pre,
        from vital_sign_table
        where timestamp_sub(main_start_time, interval 9 minute) <= time
            and time <= main_start_time
    )
    
select *
from median_values_pre
where hr_pre is not null or map_pre is not null
order by icu_stay_id, active_ingredient_name      
