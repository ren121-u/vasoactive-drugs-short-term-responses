-- Values of PAP from 30 minutes before to 120 minutes after initiation of a vasoactive drug.
-- Observation is truncated at the end of, or a rate change in, that drug, and at the start of, end of,
-- or a rate change in any other vasoactive drug.

with
  -- Extract the start and end time of the first continuous infusion of each vasoactive drug
  main_drug_period as (
    select
      icu_stay_id,
      active_ingredient_name,
      min(start_time) as main_start_time,
      min_by(end_time, start_time) as main_end_time,
    from `medicu-beta.latest_one_icu_derived.infusion_injection_active_ingredient_rate_smoothed`
    where active_ingredient_name in (
      'noradrenaline', 
      'dopamine', 
      'dobutamine'
    )
    and source = 'infusions'
    group by icu_stay_id, active_ingredient_name
  )
  -- Exclusion list based on the start or end of another vasoactive drug between 30 minutes before and the time of initiation of the main drug
  , exclude_by_different_drugs as (
    select distinct icu_stay_id, main_active_ingredient_name, exclude_flag
    from (
      select
        v1.icu_stay_id as icu_stay_id,
        v1.active_ingredient_name as main_active_ingredient_name,
        1 as exclude_flag,
      from main_drug_period v1
      inner join (
        select
          icu_stay_id,
          active_ingredient_name,
          start_time,
          end_time,
        from `medicu-beta.latest_one_icu_derived.infusion_injection_active_ingredient_rate_smoothed`
        where active_ingredient_name in (
          'noradrenaline', 
          'adrenaline', 
          'dopamine', 
          'dobutamine',
          'phenylephrine',
          'vasopressin'
        )
      ) v2
      on v1.icu_stay_id = v2.icu_stay_id
      where v1.active_ingredient_name != v2.active_ingredient_name
      and (((timestamp_sub(v1.main_start_time, interval 30 minute) <= v2.start_time) and (v2.start_time <= v1.main_start_time))
        or ((timestamp_sub(v1.main_start_time, interval 30 minute) <= v2.end_time) and (v2.end_time <= v1.main_start_time)))
    )
  )
  -- Exclusion using the list above
  , without_different_drug as (
    select
      v.icu_stay_id as icu_stay_id,
      active_ingredient_name,
      main_start_time,
      main_end_time,
    from main_drug_period as v
    left join exclude_by_different_drugs e
    on v.icu_stay_id = e.icu_stay_id
      and v.active_ingredient_name = e.main_active_ingredient_name
    where exclude_flag is null
  )
  -- Candidate time to stop observation, defined by the start of another vasoactive drug after initiation of the main drug
  , sub_drug_administration as (
    select
      icu_stay_id,
      active_ingredient_name,
      min(start_time) as sub_drug_start,
    from without_different_drug
    inner join (
      select
        icu_stay_id, 
        start_time,
      from `medicu-beta.latest_one_icu_derived.infusion_injection_active_ingredient_rate_smoothed`
      where active_ingredient_name in (
        'noradrenaline', 
        'adrenaline', 
        'dopamine', 
        'dobutamine', 
        'phenylephrine', 
        'vasopressin'
      )
    ) using (icu_stay_id)
    where main_start_time < start_time
    group by icu_stay_id, active_ingredient_name
  )
  -- Candidate time to stop observation, defined by the end of, or an infusion-rate change in, another vasoactive drug after initiation of the main drug
  , sub_drug_finish as (
    select
      icu_stay_id,
      active_ingredient_name,
      min(end_time) as sub_drug_end,
    from without_different_drug
    inner join (
      select
        icu_stay_id, 
        end_time,
      from `medicu-beta.latest_one_icu_derived.infusion_injection_active_ingredient_rate_smoothed`
      where active_ingredient_name in (
        'noradrenaline', 
        'adrenaline', 
        'dopamine', 
        'dobutamine', 
        'phenylephrine', 
        'vasopressin'
      )
    ) using (icu_stay_id)
    where main_start_time < end_time
    group by icu_stay_id, active_ingredient_name      
  )
  -- Administration period of the main vasoactive drug (accounting for other vasoactive drugs)
  , main_drug_true_period as (
    select
      w.icu_stay_id as icu_stay_id,
      w.active_ingredient_name as active_ingredient_name,
      main_start_time,
      least (
        main_end_time,
        timestamp_add((main_start_time), interval 120 minute),
        coalesce(sub_drug_start, timestamp '9999-01-01 00:00:00 UTC'),
        coalesce(sub_drug_end, timestamp '9999-01-01 00:00:00 UTC')
      ) as measurement_stop_time,
    from without_different_drug w
    left join sub_drug_administration s
      on w.icu_stay_id = s.icu_stay_id
      and w.active_ingredient_name = s.active_ingredient_name
    left join sub_drug_finish f
      on w.icu_stay_id = f.icu_stay_id
      and w.active_ingredient_name = f.active_ingredient_name
  )
  -- Obtain PAP from advanced_hemodynamic_monitoring
  , gain_pap as (
    select
      icu_stay_id,
      active_ingredient_name,
      main_start_time,
      time, 
      measurement_stop_time,
      pap_mean as pap,
    from main_drug_true_period
    inner join `medicu-beta.latest_one_icu.advanced_hemodynamic_monitoring` using (icu_stay_id)
    where timestamp_sub(main_start_time, interval 30 minute) <= time
    and time <= measurement_stop_time
  )
  -- Final output
  , final as (
    select
      icu_stay_id,
      active_ingredient_name,
      main_start_time,
      time,
      measurement_stop_time,
      pap,
    from gain_pap
    where pap is not null
  )

select *
from final
inner join `medicu-production.research_vasoactive_drugs_short_term_responses_2025.01_eligibility_criteria` using (icu_stay_id)
order by icu_stay_id, active_ingredient_name, time
