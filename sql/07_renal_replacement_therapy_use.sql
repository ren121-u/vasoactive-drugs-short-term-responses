with
    -- Whether renal replacement therapy is used. on_rrt denotes current use. 0 = not used, 1 = used
    rrt_use_table as (
        select
            icu_stay_id,
            active_ingredient_name,
            case
                when
                    start_time <= main_start_time
                    and main_start_time <= end_time
                then 1
                else 0
            end as on_rrt,
        from
           `medicu-production.research_vasoactive_drugs_short_term_responses_2025.03_vasoactive_drug_rate`
        left join
            `medicu-beta.latest_one_icu.renal_replacement_therapy` using (icu_stay_id)
    ),
    rrt_use_max  as (
        select 
            icu_stay_id,
            active_ingredient_name,
            max(on_rrt) as on_rrt,
        from rrt_use_table
        group by icu_stay_id, active_ingredient_name
    )

select 
    icu_stay_id,
    active_ingredient_name,
    on_rrt,
from rrt_use_max
order by icu_stay_id, active_ingredient_name
