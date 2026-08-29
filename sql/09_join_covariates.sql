with
    inclusion as (
        select
            icu_stay_id,
            active_ingredient_name,
            female,
            age,
            body_weight,
            apache2_score,
            in_time,
            diagnosis_category,
            surgery_category,
            ph,
            bicarbonate,
            base_excess,
            pco2,
            lactate,
            hr_pre,
            map_pre,
            first_drug_rate,
            gamma,
            on_vent,
            on_rrt,
        from `medicu-production.research_vasoactive_drugs_short_term_responses_2025.101_time_fixed_vasoactive_drug_rate`
        left join
            `medicu-production.research_vasoactive_drugs_short_term_responses_2025.02_static_variables`
            using (icu_stay_id)
        left join
            `medicu-production.research_vasoactive_drugs_short_term_responses_2025.102_time_fixed_mv_use`
            using (icu_stay_id, active_ingredient_name)
        left join
            `medicu-production.research_vasoactive_drugs_short_term_responses_2025.103_time_fixed_blood_gas`
            using (icu_stay_id, active_ingredient_name)
        left join
            `medicu-production.research_vasoactive_drugs_short_term_responses_2025.104_time_fixed_vital_sign`
            using (icu_stay_id, active_ingredient_name)
        left join
            `medicu-production.research_vasoactive_drugs_short_term_responses_2025.105_time_fixed_rrt_use`
            using (icu_stay_id, active_ingredient_name)
        left join
            `medicu-production.research_vasoactive_drugs_short_term_responses_2025.106_bodyweight`
            using (icu_stay_id, active_ingredient_name)
    )

select *
from inclusion
order by icu_stay_id, active_ingredient_name
