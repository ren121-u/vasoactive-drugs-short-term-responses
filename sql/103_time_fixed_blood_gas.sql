with
    bg_table as (
        select
            icu_stay_id,
            active_ingredient_name,
            field_name,
            value,
            time as measurement_time,
            main_start_time,
        from `medicu-beta.latest_one_icu.blood_gas`
        inner join `medicu-production.research_vasoactive_drugs_short_term_responses_2025.101_time_fixed_vasoactive_drug_rate` using (icu_stay_id)
        where
            field_name in ('ph', 'bicarbonate', 'base_excess', 'pco2', 'lactate')
            and sample_type = "arterial_blood_gas"
    ),
    pivoted as (
        select
            icu_stay_id,
            active_ingredient_name,
            main_start_time,
            measurement_time,
            ph,
            bicarbonate,
            base_excess,
            pco2,
            lactate,
        from
            bg_table pivot (
                max(value) for field_name
                in ('ph', 'bicarbonate', 'base_excess', 'pco2', 'lactate')
            )
    ),
    ph_pre_tab as (
        select
            icu_stay_id,
            active_ingredient_name,
            max(measurement_time) as ph_measurement_time_pre,
            max_by(ph, measurement_time) as ph_pre,
        from pivoted
        where measurement_time < main_start_time
        and ph is not null
        group by icu_stay_id, active_ingredient_name
    ),
    ph_after_tab as (
        select
            icu_stay_id,
            active_ingredient_name,
            min(measurement_time) as ph_measurement_time_after,
            min_by(ph, measurement_time) as ph_after,
        from pivoted
        where main_start_time <= measurement_time
        and ph is not null
        group by icu_stay_id, active_ingredient_name
    ),
    bicarbonate_pre_tab as (
        select
            icu_stay_id,
            active_ingredient_name,
            max(measurement_time) as bicarbonate_measurement_time_pre,
            max_by(bicarbonate, measurement_time) as bicarbonate_pre,
        from pivoted
        where measurement_time < main_start_time
        and bicarbonate is not null
        group by icu_stay_id, active_ingredient_name
    ),
    bicarbonate_after_tab as (
        select
            icu_stay_id,
            active_ingredient_name,
            min(measurement_time) as bicarbonate_measurement_time_after,
            min_by(bicarbonate, measurement_time) as bicarbonate_after,
        from pivoted
        where main_start_time <= measurement_time
        and bicarbonate is not null
        group by icu_stay_id, active_ingredient_name
    ),
    base_excess_pre_tab as (
        select
            icu_stay_id,
            active_ingredient_name,
            max(measurement_time) as base_excess_measurement_time_pre,
            max_by(base_excess, measurement_time) as base_excess_pre,
        from pivoted
        where measurement_time < main_start_time
        and base_excess is not null
        group by icu_stay_id, active_ingredient_name
    ),
    base_excess_after_tab as (
        select
            icu_stay_id,
            active_ingredient_name,
            min(measurement_time) as base_excess_measurement_time_after,
            min_by(base_excess, measurement_time) as base_excess_after
        from pivoted
        where main_start_time <= measurement_time
        and base_excess is not null
        group by icu_stay_id, active_ingredient_name
    ),
    pco2_pre_tab as (
        select
            icu_stay_id,
            active_ingredient_name,
            max(measurement_time) as pco2_measurement_time_pre,
            max_by(pco2, measurement_time) as pco2_pre,
        from pivoted
        where measurement_time < main_start_time
        and pco2 is not null
        group by icu_stay_id, active_ingredient_name
    ),
    pco2_after_tab as (
        select
            icu_stay_id,
            active_ingredient_name,
            min(measurement_time) as pco2_measurement_time_after,
            min_by(pco2, measurement_time) as pco2_after,
        from pivoted
        where main_start_time <= measurement_time
        and pco2 is not null
        group by icu_stay_id, active_ingredient_name
    ),
    lactate_pre_tab as (
        select
            icu_stay_id,
            active_ingredient_name,
            max(measurement_time) as lactate_measurement_time_pre,
            max_by(lactate, measurement_time) as lactate_pre,
        from pivoted
        where measurement_time < main_start_time
        and lactate is not null
        group by icu_stay_id, active_ingredient_name
    ),
    lactate_after_tab as (
        select
            icu_stay_id,
            active_ingredient_name,
            min(measurement_time) as lactate_measurement_time_after,
            min_by(lactate, measurement_time) as lactate_after,
        from pivoted
        where main_start_time <= measurement_time
        and lactate is not null
        group by icu_stay_id, active_ingredient_name
    ),
    bg_coalesce_tab as (
        select
            icu_stay_id,
            active_ingredient_name,
            coalesce(ph_pre, ph_after) as ph,
            coalesce(bicarbonate_pre, bicarbonate_after) as bicarbonate,
            coalesce(base_excess_pre, base_excess_after) as base_excess,
            coalesce(pco2_pre, pco2_after) as pco2,
            coalesce(lactate_pre, lactate_after) as lactate
        from `medicu-production.research_vasoactive_drugs_short_term_responses_2025.101_time_fixed_vasoactive_drug_rate` 
        left join 
            ph_pre_tab using (icu_stay_id, active_ingredient_name)
        left join
            ph_after_tab using (icu_stay_id, active_ingredient_name)
        left join
            bicarbonate_pre_tab using (icu_stay_id, active_ingredient_name)
        left join
            bicarbonate_after_tab using (icu_stay_id, active_ingredient_name)
        left join
            base_excess_pre_tab using (icu_stay_id, active_ingredient_name)
        left join
            base_excess_after_tab using (icu_stay_id, active_ingredient_name)
        left join
            pco2_pre_tab using (icu_stay_id, active_ingredient_name)
        left join
            pco2_after_tab using (icu_stay_id, active_ingredient_name)
        left join
            lactate_pre_tab using (icu_stay_id, active_ingredient_name)
        left join   
            lactate_after_tab using (icu_stay_id, active_ingredient_name)
    )
    
select *
from bg_coalesce_tab
order by icu_stay_id, active_ingredient_name
