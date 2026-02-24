# Healthcare-Insurance-Risk-Intelligence

I built this project to practice working on a real healthcare dataset instead of small practice problems. The dataset contains hospital admission records, patient details, billing information, and insurance claims (around 55,000 rows).
My main goal was to understand how patient admissions and insurance costs are connected, and how we can identify high-risk or high-cost cases using data.

## What I did in this project

First, I imported the raw CSV files into MySQL 8.0.
I used `LOAD DATA INFILE` instead of the import wizard because the dataset was large. I also handled issues like date formatting and null values.
After cleaning the data, I created proper tables instead of keeping everything in one single flat table. I designed fact and dimension tables so that analysis becomes easier and faster.
Then I worked on:
* Calculating Length of Stay (discharge date – admission date)
* Checking which diagnoses have higher costs
* Analyzing insurance claim amounts
* Finding readmission patterns
* Categorizing patients based on risk level
For additional analysis, I used Python (pandas and basic machine learning models) to experiment with simple risk scoring logic.
Finally, I built a Power BI dashboard to show:
* Total claims
* Monthly trends
* Average treatment cost
* High-risk patient percentage
* Insurance provider comparison
* 
## What I learned
This project helped me understand:
* How to handle large CSV imports in MySQL
* Why star schema is better than flat tables
* How SQL + Python + Power BI can work together
* How to think in terms of business problems instead of just writing queries

This project is part of my journey to become a Data Analyst, and it helped me move from basic SQL practice to building a complete end-to-end analysis workflow.


