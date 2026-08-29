with
    static_table as (
        select
            icu_stay_id,
            female,
            age,
            body_weight,
            apache2_score,
            in_time,
        from `medicu-beta.latest_one_icu_derived.extended_icu_stays`
        left join `medicu-beta.latest_one_icu_derived.apache2` using (icu_stay_id)
    ),
    join_diagnosis as (
        select 
            icu_stay_id,
            category as diagnosis_category
       from `medicu-beta.latest_one_icu_derived.unioned_icu_diagnoses` 
       where primary
    ),
    join_surgery as (
        select
            icu_stay_id,
            case
                when kcode is null then null
                when kcode in (
                  'K555',
                  'K554',
                  'K555-2',
                  'K559-3',
                  'K554-2'
                )
                then 'valvular'
                when kcode in (
                  'K560',
                  'K561',
                  'K570-3',
                  'K560-2',
                  'K615',
                  'K610',
                  'K178-4'
                )
                then 'aortic and vascular'
                when kcode in (
                  'K552',
                  'K546',
                  'K552-2',
                  'K549',
                  'K588',
                  'K551'
                )
                then 'coronary'
                else 'others'
            end as surgery_category,
        from `medicu-beta.latest_one_icu.surgery`
    )
select distinct *
from static_table
left join join_diagnosis using (icu_stay_id)
left join join_surgery using (icu_stay_id)
where icu_stay_id in (select icu_stay_id from `medicu-production.research_vasoactive_drugs_short_term_responses_2025.01_eligibility_criteria`)
