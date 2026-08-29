-- Patients meeting the eligibility criteria of the study (returns icu_stay_id).

with
  -- inclusion criteria
  -- 1. icd10 in (I2~, I3~, I050, I052, I071) but not in (I30~32) 
  -- 2. Cases after cardiac surgery
  inclusion_criteria as (
    select distinct icu_stay_id
    from `medicu-beta.latest_one_icu_derived.extended_icu_diagnoses`
    left join `medicu-beta.latest_one_icu_derived.extended_icu_stays` using (icu_stay_id)
    where 
      -- 1. icd10 in (I2~, I3~, I050, I052, I071) but not in (I30~32)
      (icd10 like 'I2%'
      or icd10 in (
        'I050',
        'I052',
        'I071'
      )
      or (
        icd10 like 'I3%' 
        and (
          icd10 not like 'I30%'
          and icd10 not like 'I31%'
          and icd10 not like 'I32%'
        )
      ))
      -- 2. Cases after cardiac surgery
      and icu_stay_id in (
        select distinct icu_stay_id
        from `medicu-beta.latest_one_icu.surgery`
        where kcode in (
          'K538',
          'K538-2',
          'K539',
          'K539-2',
          'K539-3',
          'K540',
          'K541',
          'K542',
          'K543',
          'K544',
          'K545',
          -- Percutaneous procedures are excluded
          -- 'K546',
          -- 'K547',
          -- 'K548',
          'K549',
          'K550',
          'K550-2',
          'K551',
          'K552',
          -- TAVI is excluded
          -- 'K552-2',
          'K553',
          'K553-2',
          'K554',
          'K554-2',
          'K555',
          'K555-2',
          'K555-3',
          'K556',
          -- TAVI is excluded
          -- 'K556-2',
          'K557',
          'K557-2',
          'K557-3',
          'K557-4',
          'K558',
          'K559',
          -- Percutaneous procedures are excluded
          -- 'K559-2',
          -- 'K559-3',
          'K560',
          'K560-2',
          'K561',
          'K562',
          'K562-2',
          'K563',
          'K564',
          'K565',
          'K566',
          'K567',
          -- Percutaneous procedures are excluded
          -- 'K567-2',
          'K568',
          'K569',
          'K570',
          'K570-2',
          'K570-3',
          'K570-4',
          'K571',
          'K572',
          'K573',
          'K574',
          -- Percutaneous procedures are excluded
          -- 'K574-2',
          -- 'K574-3',
          'K574-4',
          'K575',
          'K576',
          'K577',
          'K578',
          'K579',
          'K579-2',
          'K580',
          'K581',
          'K582',
          'K583',
          'K584',
          'K585',
          'K586',
          'K587',
          'K588',
          'K589',
          'K590',
          'K591',
          'K592',
          'K592-2',
          'K593',
          'K594',
          'K594-2',
          'K605',
          'K605-2',
          'K605-3',
          'K605-4',
          'K605-5'
        )
      )
  ),  
  -- exclusion criteria
  -- 1. Cases without a recorded age or sex
  -- 2. Pediatric cases (age < 15 years)
  -- 3. Cases treated with ECMO
  -- 4. Cases treated with Impella
  exclusion_criteria as (
    with
    -- 1. Cases without a recorded age or sex
      no_recorded_gender_age as (
        select distinct icu_stay_id
        from inclusion_criteria
        where
          icu_stay_id not in (
            select distinct icu_stay_id
            from `medicu-beta.latest_one_icu_derived.extended_icu_stays`
            where age is not null and female is not null
          )
        ),
    -- 2. Pediatric cases (age < 15 years)
      age_less_than_15 as (
        select distinct icu_stay_id
        from inclusion_criteria
        where
          icu_stay_id not in (
            select distinct icu_stay_id
            from `medicu-beta.latest_one_icu_derived.extended_icu_stays`
            where age >= 15
          )
      ),
    -- 3. Cases treated with ECMO
      using_ecmo as (
        select distinct icu_stay_id
        from `medicu-beta.latest_one_icu.ecmo`
      ),
    -- 4. Cases treated with Impella
      using_impella as (
        select distinct icu_stay_id
        from `medicu-beta.latest_one_icu.impella`
      )
    select icu_stay_id
    from no_recorded_gender_age
    union distinct
    select icu_stay_id
    from age_less_than_15
    union distinct
    select icu_stay_id
    from using_ecmo
    union distinct
    select icu_stay_id
    from using_impella   
  )

select icu_stay_id
from inclusion_criteria
where icu_stay_id not in (select distinct icu_stay_id from exclusion_criteria)
