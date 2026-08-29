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
        from `medicu-production.research_vasoactive_drugs_short_term_responses_2025.03_vasoactive_drug_rate`
        left join
            `medicu-production.research_vasoactive_drugs_short_term_responses_2025.02_static_variables`
            using (icu_stay_id)
        left join
            `medicu-production.research_vasoactive_drugs_short_term_responses_2025.04_mechanical_ventilation_use`
            using (icu_stay_id, active_ingredient_name)
        left join
            `medicu-production.research_vasoactive_drugs_short_term_responses_2025.05_blood_gas`
            using (icu_stay_id, active_ingredient_name)
        left join
            `medicu-production.research_vasoactive_drugs_short_term_responses_2025.06_vital_sign`
            using (icu_stay_id, active_ingredient_name)
        left join
            `medicu-production.research_vasoactive_drugs_short_term_responses_2025.07_renal_replacement_therapy_use`
            using (icu_stay_id, active_ingredient_name)
        left join
            `medicu-production.research_vasoactive_drugs_short_term_responses_2025.08_gamma_from_bodyweight`
            using (icu_stay_id, active_ingredient_name)
    )

select *
from inclusion
order by icu_stay_id, active_ingredient_name
