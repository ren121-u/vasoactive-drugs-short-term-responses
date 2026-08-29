with
    -- Whether mechanical ventilation is used. on_vent denotes current use. 0 = not used, 1 = used
    mv_use_table as (
        select
            icu_stay_id,
            active_ingredient_name,
            case
                when
                    start_time <= main_start_time
                    and main_start_time <= end_time
                then 1
                else 0
            end as on_vent,
        from `medicu-production.research_vasoactive_drugs_short_term_responses_2025.101_time_fixed_vasoactive_drug_rate`
        left join `medicu-beta.latest_one_icu.mechanical_ventilations` using (icu_stay_id)
    ),
    mv_use_max as (
        select 
            icu_stay_id, 
            active_ingredient_name,
            max(on_vent) as on_vent, 
        from mv_use_table
        group by icu_stay_id, active_ingredient_name
    )
    
select *
from mv_use_max
order by icu_stay_id, active_ingredient_name
