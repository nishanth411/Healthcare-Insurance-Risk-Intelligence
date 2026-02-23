CREATE DATABASE hospital_insurance_dw;
USE hospital_insurance_dw;

CREATE TABLE raw_patient_data (
    name TEXT,
    age TEXT,
    gender TEXT,
    blood_type TEXT,
    medical_condition TEXT,
    date_of_admission TEXT,
    doctor TEXT,
    hospital TEXT,
    insurance_provider TEXT,
    billing_amount TEXT,
    room_number TEXT,
    admission_type TEXT,
    discharge_date TEXT,
    medication TEXT,
    test_results TEXT
);

LOAD DATA INFILE 
'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/hospital_data.csv'
INTO TABLE raw_patient_data
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

CREATE TABLE clean_patient_data AS
SELECT
    name,
    CAST(age AS UNSIGNED) AS age,
    gender,
    blood_type,
    medical_condition,
    CAST(date_of_admission AS DATE) AS date_of_admission,
    doctor,
    hospital,
    insurance_provider,
    CAST(billing_amount AS DECIMAL(12,2)) AS billing_amount,
    CAST(room_number AS UNSIGNED) AS room_number,
    admission_type,
    CAST(discharge_date AS DATE) AS discharge_date,
    medication,
    test_results
FROM raw_patient_data;

ALTER TABLE clean_patient_data
ADD COLUMN length_of_stay INT;

SET SQL_SAFE_UPDATES = 0;

UPDATE clean_patient_data
SET length_of_stay = DATEDIFF(discharge_date, date_of_admission);

ALTER TABLE clean_patient_data
ADD COLUMN cost_category VARCHAR(20);

UPDATE clean_patient_data
SET cost_category =
    CASE
        WHEN billing_amount > 50000 THEN 'High Cost'
        WHEN billing_amount BETWEEN 20000 AND 50000 THEN 'Medium Cost'
        ELSE 'Low Cost'
    END;

CREATE TABLE dim_patient (
    patient_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255),
    age INT,
    gender VARCHAR(10),
    blood_type VARCHAR(10)
);

INSERT INTO dim_patient (name, age, gender, blood_type)
SELECT DISTINCT name, age, gender, blood_type
FROM clean_patient_data;

CREATE TABLE dim_hospital (
    hospital_id INT AUTO_INCREMENT PRIMARY KEY,
    hospital_name VARCHAR(255)
);

INSERT INTO dim_hospital (hospital_name)
SELECT DISTINCT hospital
FROM clean_patient_data;

CREATE TABLE dim_doctor (
    doctor_id INT AUTO_INCREMENT PRIMARY KEY,
    doctor_name VARCHAR(255)
);

INSERT INTO dim_doctor (doctor_name)
SELECT DISTINCT doctor
FROM clean_patient_data;

CREATE TABLE dim_insurance (
    insurance_id INT AUTO_INCREMENT PRIMARY KEY,
    insurance_provider VARCHAR(255)
);

INSERT INTO dim_insurance (insurance_provider)
SELECT DISTINCT insurance_provider
FROM clean_patient_data;

CREATE TABLE dim_medical_condition (
    condition_id INT AUTO_INCREMENT PRIMARY KEY,
    medical_condition VARCHAR(255)
);

INSERT INTO dim_medical_condition (medical_condition)
SELECT DISTINCT medical_condition
FROM clean_patient_data;

CREATE TABLE dim_date (
    date_id INT AUTO_INCREMENT PRIMARY KEY,
    full_date DATE,
    year INT,
    month INT,
    day INT
);

INSERT INTO dim_date (full_date, year, month, day)
SELECT DISTINCT 
    date_of_admission,
    YEAR(date_of_admission),
    MONTH(date_of_admission),
    DAY(date_of_admission)
FROM clean_patient_data;

CREATE TABLE fact_admissions (
    admission_id INT AUTO_INCREMENT PRIMARY KEY,
    patient_id INT,
    hospital_id INT,
    doctor_id INT,
    insurance_id INT,
    condition_id INT,
    date_id INT,
    billing_amount DECIMAL(12,2),
    length_of_stay INT,
    admission_type VARCHAR(50),
    cost_category VARCHAR(20),

    FOREIGN KEY (patient_id) REFERENCES dim_patient(patient_id),
    FOREIGN KEY (hospital_id) REFERENCES dim_hospital(hospital_id),
    FOREIGN KEY (doctor_id) REFERENCES dim_doctor(doctor_id),
    FOREIGN KEY (insurance_id) REFERENCES dim_insurance(insurance_id),
    FOREIGN KEY (condition_id) REFERENCES dim_medical_condition(condition_id),
    FOREIGN KEY (date_id) REFERENCES dim_date(date_id)
);

INSERT INTO fact_admissions (
    patient_id,
    hospital_id,
    doctor_id,
    insurance_id,
    condition_id,
    date_id,
    billing_amount,
    length_of_stay,
    admission_type,
    cost_category
)
SELECT
    dp.patient_id,
    dh.hospital_id,
    dd.doctor_id,
    di.insurance_id,
    dc.condition_id,
    dt.date_id,
    c.billing_amount,
    c.length_of_stay,
    c.admission_type,
    c.cost_category
FROM clean_patient_data c
JOIN dim_patient dp ON c.name = dp.name
JOIN dim_hospital dh ON c.hospital = dh.hospital_name
JOIN dim_doctor dd ON c.doctor = dd.doctor_name
JOIN dim_insurance di ON c.insurance_provider = di.insurance_provider
JOIN dim_medical_condition dc ON c.medical_condition = dc.medical_condition
JOIN dim_date dt ON c.date_of_admission = dt.full_date;


DESCRIBE fact_admissions;
SELECT risk_score
FROM fact_admissions
LIMIT 10;

SELECT COUNT(*) 
FROM fact_admissions
WHERE risk_score IS NOT NULL;

UPDATE fact_admissions
SET risk_score = ROUND(
      (IFNULL(billing_amount,0) / 10000) * 0.4
    + (IFNULL(length_of_stay,0) * 0.3)
    + (CASE WHEN cost_category = 'High Cost' THEN 15 ELSE 0 END)
    + (CASE WHEN admission_type = 'Emergency' THEN 5 ELSE 0 END)
, 2);

SELECT MIN(risk_score), MAX(risk_score), AVG(risk_score)
FROM fact_admissions;

UPDATE fact_admissions
SET risk_category =
    CASE
        WHEN risk_score >= 25 THEN 'High'
        WHEN risk_score >= 15 THEN 'Medium'
        ELSE 'Low'
    END;

SELECT risk_category, COUNT(*) 
FROM fact_admissions
GROUP BY risk_category;

SELECT 
    di.insurance_provider,
    COUNT(*) AS total_cases,
    SUM(CASE WHEN f.risk_category='High' THEN 1 ELSE 0 END) AS high_risk_cases,
    AVG(f.risk_score) AS avg_risk_score
FROM fact_admissions f
JOIN dim_insurance di
ON f.insurance_id = di.insurance_id
GROUP BY di.insurance_provider
ORDER BY avg_risk_score DESC;

SELECT 
    dh.hospital_name,
    COUNT(*) AS total_cases,
    AVG(f.risk_score) AS avg_risk,
    SUM(CASE WHEN f.risk_category='High' THEN 1 ELSE 0 END) AS high_risk_cases
FROM fact_admissions f
JOIN dim_hospital dh
ON f.hospital_id = dh.hospital_id
GROUP BY dh.hospital_name
ORDER BY avg_risk DESC;

SELECT 
    dmc.medical_condition,
    COUNT(*) AS total_cases,
    AVG(f.risk_score) AS avg_risk,
    SUM(CASE WHEN f.risk_category='High' THEN 1 ELSE 0 END) AS high_risk_cases
FROM fact_admissions f
JOIN dim_medical_condition dmc
ON f.condition_id = dmc.condition_id
GROUP BY dmc.medical_condition
ORDER BY avg_risk DESC;

SELECT 
    admission_type,
    AVG(risk_score) AS avg_risk,
    COUNT(*) AS total_cases
FROM fact_admissions
GROUP BY admission_type
ORDER BY avg_risk DESC;

SELECT *
FROM fact_admissions
ORDER BY risk_score DESC
LIMIT 20;

