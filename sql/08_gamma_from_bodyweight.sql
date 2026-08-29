with
    bodyweight_table as (
        select
            icu_stay_id,
            coalesce(body_weight, measured_body_weight) as body_weight,
        from `medicu-beta.latest_one_icu_derived.extended_icu_stays`
        inner join (
            select
                icu_stay_id,
                min_by(body_weight,time) as measured_body_weight,
            from `medicu-beta.latest_one_icu.body_weight_measurements`
            group by icu_stay_id
        ) using (icu_stay_id)
        where coalesce(body_weight, measured_body_weight) is not null
    ),
    gamma_table as (
        select
            icu_stay_id,
            active_ingredient_name,
            1000*first_drug_rate / (body_weight * 60) as gamma,
        from `medicu-production.research_vasoactive_drugs_short_term_responses_2025.03_vasoactive_drug_rate`
        inner join bodyweight_table using (icu_stay_id)
    ) 

select *
from gamma_table
order by icu_stay_id, active_ingredient_name